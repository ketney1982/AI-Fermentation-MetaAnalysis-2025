function results = meta_continuous(M, metric_name)
% META_CONTINUOUS Perform DerSimonian-Laird meta-analysis for continuous metrics
%
% Inputs:
%   M - Metrics table
%   metric_name - 'R2', 'RMSE', or 'MAE'
%
% Outputs:
%   results - Struct with: k, effect, SE, ci_low, ci_high, tau2, I2, Q, p

tic;
fprintf('[DEBUG][meta_cont] Started meta-analysis for %s\n', metric_name);

% Extract metric values
values = M.(metric_name);

% Remove NaN values
valid_idx = ~isnan(values);
values = values(valid_idx);
k = length(values);

fprintf('[DEBUG][meta_cont] %s | k=%d\n', metric_name, k);

if k < 3
    warning('meta_continuous:InsufficientData', ...
        'Insufficient studies (k=%d) for %s meta-analysis', k, metric_name);
    results = create_empty_results();
    results.k = k;
    results.note = 'Insufficient data';
    return;
end

% For continuous metrics without reported variances, use unweighted mean
% and estimate variance from sample variance
% This is a limitation noted in the requirements

% Calculate sample variance as proxy for study-level variance
study_var = var(values);
if study_var == 0 || isnan(study_var)
    study_var = 0.01; % Small default
end

% Assume equal variances (since not reported)
variances = repmat(study_var / k, k, 1);
weights = 1 ./ variances;

% Weighted mean (fixed-effect)
effect_fixed = sum(weights .* values) / sum(weights);
se_fixed = sqrt(1 / sum(weights));

% Calculate Q statistic for heterogeneity
Q = sum(weights .* (values - effect_fixed).^2);
df = k - 1;
p_het = 1 - chi2cdf(Q, df);

% Calculate I² (percentage of variation due to heterogeneity)
I2 = max(0, 100 * (Q - df) / Q);

% DerSimonian-Laird tau² estimator
C = sum(weights) - sum(weights.^2) / sum(weights);
tau2 = max(0, (Q - df) / C);

% Random-effects weights
weights_re = 1 ./ (variances + tau2);

% Random-effects pooled estimate
effect = sum(weights_re .* values) / sum(weights_re);
se = sqrt(1 / sum(weights_re));

% 95% CI
ci_low = effect - 1.96 * se;
ci_high = effect + 1.96 * se;

% 95% Prediction Interval
if k >= 3
    pi_results = calculate_prediction_interval(effect, se, tau2, k);
    pi_low = pi_results.pi_low;
    pi_high = pi_results.pi_high;
else
    pi_low = NaN;
    pi_high = NaN;
end

% Z-test for overall effect
z = effect / se;
p = 2 * (1 - normcdf(abs(z)));

% Package results
results = struct();
results.metric = metric_name;
results.model = 'DerSimonian-Laird';
results.k = k;
results.effect = effect;
results.se = se;
results.ci_low = ci_low;
results.ci_high = ci_high;
results.pi_low = pi_low;
results.pi_high = pi_high;
results.tau2 = tau2;
results.I2 = I2;
results.Q = Q;
results.p_het = p_het;
results.p = p;
results.note = 'Variances estimated from sample variance';

elapsed = toc;

% Debug output
fprintf('[DEBUG][meta_cont] %s | k=%d | effect=%.4f [%.4f, %.4f] | I2=%.1f%% | tau2=%.4f\n', ...
    metric_name, k, effect, ci_low, ci_high, I2, tau2);
fprintf('[DEBUG][meta_cont] Q=%.2f (p=%.4f) | Overall p=%.4f\n', Q, p_het, p);
fprintf('[DEBUG][meta_cont] Elapsed=%.2fs\n', elapsed);

% Show individual study values
fprintf('[DEBUG][meta_cont] Study values (first 5):\n');
for i = 1:min(5, k)
    fprintf('  Study %d: %.4f\n', i, values(i));
end
fprintf('[DEBUG][meta_cont] Min=%.4f, Max=%.4f, Mean=%.4f, SD=%.4f\n', ...
    min(values), max(values), mean(values), std(values));
end

function res = create_empty_results()
res = struct();
res.metric = '';
res.model = '';
res.k = 0;
res.effect = NaN;
res.se = NaN;
res.ci_low = NaN;
res.ci_high = NaN;
res.tau2 = NaN;
res.I2 = NaN;
res.Q = NaN;
res.p_het = NaN;
res.p = NaN;
res.note = '';
end
