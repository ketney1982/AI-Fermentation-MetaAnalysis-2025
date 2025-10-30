function bias_results = bias_publication(M, metric_name)
% BIAS_PUBLICATION Test for publication bias
%
% Performs:
%   - Egger's regression test
%   - Generates funnel plot data
%   - Trim-and-fill (if k >= 10)
%
% Inputs:
%   M - Metrics table
%   metric_name - Metric to test ('R2', 'RMSE', 'MAE', etc.)
%
% Outputs:
%   bias_results - Struct with test statistics and funnel data

tic;
fprintf('[DEBUG][bias] Started publication bias testing for %s\n', metric_name);

% Extract metric values
values = M.(metric_name);

% Remove NaN
valid_idx = ~isnan(values);
values = values(valid_idx);
k = length(values);

fprintf('[DEBUG][bias] %s | k=%d\n', metric_name, k);

if k < 3
    warning('bias_publication:InsufficientData', ...
        'Insufficient studies (k=%d) for bias testing', k);
    bias_results = create_empty_results();
    bias_results.k = k;
    return;
end

% Estimate standard errors (simplified - from sample variance)
overall_var = var(values);
se_values = sqrt(overall_var / k * ones(k, 1));

% Egger's test: regress standardized effect (values/SE) on precision (1/SE)
precision = 1 ./ se_values;
standardized_effect = values ./ se_values;

% Linear regression: standardized_effect = intercept + slope * precision
% Intercept significantly different from 0 indicates asymmetry
X = [ones(k, 1), precision];
beta = X \ standardized_effect;

intercept = beta(1);
slope = beta(2);

% Calculate residuals and standard error of intercept
fitted = X * beta;
residuals = standardized_effect - fitted;
mse = sum(residuals.^2) / (k - 2);
var_beta = mse * inv(X' * X);
se_intercept = sqrt(var_beta(1,1));

% T-test for intercept
t_stat = intercept / se_intercept;
df = k - 2;
p_egger = 2 * (1 - tcdf(abs(t_stat), df));

% Funnel plot data
funnel_data = struct();
funnel_data.effect = values;
funnel_data.se = se_values;
funnel_data.precision = precision;

% Trim-and-fill (only if k >= 10)
trim_fill_results = struct();
if k >= 10
    fprintf('[DEBUG][bias] Running trim-and-fill (k=%d)\n', k);
    trim_fill_results = trim_and_fill(values, se_values);
else
    fprintf('[DEBUG][bias] Skipping trim-and-fill (k=%d < 10)\n', k);
    trim_fill_results.k_trimmed = 0;
    trim_fill_results.adjusted_effect = NaN;
    trim_fill_results.note = 'Not performed (k < 10)';
end

% Package results
bias_results = struct();
bias_results.metric = metric_name;
bias_results.k = k;
bias_results.egger_intercept = intercept;
bias_results.egger_se = se_intercept;
bias_results.egger_t = t_stat;
bias_results.egger_p = p_egger;
bias_results.funnel_data = funnel_data;
bias_results.trim_fill = trim_fill_results;

elapsed = toc;

% Debug output
fprintf('[DEBUG][bias] Egger test: intercept=%.4f (SE=%.4f), t=%.2f, p=%.4f\n', ...
    intercept, se_intercept, t_stat, p_egger);
if p_egger < 0.05
    fprintf('[DEBUG][bias] WARNING: Significant asymmetry detected (p < 0.05)\n');
else
    fprintf('[DEBUG][bias] No significant asymmetry detected\n');
end
fprintf('[DEBUG][bias] Elapsed=%.2fs\n', elapsed);
end

function tf_results = trim_and_fill(values, se_values)
% Simplified trim-and-fill implementation
% Identifies potentially missing studies and imputes them

k = length(values);

% Rank studies by effect size
[sorted_values, sort_idx] = sort(values);
sorted_se = se_values(sort_idx);

% Simple trimming: remove most extreme studies iteratively
% until funnel plot is symmetric
% For simplicity, estimate number of missing studies as
% those on the "missing" side

mean_effect = mean(values);

% Count studies above vs below mean
n_above = sum(values > mean_effect);
n_below = sum(values < mean_effect);

% Asymmetry estimate
k_missing = abs(n_above - n_below);

% Adjusted effect (simple approach: add imputed studies at mirror positions)
if k_missing > 0
    % Impute missing studies
    if n_above > n_below
        % Missing on lower side - impute low values
        imputed_values = mean_effect - abs(values(values > mean_effect) - mean_effect);
    else
        % Missing on upper side - impute high values
        imputed_values = mean_effect + abs(values(values < mean_effect) - mean_effect);
    end

    combined_values = [values; imputed_values(1:min(k_missing, length(imputed_values)))];
    adjusted_effect = mean(combined_values);
else
    adjusted_effect = mean_effect;
end

tf_results = struct();
tf_results.k_original = k;
tf_results.k_trimmed = k_missing;
tf_results.original_effect = mean_effect;
tf_results.adjusted_effect = adjusted_effect;
tf_results.note = 'Simplified trim-and-fill';
end

function res = create_empty_results()
res = struct();
res.metric = '';
res.k = 0;
res.egger_intercept = NaN;
res.egger_se = NaN;
res.egger_t = NaN;
res.egger_p = NaN;
res.funnel_data = struct();
res.trim_fill = struct();
end
