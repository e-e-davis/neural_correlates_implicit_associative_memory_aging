%addpath('/usr/local/MATLAB/R2025b/toolbox/spm_25.01.02/spm')
clear;clc;
%% Indicate second level information 
condition_folder = 'second_level_full-binding';
contrast = 'con_0012.nii'; 

%% Get participants and set up folders 
preproc_dir = '/media/lab/bigbrains/COFA/COFA_bids/derivatives/';
root_dir = sprintf('%sfmriprep_slicetime/',preproc_dir);
all_dirs = dir(root_dir);
participants = {all_dirs([all_dirs.isdir]).name};
participants = participants(contains(participants, 'sub-O') | contains(participants, 'sub-Y'));
output_folder = sprintf('%s%s', preproc_dir, condition_folder);

% Participants to exclude 
exclude = {'sub-O403', 'sub-O405', 'sub-O421', 'sub-O427', 'sub-Y334', 'sub-Y303'};
keep_indx = ~ismember(participants, exclude);
participants = participants(keep_indx);

%% Get correct contrasts from first level. 
cons = cell(length(participants),1);
for i = 1:length(participants)
    sub = char(participants(i));
    sub = erase(sub, 'sub-');
    cons{i} = sprintf('%sfirst_level_test_slicetime/%s/%s,1', preproc_dir, sub, contrast);
end

% Split groups by subject ID prefix
young_idx = contains(participants, 'sub-Y');
old_idx = contains(participants, 'sub-O');

young_scans = cons(young_idx);  % cell array of scans for younger group
old_scans = cons(old_idx); 

%-----------------------------------------------------------------------
% Job saved on 02-Nov-2025 14:18:31 by cfg_util (rev $Rev: 8183 $)
% spm SPM - SPM25 (25.01.02)
% cfg_basicio BasicIO - Unknown
%-----------------------------------------------------------------------
matlabbatch{1}.spm.stats.factorial_design.dir = {output_folder};
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = young_scans;
matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = old_scans;
matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

spm_jobman('run', matlabbatch);