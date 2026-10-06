%% CONTRASTS
clear; clc;
base_dir = '/media/lab/bigbrains/COFA/COFA_bids/derivatives/first_level_test_slicetime/';
subj_dirs = dir(base_dir);
subject = {subj_dirs([subj_dirs.isdir]).name};
subjects = subject(contains(subject, 'O') | contains(subject, 'Y'));
exclude = {'sub-O403', 'sub-O405', 'sub-O421', 'sub-O427', 'sub-Y334'};
keep_indx = ~ismember(subjects, exclude);
subjects = subjects(keep_indx);
%subjects = subjects(27:end);
% Column layout per run: [Intact, Intact_PM, Rearranged, Rearranged_PM, nuisance x7]
% Run order: R1=FB  R2=FB
%
% Weights for a single run:
%   Intact < Rearranged = [-1, 0, +1, 0, zeros(1,7)]
%   Intact > Rearranged = [+1, 0, -1, 0, zeros(1,7)]
%
% For combined (2-run) contrasts, weights are 0.5 so the estimate
% reflects the average effect across runs rather than the sum.
% Single-run contrasts keep weight of 1.
z       = zeros(1,11);               % silent run (all zeros)
iLTr    = [-1,   0,  1,  0, zeros(1,7)];  % Intact < Rearranged, single run (weight=1)
iGTr    = [ 1,   0, -1,  0, zeros(1,7)];  % Intact > Rearranged, single run (weight=1)
iLTr_h  = [-0.5, 0, 0.5, 0, zeros(1,7)]; % Intact < Rearranged, half-weight for averaging
iGTr_h  = [ 0.5, 0,-0.5, 0, zeros(1,7)]; % Intact > Rearranged, half-weight for averaging
for sub = 1:length(subjects)
    func_dir     = fullfile(base_dir, subjects{sub});
    spm_mat_path = fullfile(func_dir, 'SPM.mat');
    delete(fullfile(func_dir, 'spmT*'));
if ~exist(spm_mat_path, 'file')
        warning('SPM.mat not found for %s. Skipping...', subjects{sub});
continue;
end
    matlabbatch = {};
    matlabbatch{1}.spm.stats.con.spmmat = {spm_mat_path};
    matlabbatch{1}.spm.stats.con.delete = 1;
    matlabbatch{1}.spm.stats.con.consess = {
% --- Full Binding: combined (R1+R2 averaged) ---
        struct('tcon', struct('name', 'FB: Intact < Rearranged', ...
'weights', [iLTr_h, iLTr_h], 'sessrep', 'none'))
        struct('tcon', struct('name', 'FB: Intact > Rearranged', ...
'weights', [iGTr_h, iGTr_h], 'sessrep', 'none'))
% --- Full Binding: per run ---
        struct('tcon', struct('name', 'FB: Intact < Rearranged (R1 only)', ...
'weights', [iLTr, z], 'sessrep', 'none'))
        struct('tcon', struct('name', 'FB: Intact < Rearranged (R2 only)', ...
'weights', [z, iLTr], 'sessrep', 'none'))
    };
    spm_jobman('run', matlabbatch);
end