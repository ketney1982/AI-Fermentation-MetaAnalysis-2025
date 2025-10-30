function export_reports(output_dir, prisma_counts, descriptive_tables, meta_cont_results, meta_diag_results, bias_results, M)
% EXPORT_REPORTS Export all results to CSV and JSON files
%
% Inputs:
%   output_dir - Directory for output files
%   prisma_counts - PRISMA flow counts struct
%   descriptive_tables - Group counts tables
%   meta_cont_results - Cell array of continuous meta-analysis results
%   meta_diag_results - Diagnostic meta-analysis results
%   bias_results - Cell array of bias test results
%   M - Metrics table

tic;
fprintf('[DEBUG][export] Started export to: %s\n', output_dir);

if ~isfolder(output_dir)
    mkdir(output_dir);
    fprintf('[DEBUG][export] Created output directory\n');
end

% 1. PRISMA counts
prisma_file = fullfile(output_dir, 'prisma_counts.csv');
export_prisma_counts(prisma_file, prisma_counts);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', prisma_file, 1);

% 2. Table 2 - Descriptive statistics
table2_file = fullfile(output_dir, 'table2_descriptive.csv');
export_descriptive_table(table2_file, descriptive_tables, M);

% 3. Meta-analysis continuous summary
meta_cont_file = fullfile(output_dir, 'meta_continuous_summary.csv');
export_meta_continuous(meta_cont_file, meta_cont_results);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', meta_cont_file, length(meta_cont_results));

% 4. Meta-analysis diagnostic summary
meta_diag_file = fullfile(output_dir, 'meta_diagnostic_summary.csv');
export_meta_diagnostic(meta_diag_file, meta_diag_results);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', meta_diag_file, 1);

% 5. Bias tests
bias_file = fullfile(output_dir, 'bias_tests.csv');
export_bias_tests(bias_file, bias_results);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', bias_file, length(bias_results));

% 6. Studies metrics (full data)
studies_file = fullfile(output_dir, 'studies_metrics.csv');
writetable(M, studies_file);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', studies_file, height(M));

elapsed = toc;
fprintf('[DEBUG][export] Total elapsed=%.2fs\n', elapsed);
end

function export_prisma_counts(filepath, counts)
% Export PRISMA flow counts
fid = fopen(filepath, 'w');
fprintf(fid, 'identified,duplicates_removed,screened,fulltext_assessed,excluded_total,');
fprintf(fid, 'excluded_ai_absent,excluded_topic_mismatch,excluded_abstract_only,');
fprintf(fid, 'excluded_duplicate_late,excluded_language,eligible,included_meta\n');

fprintf(fid, '%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n', ...
    counts.identified, ...
    counts.duplicates_removed, ...
    counts.screened, ...
    counts.screened, ... % fulltext_assessed (same as screened)
    counts.excluded_total, ...
    counts.excluded_ai_absent, ...
    counts.excluded_topic_mismatch, ...
    counts.excluded_abstract_only, ...
    0, ... % excluded_duplicate_late
    0, ... % excluded_language
    counts.eligible, ...
    counts.for_meta);

fclose(fid);
end

function export_descriptive_table(filepath, tables, M)
% Export Table 2 - Descriptive characteristics
fid = fopen(filepath, 'w');
fprintf(fid, 'Caracteristica,Subcategorie,n,pct,ReferinteCheie\n');

% Year distribution
write_category(fid, 'Year', tables.year, M);

% AI methodology
write_category(fid, 'AI Method', tables.ai_method, M);

% Domain
write_category(fid, 'Domain', tables.domain, M);

% Scale
write_category(fid, 'Scale', tables.scale, M);

fclose(fid);
fprintf('[DEBUG][export] Wrote=%s (rows=%d)\n', filepath, ...
    height(tables.year) + height(tables.ai_method) + height(tables.domain) + height(tables.scale));
end

function write_category(fid, category_name, table_data, M)
% Write one category to descriptive table
for i = 1:height(table_data)
    refs = 'Ref1,2021; Ref2,2022'; % Placeholder - would extract from M
    fprintf(fid, '%s,%s,%d,%.1f,"%s"\n', ...
        category_name, ...
        table_data.Category{i}, ...
        table_data.n(i), ...
        table_data.Percent(i), ...
        refs);
end
end

function export_meta_continuous(filepath, results_array)
% Export continuous meta-analysis results
fid = fopen(filepath, 'w');
fprintf(fid, 'metric,model,k,effect,ci_low,ci_high,tau2,I2,Q,p\n');

for i = 1:length(results_array)
    r = results_array{i};
    if r.k > 0
        fprintf(fid, '%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.1f,%.2f,%.4f\n', ...
            r.metric, r.model, r.k, r.effect, r.ci_low, r.ci_high, ...
            r.tau2, r.I2, r.Q, r.p);
    end
end

fclose(fid);
end

function export_meta_diagnostic(filepath, results)
% Export diagnostic meta-analysis results
fid = fopen(filepath, 'w');
fprintf(fid, 'k,sens,sens_ci_low,sens_ci_high,spec,spec_ci_low,spec_ci_high,AUC,AUC_ci_low,AUC_ci_high\n');

if results.k > 0
    fprintf(fid, '%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n', ...
        results.k, results.sens, results.sens_ci_low, results.sens_ci_high, ...
        results.spec, results.spec_ci_low, results.spec_ci_high, ...
        results.AUC, results.AUC_ci_low, results.AUC_ci_high);
end

fclose(fid);
end

function export_bias_tests(filepath, results_array)
% Export publication bias test results
fid = fopen(filepath, 'w');
fprintf(fid, 'subset,test,k,stat,p,note\n');

for i = 1:length(results_array)
    r = results_array{i};
    if r.k > 0
        % Egger test
        fprintf(fid, '%s,Egger,%d,%.4f,%.4f,"Intercept test"\n', ...
            r.metric, r.k, r.egger_t, r.egger_p);

        % Trim-and-fill
        if isfield(r.trim_fill, 'k_trimmed') && r.trim_fill.k_trimmed > 0
            fprintf(fid, '%s,Trim-and-Fill,%d,%.4f,NA,"%s"\n', ...
                r.metric, r.k, r.trim_fill.adjusted_effect, r.trim_fill.note);
        end
    end
end

fclose(fid);
end
