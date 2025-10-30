function grade_table = assess_grade_certainty(meta_results, study_characteristics)
% ASSESS_GRADE_CERTAINTY Evaluate certainty of evidence using GRADE framework
%
% Inputs:
%   meta_results - Struct with meta-analysis results (effect, CI, I2, etc.)
%   study_characteristics - Struct with study info (risk_of_bias, etc.)
%
% Outputs:
%   grade_table - Table with GRADE assessment for each outcome

fprintf('[DEBUG][GRADE] Assessing certainty of evidence...\n');

% Initialize starting rating (MODERATE for observational AI/ML studies)
starting_rating = 3; % 4=HIGH, 3=MODERATE, 2=LOW, 1=VERY LOW

% DOWNGRADE CRITERIA

% 1. Risk of Bias
rob_downgrade = 0;
if study_characteristics.high_risk_pct > 0.75
    rob_downgrade = 2; % Serious limitation
elseif study_characteristics.high_risk_pct > 0.50
    rob_downgrade = 1; % Some limitation
end

% 2. Inconsistency (based on I²)
I2 = meta_results.I2;
inconsistency_downgrade = 0;
if I2 > 75
    inconsistency_downgrade = 2; % Serious inconsistency
elseif I2 > 50
    inconsistency_downgrade = 1; % Some inconsistency
end

% 3. Indirectness (assume moderate if different populations/settings)
indirectness_downgrade = 0;
if study_characteristics.diverse_populations
    indirectness_downgrade = 1;
end

% 4. Imprecision (based on CI width and sample size)
ci_width = meta_results.ci_high - meta_results.ci_low;
relative_ci = ci_width / abs(meta_results.effect);
imprecision_downgrade = 0;
if relative_ci > 0.5 || meta_results.k < 10
    imprecision_downgrade = 1; % Some imprecision
end
if relative_ci > 1.0 || meta_results.k < 5
    imprecision_downgrade = 2; % Serious imprecision
end

% 5. Publication Bias
pub_bias_downgrade = 0;
if isfield(meta_results, 'egger_p') && meta_results.egger_p < 0.05
    pub_bias_downgrade = 1; % Evidence of publication bias
end

% Total downgrade
total_downgrade = rob_downgrade + inconsistency_downgrade + ...
    indirectness_downgrade + imprecision_downgrade + pub_bias_downgrade;

% Final rating
final_rating = max(1, starting_rating - total_downgrade);

% Convert to categorical
rating_labels = {'VERY LOW', 'LOW', 'MODERATE', 'HIGH'};
final_label = rating_labels{final_rating};

% Create summary
grade_table = table();
grade_table.Outcome = {meta_results.metric};
grade_table.N_Studies = meta_results.k;
grade_table.Effect = meta_results.effect;
grade_table.CI_Lower = meta_results.ci_low;
grade_table.CI_Upper = meta_results.ci_high;
grade_table.I2_Percent = I2;
grade_table.Starting_Rating = starting_rating;
grade_table.RoB_Downgrade = rob_downgrade;
grade_table.Inconsistency_Downgrade = inconsistency_downgrade;
grade_table.Indirectness_Downgrade = indirectness_downgrade;
grade_table.Imprecision_Downgrade = imprecision_downgrade;
grade_table.PubBias_Downgrade = pub_bias_downgrade;
grade_table.Total_Downgrade = total_downgrade;
grade_table.Final_Rating = final_rating;
grade_table.Certainty = {final_label};

fprintf('[DEBUG][GRADE] Outcome: %s\n', meta_results.metric);
fprintf('[DEBUG][GRADE] Starting: %s (%d)\n', rating_labels{starting_rating}, starting_rating);
fprintf('[DEBUG][GRADE] Downgrades: RoB=%d, Incons=%d, Indir=%d, Imprec=%d, PubBias=%d\n', ...
    rob_downgrade, inconsistency_downgrade, indirectness_downgrade, imprecision_downgrade, pub_bias_downgrade);
fprintf('[DEBUG][GRADE] Final: %s (%d)\n', final_label, final_rating);

end
