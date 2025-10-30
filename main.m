% MAIN.M - End-to-end pipeline for AI fermentation meta-analysis
%
% Pipeline:
%   1. Parse RIS file
%   2. Deduplicate records
%   3. Apply eligibility criteria
%   4. Extract metrics
%   5. Generate descriptive statistics
%   6. Perform meta-analyses (continuous + diagnostic)
%   7. Test publication bias
%   8. Export all reports
%
% Requirements: MATLAB R2021a+, base installation only
%
% Author: AI-Fermentation-MetaAnalysis-2025
% Date: 2025-10-30

function main()
% Set random seed for reproducibility
rng(42, 'twister');

fprintf('=================================================================\n');
fprintf('AI FERMENTATION META-ANALYSIS PIPELINE\n');
fprintf('=================================================================\n');
fprintf('Started: %s\n', datestr(now));
fprintf('MATLAB version: %s\n', version);

% Start overall timer
main_tic = tic;

%% Configuration
% Add src folder to path
addpath('src');

%% GUI: Select RIS file
fprintf('\n[STEP 0] Select RIS file...\n');
[ris_filename, ris_pathname] = uigetfile({'*.ris', 'RIS Files (*.ris)'; ...
    '*.*', 'All Files (*.*)'}, ...
    'Select RIS Bibliography File');
if isequal(ris_filename, 0)
    error('main:UserCancelled', 'User cancelled file selection');
end
input_ris_file = fullfile(ris_pathname, ris_filename);
fprintf('  Selected: %s\n', input_ris_file);

%% GUI: Select year range
fprintf('\n[STEP 0b] Select year range...\n');
current_year = year(datetime('now'));
prompt = {sprintf('Start Year (e.g., 2015):'), ...
    sprintf('End Year (e.g., %d):', current_year)};
dlgtitle = 'Year Range Filter';
dims = [1 35];
definput = {'2015', num2str(current_year)};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    error('main:UserCancelled', 'User cancelled year selection');
end

year_start = str2double(answer{1});
year_end = str2double(answer{2});

% Validate years
if isnan(year_start) || isnan(year_end)
    error('main:InvalidYear', 'Invalid year values');
end
if year_start > year_end
    error('main:InvalidRange', 'Start year must be <= end year');
end

fprintf('  Year range: %d - %d\n', year_start, year_end);

%% Configuration files
config_file = 'config.json';
output_dir = 'output';

% Validate config file
if ~isfile(config_file)
    error('main:ConfigNotFound', 'Config file not found: %s', config_file);
end

% Load configuration
fprintf('\n[STEP 1] Loading configuration...\n');
config = jsondecode(fileread(config_file));
fprintf('  Loaded %d AI keywords, %d fermentation keywords\n', ...
    length(config.ai_keywords_include), length(config.fermentation_keywords));

%% Step 2: Parse RIS file
fprintf('\n[STEP 2] Parsing RIS file...\n');
T_raw = parse_ris(input_ris_file);
fprintf('  Parsed %d records\n', height(T_raw));

if height(T_raw) == 0
    error('main:NoRecords', 'No records parsed from RIS file');
end

%% Step 3: Filter by year range
fprintf('\n[STEP 3] Filtering by year range (%d-%d)...\n', year_start, year_end);
initial_count = height(T_raw);

% Convert PY (Publication Year) from string to numeric
year_numeric = zeros(height(T_raw), 1);
for i = 1:height(T_raw)
    year_str = T_raw.PY{i};
    if ~isempty(year_str)
        year_numeric(i) = str2double(year_str);
    else
        year_numeric(i) = NaN;
    end
end

% Filter by year range (exclude NaN)
year_mask = (year_numeric >= year_start) & (year_numeric <= year_end);
T_raw = T_raw(year_mask, :);
filtered_count = height(T_raw);
fprintf('  Kept %d records (%.1f%%)\n', filtered_count, 100*filtered_count/initial_count);
fprintf('  Excluded %d records outside year range\n', initial_count - filtered_count);

if height(T_raw) == 0
    error('main:NoRecordsInRange', 'No records found in year range %d-%d', year_start, year_end);
end

%% Step 4: Deduplicate
fprintf('\n[STEP 4] Deduplicating records...\n');
[T_dedup, dedup_report] = deduplicate_records(T_raw);
fprintf('  Removed %d duplicates\n', dedup_report.total_duplicates);
fprintf('  Remaining: %d unique records\n', height(T_dedup));

%% Step 5: Eligibility screening
fprintf('\n[STEP 5] Applying eligibility criteria...\n');
[T_filtered, eligibility_counts] = eligibility_filter(T_dedup, config);
fprintf('  Eligible: %d records (%.1f%%)\n', ...
    eligibility_counts.eligible, 100*eligibility_counts.eligible/height(T_dedup));
fprintf('  For meta-analysis: %d records\n', eligibility_counts.for_meta);

%% Step 6: Extract metrics
fprintf('\n[STEP 6] Extracting performance metrics...\n');
[M, extract_stats] = extract_metrics(T_filtered, config);
fprintf('  Extracted metrics from %d studies\n', height(M));
fprintf('  Complete data: %.1f%%\n', extract_stats.complete_pct);

if height(M) == 0
    error('main:NoMetrics', 'No metrics extracted');
end

%% Step 7: Descriptive statistics
fprintf('\n[STEP 7] Generating descriptive statistics...\n');
[descriptive_tables, ~] = group_counts(M);
fprintf('  Generated %d frequency tables\n', 4); % year, method, domain, scale

%% Step 8: Meta-analyses
fprintf('\n[STEP 8] Performing meta-analyses...\n');

% Continuous metrics
fprintf('  [8a] Continuous meta-analyses...\n');
meta_cont_results = {};
continuous_metrics = {'R2', 'RMSE', 'MAE'};
for i = 1:length(continuous_metrics)
    metric = continuous_metrics{i};
    results = meta_continuous(M, metric);
    meta_cont_results{end+1} = results;
    if results.k >= config.meta_analysis_thresholds.min_studies_continuous
        fprintf('    %s: k=%d, effect=%.4f [%.4f, %.4f]\n', ...
            metric, results.k, results.effect, results.ci_low, results.ci_high);
        fprintf('        95%% PI: [%.4f, %.4f]\n', results.pi_low, results.pi_high);
        fprintf('        I²=%.1f%%, τ²=%.4f, Q=%.2f (p=%.4f)\n', ...
            results.I2, results.tau2, results.Q, results.p_het);
    else
        fprintf('    %s: insufficient studies (k=%d)\n', metric, results.k);
    end
end

% Diagnostic accuracy
fprintf('  [8b] Diagnostic meta-analysis...\n');
meta_diag_results = meta_diagnostic(M);
if meta_diag_results.k >= config.meta_analysis_thresholds.min_studies_diagnostic
    fprintf('    Diagnostic: k=%d, Sens=%.3f, Spec=%.3f, AUC=%.3f\n', ...
        meta_diag_results.k, meta_diag_results.sens, meta_diag_results.spec, meta_diag_results.AUC);
else
    fprintf('    Diagnostic: insufficient studies (k=%d)\n', meta_diag_results.k);
end

%% Step 8c: Subgroup analyses
fprintf('  [8c] Subgroup analyses...\n');
subgroup_results = {};
if height(M) > 10
    % Subgroup by scale
    try
        sub_scale = meta_subgroup_analysis(M, 'R2', 'scale');
        subgroup_results{end+1} = sub_scale;
        fprintf('    Scale subgroups: Q_between=%.2f (p=%.4f)\n', ...
            sub_scale.Q_between, sub_scale.p_between);
    catch ME
        fprintf('    Scale subgroup failed: %s\n', ME.message);
    end

    % Subgroup by AI method
    try
        sub_method = meta_subgroup_analysis(M, 'R2', 'ai_method');
        subgroup_results{end+1} = sub_method;
        fprintf('    AI method subgroups: Q_between=%.2f (p=%.4f)\n', ...
            sub_method.Q_between, sub_method.p_between);
    catch ME
        fprintf('    AI method subgroup failed: %s\n', ME.message);
    end
end

%% Step 9: Publication bias
fprintf('\n[STEP 9] Testing publication bias...\n');
bias_results = {};
for i = 1:length(continuous_metrics)
    metric = continuous_metrics{i};
    results = bias_publication(M, metric);
    bias_results{end+1} = results;
    if results.k >= 3
        fprintf('    %s: Egger p=%.4f', metric, results.egger_p);
        if results.egger_p < 0.05
            fprintf(' (significant asymmetry)\n');
        else
            fprintf(' (no significant bias)\n');
        end
    end
end

%% Step 10: Export results
fprintf('\n[STEP 10] Exporting results...\n');

% Build PRISMA counts
prisma_counts = struct();
prisma_counts.identified = initial_count;  % Before year filter
prisma_counts.after_year_filter = filtered_count;
prisma_counts.duplicates_removed = dedup_report.total_duplicates;
prisma_counts.screened = eligibility_counts.screened;
prisma_counts.eligible = eligibility_counts.eligible;
prisma_counts.for_meta = eligibility_counts.for_meta;
prisma_counts.excluded_total = eligibility_counts.excluded_total;
prisma_counts.excluded_ai_absent = eligibility_counts.excluded_ai_absent;
prisma_counts.excluded_topic_mismatch = eligibility_counts.excluded_topic_mismatch;
prisma_counts.excluded_abstract_only = eligibility_counts.excluded_abstract_only;
prisma_counts.year_start = year_start;
prisma_counts.year_end = year_end;

% Export standard reports
fprintf('  [10a] Exporting standard reports...\n');
export_reports(output_dir, prisma_counts, descriptive_tables, ...
    meta_cont_results, meta_diag_results, bias_results, M);

% Export extended statistics
fprintf('  [10b] Exporting extended statistics...\n');
export_extended_statistics(output_dir, meta_cont_results, meta_diag_results, subgroup_results, M);

fprintf('  All reports exported to: %s\n', output_dir);

%% Summary
main_elapsed = toc(main_tic);
fprintf('\n=================================================================\n');
fprintf('PIPELINE COMPLETED SUCCESSFULLY\n');
fprintf('=================================================================\n');
fprintf('Year range: %d - %d\n', year_start, year_end);
fprintf('Total elapsed time: %.2f seconds\n', main_elapsed);
fprintf('Finished: %s\n', datestr(now));
fprintf('\n📁 OUTPUT FILES GENERATED:\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Standard Reports:\n');
fprintf('  ✓ %s\n', fullfile(output_dir, 'prisma_counts.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'table2_descriptive.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'meta_continuous_summary.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'meta_diagnostic_summary.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'bias_tests.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'studies_metrics.csv'));
fprintf('\nExtended Statistics\n');
fprintf('  ✓ %s\n', fullfile(output_dir, 'meta_extended_statistics.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'heterogeneity_summary.csv'));
fprintf('  ✓ %s\n', fullfile(output_dir, 'study_characteristics_extended.csv'));
fprintf('  ✓ %s (if applicable)\n', fullfile(output_dir, 'subgroup_*.csv'));
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('\n');
end
