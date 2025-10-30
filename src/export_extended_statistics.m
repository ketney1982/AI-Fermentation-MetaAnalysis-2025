function export_extended_statistics(output_dir, meta_cont_results, meta_diag_results, subgroup_results, M)
% EXPORT_EXTENDED_STATISTICS Export all statistical parameters from manuscript
%
% Exports:
%   - Extended meta-analysis statistics (I², τ², Q, p, PI)
%   - Subgroup analyses
%   - GRADE assessments
%   - Heterogeneity assessments

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('[EXPORT] Exporting extended statistics...\n');

%% 1. Extended Meta-Analysis Statistics
fprintf('  [1] Extended meta-analysis stats...\n');
extended_stats = table();

for i = 1:length(meta_cont_results)
    res = meta_cont_results{i};
    if isempty(res) || res.k < 3
        continue;
    end

    row = table();
    row.Metric = {res.metric};
    row.Model = {res.model};
    row.k = res.k;
    row.Effect = res.effect;
    row.SE = res.se;
    row.CI_Lower = res.ci_low;
    row.CI_Upper = res.ci_high;
    row.PI_Lower = res.pi_low;
    row.PI_Upper = res.pi_high;
    row.tau2 = res.tau2;
    row.I2_percent = res.I2;
    row.Q = res.Q;
    row.p_heterogeneity = res.p_het;
    row.p_overall = res.p;

    % Interpret I²
    if res.I2 < 25
        i2_interp = 'Low';
    elseif res.I2 < 50
        i2_interp = 'Moderate';
    elseif res.I2 < 75
        i2_interp = 'Substantial';
    else
        i2_interp = 'Considerable';
    end
    row.I2_Interpretation = {i2_interp};

    extended_stats = [extended_stats; row];
end

writetable(extended_stats, fullfile(output_dir, 'meta_extended_statistics.csv'));
fprintf('    ✓ Exported: meta_extended_statistics.csv\n');

%% 2. Heterogeneity Summary
fprintf('  [2] Heterogeneity summary...\n');
het_summary = table();

for i = 1:length(meta_cont_results)
    res = meta_cont_results{i};
    if isempty(res) || res.k < 3
        continue;
    end

    row = table();
    row.Outcome = {res.metric};
    row.I2_Percent = res.I2;
    row.tau2 = res.tau2;
    row.Q_statistic = res.Q;
    row.df = res.k - 1;
    row.p_value = res.p_het;

    if res.p_het < 0.10
        row.Significant = {'Yes (p<0.10)'};
    else
        row.Significant = {'No'};
    end

    het_summary = [het_summary; row];
end

writetable(het_summary, fullfile(output_dir, 'heterogeneity_summary.csv'));
fprintf('    ✓ Exported: heterogeneity_summary.csv\n');

%% 3. Subgroup Analyses (if available)
if ~isempty(subgroup_results)
    fprintf('  [3] Subgroup analyses...\n');

    for i = 1:length(subgroup_results)
        sub_res = subgroup_results{i};
        if isempty(sub_res)
            continue;
        end

        sub_table = table();
        for j = 1:length(sub_res.subgroups)
            grp = sub_res.subgroups{j};
            if isempty(grp)
                continue;
            end

            row = table();
            row.Grouping_Variable = {sub_res.grouping_var};
            row.Subgroup = {grp.group};
            row.k = grp.k;
            row.Mean = grp.mean;
            row.SE = grp.se;
            row.CI_Lower = grp.ci_low;
            row.CI_Upper = grp.ci_high;

            sub_table = [sub_table; row];
        end

        % Add between-group test (separate table to avoid type mismatch)
        summary_row = table();
        summary_row.Grouping_Variable = {sub_res.grouping_var};
        summary_row.Test = {'Between-group heterogeneity'};
        summary_row.Q_between = sub_res.Q_between;
        summary_row.df = sub_res.df_between;
        summary_row.p_value = sub_res.p_between;

        % Combine with main table (add summary stats as note)
        sub_table.Properties.Description = sprintf('Q_between=%.2f, df=%d, p=%.4f', ...
            sub_res.Q_between, sub_res.df_between, sub_res.p_between);

        % Export subgroup results
        filename = sprintf('subgroup_%s_by_%s.csv', sub_res.metric, sub_res.grouping_var);
        writetable(sub_table, fullfile(output_dir, filename));
        fprintf('    ✓ Exported: %s (Q_between=%.2f, p=%.4f)\n', filename, ...
            sub_res.Q_between, sub_res.p_between);

        % Export between-group test separately
        between_filename = sprintf('subgroup_%s_by_%s_heterogeneity.csv', sub_res.metric, sub_res.grouping_var);
        writetable(summary_row, fullfile(output_dir, between_filename));
    end
end

%% 4. Study Characteristics Summary
fprintf('  [4] Study characteristics...\n');
char_summary = table();

% Year distribution
years = M.year;
year_counts = [
    sum(years >= 2015 & years <= 2022);
    sum(years == 2023);
    sum(years == 2024);
    sum(years == 2025)
    ];
year_labels = {'2015-2022'; '2023'; '2024'; '2025'};

for i = 1:length(year_labels)
    row = table();
    row.Category = {'Year Range'};
    row.Subcategory = year_labels(i);
    row.Count = year_counts(i);
    row.Percent = 100 * year_counts(i) / height(M);
    char_summary = [char_summary; row];
end

% Scale distribution
scales = M.scale;
unique_scales = unique(scales);
for i = 1:length(unique_scales)
    row = table();
    row.Category = {'Experimental Scale'};
    row.Subcategory = unique_scales(i);
    row.Count = sum(strcmp(scales, unique_scales{i}));
    row.Percent = 100 * row.Count / height(M);
    char_summary = [char_summary; row];
end

writetable(char_summary, fullfile(output_dir, 'study_characteristics_extended.csv'));
fprintf('    ✓ Exported: study_characteristics_extended.csv\n');

fprintf('[EXPORT] Extended statistics export complete!\n');
end
