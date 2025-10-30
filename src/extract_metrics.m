function [M, stats] = extract_metrics(T, config)
% EXTRACT_METRICS Extract performance metrics from eligible studies
%
% Extracts:
%   - Binary classification: TP, FP, FN, TN, Accuracy, Sensitivity, Specificity
%   - Continuous regression: R2, RMSE, MAE
%   - Metadata: year, ai_method, domain, scale, sample_size
%
% Inputs:
%   T - Filtered table with eligible_flag
%   config - Configuration with extraction patterns
%
% Outputs:
%   M - Table with metrics per study
%   stats - Statistics on extraction completeness

tic;
fprintf('[DEBUG][extract] Started metric extraction\n');

% Filter to eligible records only
T_eligible = T(T.eligible_flag, :);
n = height(T_eligible);

fprintf('[DEBUG][extract] Eligible records=%d\n', n);

if n == 0
    M = create_empty_metrics_table();
    stats = struct('complete', 0, 'partial', 0, 'missing', 0);
    return;
end

% Initialize metrics arrays
id = (1:n)';
year = zeros(n, 1);
ai_method = cell(n, 1);
domain = cell(n, 1);
scale = cell(n, 1);

% Binary metrics
TP = nan(n, 1);
FP = nan(n, 1);
FN = nan(n, 1);
TN = nan(n, 1);
Acc = nan(n, 1);
Sens = nan(n, 1);
Spec = nan(n, 1);

% Continuous metrics
R2 = nan(n, 1);
RMSE = nan(n, 1);
MAE = nan(n, 1);

% Sample size
N = nan(n, 1);

% Extraction completeness flags
has_binary = false(n, 1);
has_continuous = false(n, 1);

for i = 1:n
    % Extract year
    year_str = T_eligible.PY{i};
    if isempty(year_str)
        year_str = T_eligible.Y1{i};
    end
    year(i) = extract_year(year_str);

    % Extract AI method from title/abstract/keywords
    text = [T_eligible.TI{i} ' ' T_eligible.AB{i} ' ' T_eligible.KW{i}];
    ai_method{i} = identify_ai_method(text, config);

    % Extract domain (simplified categorization)
    domain{i} = identify_domain(text);

    % Extract scale (lab/pilot/industrial)
    scale{i} = identify_scale(text);

    % Extract metrics from abstract
    abstract = T_eligible.AB{i};

    % Binary classification metrics
    Acc(i) = extract_numeric(abstract, config.extraction_patterns.accuracy_regex);
    Sens(i) = extract_numeric(abstract, config.extraction_patterns.sensitivity_regex);
    Spec(i) = extract_numeric(abstract, config.extraction_patterns.specificity_regex);

    % Continuous metrics
    R2(i) = extract_numeric(abstract, config.extraction_patterns.r2_regex);
    RMSE(i) = extract_numeric(abstract, config.extraction_patterns.rmse_regex);
    MAE(i) = extract_numeric(abstract, config.extraction_patterns.mae_regex);

    % Sample size (look for N=xxx or sample size patterns)
    N(i) = extract_sample_size(abstract);

    % Check completeness
    if ~isnan(Acc(i)) || ~isnan(Sens(i)) || ~isnan(Spec(i))
        has_binary(i) = true;
    end
    if ~isnan(R2(i)) || ~isnan(RMSE(i)) || ~isnan(MAE(i))
        has_continuous(i) = true;
    end
end

% Convert accuracy/sens/spec from percentage to proportion if needed
Acc = normalize_percentage(Acc);
Sens = normalize_percentage(Sens);
Spec = normalize_percentage(Spec);

% Create metrics table
M = table(id, year, ai_method, domain, scale, ...
    TP, FP, FN, TN, Acc, Sens, Spec, ...
    R2, RMSE, MAE, N);

% Add meta inclusion flag
M.included_meta_flag = T_eligible.meta89_flag;

% Calculate statistics
complete = sum(has_binary | has_continuous);
partial = sum(has_binary | has_continuous);
missing = n - complete;

stats = struct();
stats.total = n;
stats.complete_pct = 100 * complete / n;
stats.partial_pct = 100 * partial / n;
stats.missing_pct = 100 * missing / n;
stats.has_binary = sum(has_binary);
stats.has_continuous = sum(has_continuous);

elapsed = toc;

% Debug output
fprintf('[DEBUG][extract] Complete=%.1f%% | Partial=%.1f%% | Missing=%.1f%%\n', ...
    stats.complete_pct, stats.partial_pct, stats.missing_pct);
fprintf('[DEBUG][extract] Binary metrics: %d studies\n', stats.has_binary);
fprintf('[DEBUG][extract] Continuous metrics: %d studies\n', stats.has_continuous);
fprintf('[DEBUG][extract] Elapsed=%.2fs\n', elapsed);

% Show first 5 rows with metrics
fprintf('[DEBUG][extract] First 5 rows:\n');
for i = 1:min(5, height(M))
    fprintf('  ID=%d | Year=%d | Method=%s | R2=%.3f | Acc=%.3f\n', ...
        M.id(i), M.year(i), M.ai_method{i}, M.R2(i), M.Acc(i));
end

% Show summary statistics
fprintf('[DEBUG][extract] Year range: %d - %d\n', min(year), max(year));
fprintf('[DEBUG][extract] R2: min=%.3f, max=%.3f, mean=%.3f\n', ...
    nanmin(R2), nanmax(R2), nanmean(R2));
fprintf('[DEBUG][extract] Accuracy: min=%.3f, max=%.3f, mean=%.3f\n', ...
    nanmin(Acc), nanmax(Acc), nanmean(Acc));
end

function yr = extract_year(year_str)
% Extract 4-digit year
if isempty(year_str)
    yr = NaN;
    return;
end
tokens = regexp(year_str, '\d{4}', 'match');
if ~isempty(tokens)
    yr = str2double(tokens{1});
else
    yr = NaN;
end
end

function method = identify_ai_method(text, config)
% Identify AI method from text using synonym mapping
text_lower = lower(text);

% Check for specific methods in order of specificity
methods_priority = {
    'convolutional neural network', 'CNN';
    'deep learning', 'DL';
    'support vector machine', 'SVM';
    'random forest', 'RF';
    'neural network', 'ANN';
    'machine learning', 'ML'
    };

for i = 1:size(methods_priority, 1)
    if contains(text_lower, lower(methods_priority{i,1}))
        method = methods_priority{i,2};
        return;
    end
end

method = 'Other';
end

function dom = identify_domain(text)
% Identify application domain
text_lower = lower(text);

if contains(text_lower, {'brewing', 'beer', 'yeast'})
    dom = 'Brewing';
elseif contains(text_lower, {'bioreactor', 'bioprocess', 'cell culture'})
    dom = 'Bioprocess';
elseif contains(text_lower, {'wine', 'fermentation'})
    dom = 'Fermentation';
else
    dom = 'Other';
end
end

function sc = identify_scale(text)
% Identify experimental scale
text_lower = lower(text);

if contains(text_lower, {'industrial', 'production scale', 'commercial'})
    sc = 'Industrial';
elseif contains(text_lower, {'pilot', 'pilot-scale'})
    sc = 'Pilot';
elseif contains(text_lower, {'lab', 'laboratory', 'bench'})
    sc = 'Lab';
else
    sc = 'Unspecified';
end
end

function val = extract_numeric(text, pattern)
% Extract numeric value using regex pattern
if isempty(text)
    val = NaN;
    return;
end

tokens = regexp(text, pattern, 'tokens');
if ~isempty(tokens)
    val = str2double(tokens{1}{1});
else
    val = NaN;
end
end

function n = extract_sample_size(text)
% Extract sample size from patterns like "N=123" or "n=123"
if isempty(text)
    n = NaN;
    return;
end

patterns = {'[Nn]\s*=\s*(\d+)', 'sample size[:\s]+(\d+)', '(\d+)\s+samples'};

for i = 1:length(patterns)
    tokens = regexp(text, patterns{i}, 'tokens');
    if ~isempty(tokens)
        n = str2double(tokens{1}{1});
        return;
    end
end

n = NaN;
end

function vals = normalize_percentage(vals)
% Convert values >1 to proportions (assume they're percentages)
idx = vals > 1 & ~isnan(vals);
vals(idx) = vals(idx) / 100;
end

function M = create_empty_metrics_table()
M = table();
M.id = [];
M.year = [];
M.ai_method = {};
M.domain = {};
M.scale = {};
M.TP = [];
M.FP = [];
M.FN = [];
M.TN = [];
M.Acc = [];
M.Sens = [];
M.Spec = [];
M.R2 = [];
M.RMSE = [];
M.MAE = [];
M.N = [];
M.included_meta_flag = logical([]);
end
