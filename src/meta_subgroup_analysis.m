function results = meta_subgroup_analysis(M, metric_name, grouping_var)
% META_SUBGROUP_ANALYSIS Perform subgroup meta-analysis
%
% Inputs:
%   M - Metrics table
%   metric_name - 'R2', 'RMSE', 'MAE', etc.
%   grouping_var - Column name for grouping (e.g., 'scale', 'ai_method')
%
% Outputs:
%   results - Struct with subgroup-specific estimates and between-group heterogeneity

fprintf('[DEBUG][subgroup] Subgroup analysis for %s by %s\n', metric_name, grouping_var);

% Extract metric and grouping
values = M.(metric_name);
groups = M.(grouping_var);

% Remove NaN values
valid_idx = ~isnan(values);
values = values(valid_idx);
groups = groups(valid_idx);

% Find unique groups
unique_groups = unique(groups);
n_groups = length(unique_groups);

fprintf('[DEBUG][subgroup] Found %d subgroups\n', n_groups);

% Initialize results
subgroup_results = cell(n_groups, 1);
Q_within = 0;
df_within = 0;

for i = 1:n_groups
    grp = unique_groups{i};
    idx = strcmp(groups, grp);
    grp_values = values(idx);
    k_grp = length(grp_values);

    if k_grp < 2
        fprintf('[DEBUG][subgroup] Group %s: k=%d (skipped)\n', grp, k_grp);
        continue;
    end

    % Calculate subgroup meta-analysis
    grp_mean = mean(grp_values);
    grp_var = var(grp_values);
    grp_se = sqrt(grp_var / k_grp);

    % Heterogeneity within subgroup
    Q_grp = (k_grp - 1) * grp_var;
    Q_within = Q_within + Q_grp;
    df_within = df_within + (k_grp - 1);

    subgroup_results{i} = struct(...
        'group', grp, ...
        'k', k_grp, ...
        'mean', grp_mean, ...
        'se', grp_se, ...
        'ci_low', grp_mean - 1.96*grp_se, ...
        'ci_high', grp_mean + 1.96*grp_se, ...
        'Q', Q_grp);

    fprintf('[DEBUG][subgroup] %s: k=%d, mean=%.4f [%.4f, %.4f]\n', ...
        grp, k_grp, grp_mean, grp_mean - 1.96*grp_se, grp_mean + 1.96*grp_se);
end

% Calculate between-group heterogeneity (Q_between)
overall_mean = mean(values);
Q_total = sum((values - overall_mean).^2);
Q_between = Q_total - Q_within;
df_between = n_groups - 1;
p_between = 1 - chi2cdf(Q_between, df_between);

% Package results
results = struct();
results.metric = metric_name;
results.grouping_var = grouping_var;
results.n_groups = n_groups;
results.subgroups = subgroup_results;
results.Q_within = Q_within;
results.Q_between = Q_between;
results.Q_total = Q_total;
results.df_between = df_between;
results.p_between = p_between;

fprintf('[DEBUG][subgroup] Q_between=%.2f (df=%d, p=%.4f)\n', Q_between, df_between, p_between);
if p_between < 0.10
    fprintf('[DEBUG][subgroup] Significant between-group heterogeneity!\n');
end

end
