function results = calculate_prediction_interval(effect, se, tau2, k)
% CALCULATE_PREDICTION_INTERVAL Calculate 95% prediction interval
%
% Inputs:
%   effect - Pooled effect estimate
%   se - Standard error of pooled estimate
%   tau2 - Between-study variance
%   k - Number of studies
%
% Outputs:
%   results - Struct with pi_low, pi_high

% Prediction interval accounts for both within-study and between-study variance
% PI = effect ± t(k-2) × sqrt(se² + tau²)

if k < 3
    warning('Insufficient studies for prediction interval (k=%d)', k);
    results.pi_low = NaN;
    results.pi_high = NaN;
    results.note = 'Insufficient studies';
    return;
end

% Degrees of freedom
df = k - 2;

% t-value for 95% CI
t_val = tinv(0.975, df);

% Prediction variance = within-study variance + between-study variance
pred_var = se^2 + tau2;
pred_se = sqrt(pred_var);

% 95% Prediction Interval
pi_low = effect - t_val * pred_se;
pi_high = effect + t_val * pred_se;

results.pi_low = pi_low;
results.pi_high = pi_high;
results.pred_se = pred_se;
results.df = df;
results.t_val = t_val;

fprintf('[DEBUG][PI] 95%% Prediction Interval: [%.4f, %.4f]\n', pi_low, pi_high);
end
