function T = parse_ris(ris_file_path)
% PARSE_RIS Parse RIS format file and produce normalized table
%
% Inputs:
%   ris_file_path - Path to .RIS file
%
% Outputs:
%   T - Table with standardized columns: TY, AU, A1, A2, TI, T2, PY, Y1,
%       DO, SN, VL, IS, SP, EP, AB, KW
%
% Debug logging: record count, type distribution, missing DOI count

tic;
fprintf('[DEBUG][parse_ris] Started parsing: %s\n', ris_file_path);

% Validate input file
if ~isfile(ris_file_path)
    error('parse_ris:FileNotFound', 'RIS file not found: %s', ris_file_path);
end

% Read entire file
fid = fopen(ris_file_path, 'r', 'n', 'UTF-8');
if fid == -1
    error('parse_ris:CannotOpen', 'Cannot open RIS file: %s', ris_file_path);
end
content = fread(fid, '*char')';
fclose(fid);

fprintf('[DEBUG][parse_ris] File size: %d bytes\n', length(content));

% Split into records (separated by "ER  -")
records = strsplit(content, 'ER  -');
records = records(~cellfun(@isempty, strtrim(records)));

num_records = length(records);
fprintf('[DEBUG][parse_ris] Raw records found: %d\n', num_records);

if num_records == 0
    warning('parse_ris:NoRecords', 'No records found in RIS file');
    T = create_empty_table();
    return;
end

% Initialize cell arrays for each column
TY = cell(num_records, 1);
AU = cell(num_records, 1);
A1 = cell(num_records, 1);
A2 = cell(num_records, 1);
TI = cell(num_records, 1);
T2 = cell(num_records, 1);
PY = cell(num_records, 1);
Y1 = cell(num_records, 1);
DO = cell(num_records, 1);
SN = cell(num_records, 1);
VL = cell(num_records, 1);
IS = cell(num_records, 1);
SP = cell(num_records, 1);
EP = cell(num_records, 1);
AB = cell(num_records, 1);
KW = cell(num_records, 1);

% Parse each record
for i = 1:num_records
    record_text = records{i};
    lines = strsplit(record_text, '\n');

    % Extract fields
    TY{i} = extract_field(lines, 'TY');
    AU{i} = extract_multiline_field(lines, 'AU');
    A1{i} = extract_multiline_field(lines, 'A1');
    A2{i} = extract_multiline_field(lines, 'A2');
    TI{i} = extract_field(lines, 'TI');
    T2{i} = extract_field(lines, 'T2');
    PY{i} = extract_field(lines, 'PY');
    Y1{i} = extract_field(lines, 'Y1');
    DO{i} = extract_field(lines, 'DO');
    SN{i} = extract_field(lines, 'SN');
    VL{i} = extract_field(lines, 'VL');
    IS{i} = extract_field(lines, 'IS');
    SP{i} = extract_field(lines, 'SP');
    EP{i} = extract_field(lines, 'EP');
    AB{i} = extract_field(lines, 'AB');
    KW{i} = extract_multiline_field(lines, 'KW');
end

% Create table
T = table(TY, AU, A1, A2, TI, T2, PY, Y1, DO, SN, VL, IS, SP, EP, AB, KW);

% Normalize authors (use AU if present, otherwise A1)
for i = 1:height(T)
    if isempty(T.AU{i}) && ~isempty(T.A1{i})
        T.AU{i} = T.A1{i};
    end
end

% Calculate statistics
missing_doi = sum(cellfun(@isempty, T.DO));
type_counts = tabulate(T.TY);

elapsed = toc;

% Debug output
fprintf('[DEBUG][parse_ris] Records=%d | Elapsed=%.2fs\n', height(T), elapsed);
fprintf('[DEBUG][parse_ris] MissingDOI=%d (%.1f%%)\n', missing_doi, 100*missing_doi/height(T));
fprintf('[DEBUG][parse_ris] Type distribution:\n');
for j = 1:size(type_counts, 1)
    if ~isempty(type_counts{j,1})
        fprintf('  %s: %d (%.1f%%)\n', type_counts{j,1}, type_counts{j,2}, type_counts{j,3});
    end
end

% Show first 5 rows summary
fprintf('[DEBUG][parse_ris] First 5 rows summary:\n');
for i = 1:min(5, height(T))
    fprintf('  Row %d: TY=%s | TI=%s | PY=%s | DO=%s\n', ...
        i, T.TY{i}, truncate_string(T.TI{i}, 40), T.PY{i}, T.DO{i});
end
end

function val = extract_field(lines, tag)
% Extract single-line field value
val = '';
pattern = sprintf('^%s  - (.*)$', tag);
for i = 1:length(lines)
    tokens = regexp(lines{i}, pattern, 'tokens');
    if ~isempty(tokens)
        val = strtrim(tokens{1}{1});
        return;
    end
end
end

function val = extract_multiline_field(lines, tag)
% Extract multi-line field (e.g., AU, KW) - concatenate with semicolon
vals = {};
pattern = sprintf('^%s  - (.*)$', tag);
for i = 1:length(lines)
    tokens = regexp(lines{i}, pattern, 'tokens');
    if ~isempty(tokens)
        vals{end+1} = strtrim(tokens{1}{1});
    end
end
val = strjoin(vals, '; ');
end

function T = create_empty_table()
% Create empty table with standard columns
T = table();
T.TY = {};
T.AU = {};
T.A1 = {};
T.A2 = {};
T.TI = {};
T.T2 = {};
T.PY = {};
T.Y1 = {};
T.DO = {};
T.SN = {};
T.VL = {};
T.IS = {};
T.SP = {};
T.EP = {};
T.AB = {};
T.KW = {};
end

function s = truncate_string(str, max_len)
% Truncate string for display
if isempty(str)
    s = '(empty)';
elseif length(str) > max_len
    s = [str(1:max_len) '...'];
else
    s = str;
end
end
