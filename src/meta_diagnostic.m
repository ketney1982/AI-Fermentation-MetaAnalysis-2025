function results = meta_diagnostic(M)
% META_DIAGNOSTIC Meta-analysis for diagnostic accuracy (Sensitivity/Specificity)
%
% Aggregates sensitivity and specificity using logit transformation
% Approximates sROC AUC
%
% Inputs:
%   M - Metrics table with Sens and Spec
%
% Outputs:
%   results - Struct with pooled Sens, Spec, AUC and 95% CIs

tic;
fprintf('[DEBUG][meta_diag] Started diagnostic meta-analysis\n');

% Extract sensitivity and specificity
sens = M.Sens;
spec = M.Spec;

% Keep only studies with both sens and spec
valid_idx = ~isnan(sens) & ~isnan(spec);
sens = sens(valid_idx);
spec = spec(valid_idx);
k = length(sens);

fprintf('[DEBUG][meta_diag] k=%d\n', k);

if k < 3
    warning('meta_diagnostic:InsufficientData', ...
        'Insufficient studies (k=%d) for diagnostic meta-analysis', k);
    results = create_empty_results();
    results.k = k;
    return;
end

% Ensure values are in valid range [0.001, 0.999] for logit
sens = max(0.001, min(0.999, sens));
spec = max(0.001, min(0.999, spec));

% Logit transformation
logit_sens = log(sens ./ (1 - sens));
logit_spec = log(spec ./ (1 - spec));

% Estimate variances (simplified - assumes equal weight)
% In full implementation, would use study sample sizes
var_logit_sens = 1 ./ (k * sens .* (1 - sens));
var_logit_spec = 1 ./ (k * spec .* (1 - spec));

% Pooled estimates using inverse-variance weighting
w_sens = 1 ./ var_logit_sens;
w_spec = 1 ./ var_logit_spec;

pooled_logit_sens = sum(w_sens .* logit_sens) / sum(w_sens);
pooled_logit_spec = sum(w_spec .* logit_spec) / sum(w_spec);

% Back-transform to probability scale
pooled_sens = exp(pooled_logit_sens) / (1 + exp(pooled_logit_sens));
pooled_spec = exp(pooled_logit_spec) / (1 + exp(pooled_logit_spec));

% Standard errors
se_logit_sens = sqrt(1 / sum(w_sens));
se_logit_spec = sqrt(1 / sum(w_spec));

% 95% CI on logit scale
ci_logit_sens_low = pooled_logit_sens - 1.96 * se_logit_sens;
ci_logit_sens_high = pooled_logit_sens + 1.96 * se_logit_sens;
ci_logit_spec_low = pooled_logit_spec - 1.96 * se_logit_spec;
ci_logit_spec_high = pooled_logit_spec + 1.96 * se_logit_spec;

% Back-transform CIs
sens_ci_low = exp(ci_logit_sens_low) / (1 + exp(ci_logit_sens_low));
sens_ci_high = exp(ci_logit_sens_high) / (1 + exp(ci_logit_sens_high));
spec_ci_low = exp(ci_logit_spec_low) / (1 + exp(ci_logit_spec_low));
spec_ci_high = exp(ci_logit_spec_high) / (1 + exp(ci_logit_spec_high));

% Approximate AUC from pooled sensitivity and specificity
% Simple approximation: AUC ≈ (Sens + Spec) / 2
% More sophisticated: use DeLong method, but requires full data
auc_approx = (pooled_sens + pooled_spec) / 2;

% Approximate AUC CI (rough estimate)
auc_se = sqrt((se_logit_sens^2 + se_logit_spec^2) / 4);
auc_ci_low = max(0, auc_approx - 1.96 * auc_se);
auc_ci_high = min(1, auc_approx + 1.96 * auc_se);

% Package results
results = struct();
results.k = k;
results.sens = pooled_sens;
results.sens_ci_low = sens_ci_low;
results.sens_ci_high = sens_ci_high;
results.spec = pooled_spec;
results.spec_ci_low = spec_ci_low;
results.spec_ci_high = spec_ci_high;
results.AUC = auc_approx;
results.AUC_ci_low = auc_ci_low;
results.AUC_ci_high = auc_ci_high;
results.note = 'Logit-transformed pooling; AUC approximated';

elapsed = toc;

% Debug output
fprintf('[DEBUG][meta_diag] k=%d | Sens=%.3f [%.3f, %.3f] | Spec=%.3f [%.3f, %.3f]\n', ...
    k, pooled_sens, sens_ci_low, sens_ci_high, pooled_spec, spec_ci_low, spec_ci_high);
fprintf('[DEBUG][meta_diag] AUC=%.3f [%.3f, %.3f]\n', auc_approx, auc_ci_low, auc_ci_high);
fprintf('[DEBUG][meta_diag] Elapsed=%.2fs\n', elapsed);

% Show individual values
fprintf('[DEBUG][meta_diag] Individual values (first 5):\n');
for i = 1:min(5, k)
    fprintf('  Study %d: Sens=%.3f, Spec=%.3f\n', i, sens(i), spec(i));
end
fprintf('[DEBUG][meta_diag] Sens: Min=%.3f, Max=%.3f, Mean=%.3f\n', ...
    min(sens), max(sens), mean(sens));
fprintf('[DEBUG][meta_diag] Spec: Min=%.3f, Max=%.3f, Mean=%.3f\n', ...
    min(spec), max(spec), mean(spec));
end

function res = create_empty_results()
res = struct();
res.k = 0;
res.sens = NaN;
res.sens_ci_low = NaN;
res.sens_ci_high = NaN;
res.spec = NaN;
res.spec_ci_low = NaN;
res.spec_ci_high = NaN;
res.AUC = NaN;
res.AUC_ci_low = NaN;
res.AUC_ci_high = NaN;
res.note = '';
end
