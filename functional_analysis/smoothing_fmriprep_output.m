% Smoothing to be done after fmri prep. 
clear;clc; 
% 2025-03-27 - smooths BOLD data using SPM. 
% needs to be able to rewrite smoothed files if you want to rerun.

% 2025-05-21 
% checks if there are smoothed files, if there is, then it deletes them IF
% you change the below value to = 1. 

%delete_old_smoothed_files = 1;
delete_old_smoothed_files = 0;


% smoothing parameter - Gomes, Figueiredo, Mayes 2015. 
smooth = [8 8 8];

%% GET LIST OF PARTICIPANTS FROM FMRIPREP OUTPUT FOLDERS
% Define the directory to search
parent_dir = '/media/lab/PutDataHere/COFA/COFA_bids/derivatives/fmriprep_slicetime';

% Get a list of folders in the parent directory
folders = dir(parent_dir);
folders = folders([folders.isdir]); 

% Initialize an empty cell array to store the folder names
sub_folders = {};

% Loop through the directories and find folders starting with "sub-"
for i = 1:length(folders)
    folder_name = folders(i).name;
    if startsWith(folder_name, 'sub-')
        % Remove the "sub-" prefix and add to the list
        sub_folders{end+1} = folder_name(5:end);  % Remove the first 4 characters ("sub-")
    end
end

%% LOOP THROUGH PARTICIPANTS

for p = 1:size(sub_folders, 2)
    participant = sub_folders{p}; 
    disp(participant);
    func_dir = sprintf('%s/sub-%s/func/',parent_dir, participant);


    % check if files already smoothed
    func_dir_files = dir(func_dir); 
    smoothed_files_indx = find(startsWith({func_dir_files.name}, "ssub")); 

    %option to delete previously smoothed files if you want to rewrite them
    if ~isempty(smoothed_files_indx & delete_old_smoothed_files == 1)
        files = dir(fullfile(func_dir, 'ss*.nii')); % Get all files starting with 'ss' and ending in '.nii'

        for k = 1:length(files)
            delete(fullfile(func_dir, files(k).name)); % Delete each matching file
        end

        smoothed_files_indx = find(startsWith({func_dir_files.name}, "ssub")); 
    end
    % check again now 
    smoothed_files_indx = find(startsWith({func_dir_files.name}, "ssub")); 
    % smooth files if the don't exist. 
    if isempty(smoothed_files_indx)

        % check for .nii files
        preproc_files_indx = find(endsWith({func_dir_files.name}, "desc-preproc_bold.nii")); 

% if .nii files don't exist, they may need to be extracted. 
        if isempty(preproc_files_indx)  

            preproc_files_gz_indx = find(endsWith({func_dir_files.name}, "desc-preproc_bold.nii.gz")); 
            preproc_files_gz = func_dir_files(preproc_files_gz_indx);

            for i = 1:length(preproc_files_gz)
                gunzip(sprintf("%s%s", func_dir, preproc_files_gz(i).name))
            end

            func_dir_files = dir(func_dir); 
            preproc_files_indx = find(endsWith({func_dir_files.name}, "desc-preproc_bold.nii")); 

        end 

        preproc_files = func_dir_files(preproc_files_indx);


%-----------------------------------------------------------------------
% Job saved on 12-Jul-2023 11:26:00 by cfg_util (rev $Rev: 7345 $)
% spm SPM - SPM12 (7771)
% cfg_basicio BasicIO - Unknown
%-----------------------------------------------------------------------
        for i = 1:length(preproc_files)

            file = {sprintf('%s%s', func_dir, preproc_files(i).name)};
            %print(file)


            matlabbatch{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.name = 'cofa';
            matlabbatch{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.files = {file};
            matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Named File Selector: cofa(1) - Files', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files', '{}',{1}));
            matlabbatch{2}.spm.spatial.smooth.fwhm = smooth;
            matlabbatch{2}.spm.spatial.smooth.dtype = 0;
            matlabbatch{2}.spm.spatial.smooth.im = 0;
            matlabbatch{2}.spm.spatial.smooth.prefix = 's';
        
        
            spm_jobman('run', matlabbatch);
    
        end 
    else 
    end 
end

