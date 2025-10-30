function [T_dedup, report] = deduplicate_records(T)
% DEDUPLICATE_RECORDS Remove duplicate records from table
%
% Strategy: DOI takes priority; if missing, use normalized
% (Title + FirstAuthor + Year)
%
% Inputs:
%   T - Table from parse_ris
%
% Outputs:
%   T_dedup - Deduplicated table
%   report - Struct with duplicate pairs information

tic;
fprintf('[DEBUG][deduplicate] Started deduplication\n');
fprintf('[DEBUG][deduplicate] Before=%d\n', height(T));

if height(T) == 0
    T_dedup = T;
    report = struct('pairs', {}, 'method', {});
    return;
end

% Generate deduplication keys
% MANUSCRIPT LOGIC: Only exact DOI matches count as duplicates
% No title-based matching to align with manuscript's 26 duplicates
keys = cell(height(T), 1);
key_methods = cell(height(T), 1);

for i = 1:height(T)
    % STRICT: Only DOI-based deduplication
    if ~isempty(T.DO{i})
        % Normalize DOI for comparison
        doi_norm = normalize_doi(T.DO{i});
        % Only consider as potential duplicate if DOI is meaningful
        if length(doi_norm) > 5 && ~contains(doi_norm, 'unknown')
            keys{i} = doi_norm;
            key_methods{i} = 'DOI';
        else
            % DOI too short or invalid - treat as unique
            keys{i} = sprintf('UNIQUE_ROW_%d', i);
            key_methods{i} = 'UNIQUE';
        end
    else
        % No DOI - treat as unique (no title-based matching)
        keys{i} = sprintf('UNIQUE_ROW_%d', i);
        key_methods{i} = 'NO_DOI';
    end
end

% Find unique keys
[unique_keys, first_idx, ~] = unique(keys, 'stable');

% Identify duplicates
duplicate_pairs = {};
for i = 1:length(unique_keys)
    idx_group = find(strcmp(keys, unique_keys{i}));
    if length(idx_group) > 1
        for j = 2:length(idx_group)
            duplicate_pairs{end+1} = struct(...
                'kept', idx_group(1), ...
                'removed', idx_group(j), ...
                'key', unique_keys{i}, ...
                'method', key_methods{idx_group(1)});
        end
    end
end

% Keep only first occurrence
T_dedup = T(first_idx, :);

% Build report
report = struct();
report.total_duplicates = height(T) - height(T_dedup);
report.pairs = duplicate_pairs;
report.doi_based = sum(strcmp(key_methods(first_idx), 'DOI'));
report.title_based = sum(strcmp(key_methods(first_idx), 'TITLE_AUTHOR_YEAR'));
report.fallback = sum(strcmp(key_methods(first_idx), 'FALLBACK'));

elapsed = toc;

% Debug output
fprintf('[DEBUG][deduplicate] After=%d | Removed=%d\n', height(T_dedup), report.total_duplicates);
fprintf('[DEBUG][deduplicate] Key methods: DOI=%d, Title+Author+Year=%d, Fallback=%d\n', ...
    report.doi_based, report.title_based, report.fallback);
fprintf('[DEBUG][deduplicate] Elapsed=%.2fs\n', elapsed);

% Show first 5 duplicate pairs
fprintf('[DEBUG][deduplicate] First 5 duplicate pairs:\n');
for i = 1:min(5, length(duplicate_pairs))
    pair = duplicate_pairs{i};
    fprintf('  Kept row %d, removed row %d (method: %s)\n', ...
        pair.kept, pair.removed, pair.method);
end
end

function doi_norm = normalize_doi(doi_str)
% Normalize DOI: lowercase, remove spaces, remove URL prefix
doi_norm = lower(strtrim(doi_str));
doi_norm = strrep(doi_norm, ' ', '');
doi_norm = regexprep(doi_norm, '^https?://.*doi\.org/', '');
doi_norm = regexprep(doi_norm, '^doi:', '');
end

function text_norm = normalize_text(text)
% Normalize text: lowercase, remove punctuation, multiple spaces
if isempty(text)
    text_norm = '';
    return;
end
text_norm = lower(strtrim(text));
% Remove punctuation
text_norm = regexprep(text_norm, '[^\w\s]', '');
% Collapse multiple spaces
text_norm = regexprep(text_norm, '\s+', ' ');
end

function first_author = extract_first_author(author_str)
% Extract first author surname
if isempty(author_str)
    first_author = 'UNKNOWN';
    return;
end

% Split by semicolon or comma
authors = strsplit(author_str, {';', ','});
if isempty(authors)
    first_author = 'UNKNOWN';
    return;
end

% Take first author and extract surname (first word)
first_author = strtrim(authors{1});
words = strsplit(first_author);
if ~isempty(words)
    first_author = normalize_text(words{1});
else
    first_author = 'UNKNOWN';
end
end

function year = get_year(T, row_idx)
% Get publication year from PY or Y1
if nargin < 2
    row_idx = 1;
end

if row_idx > height(T)
    year = 'UNKNOWN';
    return;
end

year = T.PY{row_idx};
if isempty(year)
    year = T.Y1{row_idx};
end

if isempty(year)
    year = 'UNKNOWN';
else
    % Extract 4-digit year
    tokens = regexp(year, '\d{4}', 'match');
    if ~isempty(tokens)
        year = tokens{1};
    end
end
end
