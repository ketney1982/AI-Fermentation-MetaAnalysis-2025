function [tables, stats] = group_counts(M)
% GROUP_COUNTS Generate descriptive statistics tables
%
% Creates frequency tables for:
%   - Year distribution
%   - AI methodology
%   - Application domain
%   - Experimental scale
%
% Inputs:
%   M - Metrics table
%
% Outputs:
%   tables - Struct with frequency tables
%   stats - Validation statistics (sum of percentages)

tic;
fprintf('[DEBUG][group_counts] Started grouping\n');
fprintf('[DEBUG][group_counts] Total records=%d\n', height(M));

if height(M) == 0
    tables = struct();
    stats = struct();
    return;
end

% Year groups (5-year bins) - extend range to cover all data
year_bins = 1985:5:2030;  % Extended to cover 1985-2026 range
year_groups = discretize(M.year, year_bins);
year_labels = cell(length(year_bins)-1, 1);
for i = 1:length(year_bins)-1
    year_labels{i} = sprintf('%d-%d', year_bins(i), year_bins(i+1)-1);
end

% Create frequency tables
tables = struct();

% Year distribution - filter out NaN groups
valid_idx = ~isnan(year_groups);
[year_n, year_group_idx] = groupcounts(year_groups(valid_idx));
year_pct = 100 * year_n / sum(year_n);
year_cats = year_labels(year_group_idx);  % Use the same indices from groupcounts
tables.year = table(year_cats, year_n, year_pct, ...
    'VariableNames', {'Category', 'n', 'Percent'});

% AI methodology
[method_n, method_cats] = groupcounts(M.ai_method);
method_pct = 100 * method_n / sum(method_n);
tables.ai_method = table(method_cats, method_n, method_pct, ...
    'VariableNames', {'Category', 'n', 'Percent'});

% Domain
[domain_n, domain_cats] = groupcounts(M.domain);
domain_pct = 100 * domain_n / sum(domain_n);
tables.domain = table(domain_cats, domain_n, domain_pct, ...
    'VariableNames', {'Category', 'n', 'Percent'});

% Scale
[scale_n, scale_cats] = groupcounts(M.scale);
scale_pct = 100 * scale_n / sum(scale_n);
tables.scale = table(scale_cats, scale_n, scale_pct, ...
    'VariableNames', {'Category', 'n', 'Percent'});

% Validation: check percentages sum to ~100
stats = struct();
stats.year_pct_sum = sum(year_pct);
stats.method_pct_sum = sum(method_pct);
stats.domain_pct_sum = sum(domain_pct);
stats.scale_pct_sum = sum(scale_pct);

elapsed = toc;

% Debug output
fprintf('[DEBUG][group_counts] Year groups: n=%d\n', height(tables.year));
fprintf('[DEBUG][group_counts] AI methods: n=%d\n', height(tables.ai_method));
fprintf('[DEBUG][group_counts] Domains: n=%d\n', height(tables.domain));
fprintf('[DEBUG][group_counts] Scales: n=%d\n', height(tables.scale));
fprintf('[DEBUG][group_counts] Percentage sums: Year=%.1f%%, Method=%.1f%%, Domain=%.1f%%, Scale=%.1f%%\n', ...
    stats.year_pct_sum, stats.method_pct_sum, stats.domain_pct_sum, stats.scale_pct_sum);
fprintf('[DEBUG][group_counts] Elapsed=%.2fs\n', elapsed);

% Display tables
fprintf('[DEBUG][group_counts] Year distribution:\n');
disp(tables.year);

fprintf('[DEBUG][group_counts] AI method distribution:\n');
disp(tables.ai_method);

fprintf('[DEBUG][group_counts] Domain distribution:\n');
disp(tables.domain);

fprintf('[DEBUG][group_counts] Scale distribution:\n');
disp(tables.scale);
end
