clear; clc;
%addpath('/usr/local/MATLAB/R2025b/toolbox/spm_25.01.02/spm')
spm_dir = '/usr/local/MATLAB/R2025b/toolbox/spm_25.01.02/spm';
addpath(genpath(fullfile(spm_dir, 'toolbox', 'marsbar')));
marsbar('on');

%% Set up paths
preproc_dir  = '/media/lab/bigbrains/COFA/COFA_bids/derivatives/';
roi_base_dir = fullfile(preproc_dir, 'itksnap-T1-20260529');
tmp_dir      = fullfile(preproc_dir, 'tmp_gunzip');
if ~exist(tmp_dir, 'dir'), mkdir(tmp_dir); end
folder    = 'second_level_full-binding_slicetime_20260608';
condition = 'fb';
masks     = ["leftAnteriorHipp_space-MNI_2mm.nii.gz",   "rightAnteriorHipp_space-MNI_2mm.nii.gz", ...
"leftPosteriorHipp_space-MNI_2mm.nii.gz",  "rightPosteriorHipp_space-MNI_2mm.nii.gz", ...
"rightPHC_space-MNI_2mm.nii.gz",           "leftPHC_space-MNI_2mm.nii.gz", ...
"leftPRC_space-MNI_2mm.nii.gz",            "rightPRC_space-MNI_2mm.nii.gz"];

%% Load behavioural data
csv_path    = fullfile(preproc_dir, 'behav', 'ca-fmri-2025-10-03.csv');
csv_data    = readtable(csv_path, "FileType", "text", "Delimiter", ",");
sorted_data = sortrows(csv_data, 'subject_id', 'ascend');
%% Load SPM and extract participant numbers
load(sprintf('/media/lab/bigbrains/COFA/COFA_bids/derivatives/%s/SPM.mat', folder))
SPM.xY.P = strrep(SPM.xY.P, '/media/lab/PutDataHere/', '/media/lab/bigbrains/');
participant_nums = nan(length(SPM.xY.P), 1);
for id = 1:length(SPM.xY.P)
    tokens = regexp(SPM.xY.P{id}, '/[OY](\d{3})/', 'tokens');
if ~isempty(tokens)
        participant_nums(id) = str2double(tokens{1}{1});
end
end
disp(participant_nums)
%% Set up behavioural table trimmed to subjects with neural data
keep_mask   = ismember(sorted_data.subject_id, participant_nums);
sorted_data = sorted_data(keep_mask, :);
age       = sorted_data.age;
age_group = nan(size(age));
age_group(isnan(age) | age > 55) =  0.5;
age_group(age <= 55)             = -0.5;
data_table = table(participant_nums, age_group, 'VariableNames', {'subject', 'age_group'});
%% Extract ROI data
for m = 1:length(masks)
    mask_name = masks(m);
    roi_data  = nan(length(participant_nums), 1);
for id = 1:length(participant_nums)
        sub_num = participant_nums(id);
if sub_num >= 400
            prefix = 'O';
else
            prefix = 'Y';
end
        sub_label = sprintf('sub-%s%03d', prefix, sub_num);
        mask_gz = fullfile(roi_base_dir, sub_label, 'ROIs_MNI', '2mm', mask_name);
if ~exist(mask_gz, 'file')
            warning('Mask not found for %s: %s — leaving NaN', sub_label, mask_name);
continue;
end
% Gunzip to temp dir
        tmp_file = gunzip(mask_gz, tmp_dir);
        tmp_file = tmp_file{1};
        roi_data(id) = Extract_ROI_Data(tmp_file, SPM.xY.P{id});
        delete(tmp_file);
end
    col_name   = sprintf('%s_%s', condition, strrep(mask_name, '_space-MNI_2mm.nii.gz', ''));
    data_table = addvars(data_table, roi_data, 'NewVariableNames', col_name);
end
all_data = [sorted_data, data_table];
writetable(all_data, 'behaviour_brain_test_2mm_2026-09-17.csv')
% Clean up temp dir
rmdir(tmp_dir, 's');

function roi_data = Extract_ROI_Data(mask_nii, contrast_path)
% Ensure MarsBaR classes are on path
    spm_dir  = fileparts(which('spm'));
% Create ROI object directly from filename string
    roi      = maroi_image(mask_nii);
% Extract mean data from contrast image
    V        = spm_vol(contrast_path);
    marsY    = get_marsy(roi, V, 'mean');
    roi_data = summary_data(marsY);
end