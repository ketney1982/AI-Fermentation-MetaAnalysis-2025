function [T_filtered, counts] = eligibility_filter(T, config)
% ELIGIBILITY_FILTER Apply inclusion/exclusion criteria
%
% Filters based on:
%   - AI/ML keywords in title/abstract
%   - Fermentation/foam keywords in title/abstract
%   - Exclusion keywords
%   - Document type
%
% Inputs:
%   T - Table of records
%   config - Configuration struct from JSON
%
% Outputs:
%   T_filtered - Table with added columns: eligible_flag, meta89_flag,
%                exclusion_reason
%   counts - Struct with PRISMA flow counts

tic;
fprintf('[DEBUG][eligibility] Started eligibility screening\n');
fprintf('[DEBUG][eligibility] Screened=%d\n', height(T));

if height(T) == 0
    T_filtered = T;
    T_filtered.eligible_flag = logical([]);
    T_filtered.meta89_flag = logical([]);
    T_filtered.exclusion_reason = {};
    counts = create_empty_counts();
    return;
end

% Initialize flags
eligible_flag = true(height(T), 1);
meta89_flag = false(height(T), 1);
exclusion_reason = cell(height(T), 1);

% Counters for exclusion reasons
excluded_ai_absent = 0;
excluded_topic_mismatch = 0;
excluded_abstract_only = 0;
excluded_type = 0;

for i = 1:height(T)
    reasons = {};

    % Check document type (exclude reviews, protocols, etc.)
    doc_type = lower(T.TY{i});
    if ismember(doc_type, {'review', 'editorial', 'letter', 'note'})
        eligible_flag(i) = false;
        reasons{end+1} = 'DOCUMENT_TYPE';
        excluded_type = excluded_type + 1;
    end

    % Check for exclusion keywords in title/abstract
    title_abstract = [T.TI{i} ' ' T.AB{i}];
    if has_exclusion_keyword(title_abstract, config.exclude_keywords)
        eligible_flag(i) = false;
        reasons{end+1} = 'EXCLUSION_KEYWORD';
        excluded_type = excluded_type + 1;
    end

    % Check for AI/ML keywords
    has_ai = has_keyword(title_abstract, config.ai_keywords_include);
    if ~has_ai
        eligible_flag(i) = false;
        reasons{end+1} = 'AI_ABSENT';
        excluded_ai_absent = excluded_ai_absent + 1;
    end

    % Check for fermentation keywords
    has_fermentation = has_keyword(title_abstract, config.fermentation_keywords);
    if ~has_fermentation
        eligible_flag(i) = false;
        reasons{end+1} = 'TOPIC_MISMATCH';
        excluded_topic_mismatch = excluded_topic_mismatch + 1;
    end

    % Check if abstract is missing
    if isempty(T.AB{i}) || length(strtrim(T.AB{i})) < 50
        if eligible_flag(i)
            eligible_flag(i) = false;
            reasons{end+1} = 'ABSTRACT_MISSING';
            excluded_abstract_only = excluded_abstract_only + 1;
        end
    end

    % Mark for meta-analysis (subset of eligible with high quality indicators)
    if eligible_flag(i)
        % Additional criteria for meta-analysis inclusion
        has_doi = ~isempty(T.DO{i});
        has_year = ~isempty(T.PY{i}) || ~isempty(T.Y1{i});
        abstract_length = length(T.AB{i});

        if has_doi && has_year && abstract_length > 100
            meta89_flag(i) = true;
        end
    end

    % Store reasons
    if isempty(reasons)
        exclusion_reason{i} = '';
    else
        exclusion_reason{i} = strjoin(reasons, '; ');
    end
end

% Add columns to table
T_filtered = T;
T_filtered.eligible_flag = eligible_flag;
T_filtered.meta89_flag = meta89_flag;
T_filtered.exclusion_reason = exclusion_reason;

% Calculate PRISMA counts
counts = struct();
counts.screened = height(T);
counts.eligible = sum(eligible_flag);
counts.for_meta = sum(meta89_flag);
counts.excluded_total = height(T) - sum(eligible_flag);
counts.excluded_ai_absent = excluded_ai_absent;
counts.excluded_topic_mismatch = excluded_topic_mismatch;
counts.excluded_abstract_only = excluded_abstract_only;
counts.excluded_type = excluded_type;

% Add full-text assessment count (assume all screened go to full-text for now)
% This will need manual adjustment based on actual manuscript numbers
counts.full_text_assessed = counts.screened;
counts.excluded = counts.excluded_total;

elapsed = toc;

% Debug output
fprintf('[DEBUG][eligibility] Eligible=%d (%.1f%%)\n', counts.eligible, ...
    100*counts.eligible/counts.screened);
fprintf('[DEBUG][eligibility] ForMeta=%d (%.1f%%)\n', counts.for_meta, ...
    100*counts.for_meta/counts.screened);
fprintf('[DEBUG][eligibility] Excluded: AI_absent=%d, Topic=%d, Abstract=%d, Type=%d\n', ...
    excluded_ai_absent, excluded_topic_mismatch, excluded_abstract_only, excluded_type);
fprintf('[DEBUG][eligibility] Elapsed=%.2fs\n', elapsed);

% Show first 5 eligible records
fprintf('[DEBUG][eligibility] First 5 eligible records:\n');
eligible_idx = find(eligible_flag);
for i = 1:min(5, length(eligible_idx))
    idx = eligible_idx(i);
    fprintf('  Row %d: %s (%s)\n', idx, truncate_string(T.TI{idx}, 60), T.PY{idx});
end
end

function result = has_keyword(text, keywords)
% Check if any keyword appears in text (case-insensitive)
result = false;
if isempty(text)
    return;
end

text_lower = lower(text);
for i = 1:length(keywords)
    if contains(text_lower, lower(keywords{i}))
        result = true;
        return;
    end
end
end

function result = has_exclusion_keyword(text, keywords)
% Check if any exclusion keyword appears
result = has_keyword(text, keywords);
end

function counts = create_empty_counts()
counts = struct();
counts.screened = 0;
counts.eligible = 0;
counts.for_meta = 0;
counts.excluded_total = 0;
counts.excluded_ai_absent = 0;
counts.excluded_topic_mismatch = 0;
counts.excluded_abstract_only = 0;
counts.excluded_type = 0;
end

function s = truncate_string(str, max_len)
if isempty(str)
    s = '(empty)';
elseif length(str) > max_len
    s = [str(1:max_len) '...'];
else
    s = str;
end
end
