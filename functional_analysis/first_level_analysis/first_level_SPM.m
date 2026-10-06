clear;clc;

% First level model for fb test
% 2025-05-01 

% Global information
TR = 2;
picture_duration = 0; % Gomes et al. Otherwise, trial was 2s duration. 
key_press_dur = 0;
first_level_folder_name = 'first_level_test_slicetime';
n_slices = 69;

% Define condition types and run numbers
conditions = {'fbTest'};
runs = [1, 2];

% Get directories and participants
root_dir = '/media/lab/bigbrains/COFA/COFA_bids/derivatives/fmriprep_slicetime/';
all_dirs = dir(root_dir);
participants = {all_dirs([all_dirs.isdir]).name};
participants = participants(contains(participants, 'sub-O') | contains(participants, 'sub-Y'));

% Participants to exclude 
exclude = {'sub-O403', 'sub-O405', 'sub-O421', 'sub-O427', 'sub-Y334'};
keep_indx = ~ismember(participants, exclude);
participants = participants(keep_indx);

% looking at particular participants
% participants = participants(28:end);
% participants = participants(51);

% Start first level 
for p = 1:length(participants)

    participant = erase(participants{p}, 'sub-');  % e.g., 'O401'

    fprintf('Processing participant: %s\n', participant);

    % Mark directories & get lists of necessary files
    func_dir = sprintf('%ssub-%s/func/', root_dir, participant);
    behav_dir = sprintf('/media/lab/bigbrains/COFA/COFA_bids/raw_data/sub-%s/func/', participant);
    first_level_dir = sprintf('/media/lab/bigbrains/COFA/COFA_bids/derivatives/%s/%s', first_level_folder_name, participant);
    if ~exist(first_level_dir, 'dir')
        mkdir(first_level_dir)
    end

    % get smoothed .nii files
    func_dir_files = dir(func_dir);
    preproc_files_indx = find(startsWith({func_dir_files.name}, "ss"));
    preproc_files = func_dir_files(preproc_files_indx);

    fb_Test1_pattern = 'fbTest_run-1';
    match_idx = find(contains({preproc_files.name}, fb_Test1_pattern));
    path_epi_fbTest_session1 = fullfile(func_dir, preproc_files(match_idx).name);

    fb_Test2_pattern = 'fbTest_run-2';
    match_idx = find(contains({preproc_files.name}, fb_Test2_pattern));
    path_epi_fbTest_session2 = fullfile(func_dir, preproc_files(match_idx).name);


    % get confounds files
    confounds_files_indx = find(endsWith({func_dir_files.name}, "desc-confounds_timeseries.tsv"));
    confounds_files = func_dir_files(confounds_files_indx);

    %% chatgbt - get nuisance regressors and save them to txt file in func dir.
    % Initialize structure to hold all motion regressors
    motion_data = struct();

    % Loop through all condition/run combos
    for i = 1:length(conditions)
        for j = 1:length(runs)
            cond = conditions{i};
            run_num = runs(j);

            % Create pattern to search
            pattern = sprintf('task-%s_run-%d', cond, run_num);

            % Find the file matching the pattern
            match_idx = find(contains({confounds_files.name}, pattern));

            if isempty(match_idx)
                warning('No file found for %s run-%d', cond, run_num);
                continue
            end

            % Load the confounds TSV
            tsv_path = fullfile(func_dir, confounds_files(match_idx).name);
            tsv_data = readtable(tsv_path, "FileType", "text", "Delimiter", "\t");

            % Extract motion regressors
            % global singal
            % gomes included session effects, which to my understanding spm
            % does automatically. 
            motion_cols = {'rot_x', 'rot_y', 'rot_z', 'trans_x', 'trans_y', 'trans_z', 'global_signal'};
            if all(ismember(motion_cols, tsv_data.Properties.VariableNames))
                motion_array = table2array(tsv_data(:, motion_cols));
            else
                warning('Motion columns missing in %s', confounds_files(match_idx).name);
            end


            % Save into the structure
            % Motion 
            fieldname = sprintf('%s_run%d', cond, run_num);  % e.g., fbTest_run1
            motion_data.(fieldname) = motion_array;
            % 
            % % Framewise displacement
            % fd = mean(table2array(tsv_data(:, "framewise_displacement")), 'omitnan');
            % mean_framewise_displacement.(participant){i, j} = fd;
            % mean_framewise_displacement.(participant){i, 3} = cond;
            % 
            % 
            % Optionally, also save to a file:
            save_path = fullfile(func_dir, sprintf('motion_regressors_%s_run%d.txt', cond, run_num));
            save(save_path, 'motion_array', '-ascii');
        end
    end
    
    %mean_framewise_displacement.(participant){3} = conditions;

  
    %% end chatgbt

    % import onsets
    behav_dir_files = dir(behav_dir);
    behav_files_indx = find(endsWith({behav_dir_files.name}, ".tsv") & ...
                            contains({behav_dir_files.name}, "fbTest"));
    behav_files = behav_dir_files(behav_files_indx);

    key_encode = (1:88)';
    onsets_table_encode = array2table(key_encode);

    key_test = (1:44)';
    onsets_table_test = array2table(key_test);

    for i = 1:length(behav_files)

        df = readtable(sprintf('%s%s',behav_dir,behav_files(i).name), "FileType","text",'Delimiter', '\t', 'TreatAsEmpty', 'NA');

        task = erase(behav_files(i).name, "_events.tsv");
        task = erase(task, sprintf("sub-%s_task-", participant));
    
        % Participant 418 is missing two trials and matlab doesn't like
        % that
        if strcmp(participant, 'O418') && strcmp(task, 'fbTest_run-2')
            % Create a copy of the first 2 rows to preserve structure
            na_rows = df(1:2, :);

            % Loop through columns and assign appropriate placeholder values
            for col = 1:width(df)
                var = df{:, col};

                if isnumeric(var)
                    na_rows{:, col} = NaN;

                elseif islogical(var)
                    na_rows{:, col} = false;  % or NaN, but false is default

                elseif iscell(var)  % likely a cell array of strings
                    na_rows{:, col} = {''; ''};  % or {'NA'; 'NA'} if preferred

                elseif isstring(var)
                    na_rows{:, col} = strings(2, 1);  % string missing values

                elseif iscategorical(var)
                    na_rows{:, col} = categorical({missing, missing});

                else
                    % Fallback for any other type
                    na_rows{:, col} = missing;
                end
            end

            % Append to original table
            df = [df; na_rows];

        end

        onset = df.onset;
        keypress = df.keypress_onset_corr;
        condition = df.Task_condition;
        accuracy = df.accuracy;
        rt = df.rt;

        if length(onset) == 88
            key = key_encode;
        else
            key = key_test;
        end

        onsets = table(key, onset, keypress, condition, accuracy, rt);
        onsets = renamevars(onsets,["onset", "keypress", "condition", "accuracy", "rt"], ...
            [sprintf("%s_onset", task),sprintf("%s_keypress", task),sprintf("%s_condition", task), ...
            sprintf("%s_accuracy", task), sprintf("%s_rt", task)]);
      

        if length(onset) == 88
            onsets = renamevars(onsets, "key", "key_encode");
            onsets_table_encode = join(onsets_table_encode, onsets);
        else
            onsets = renamevars(onsets, "key", "key_test");
            onsets_table_test = join(onsets_table_test, onsets);
        end

    end

    % onsets fb run 1
    % trials
    is_intact = strcmp(onsets_table_test.("fbTest_run-1_condition"), 'intact') & ...
                    onsets_table_test.("fbTest_run-1_accuracy") == 1;
    fb_run1_intact_onset = {onsets_table_test.("fbTest_run-1_onset")(is_intact)};

    is_repaired = strcmp(onsets_table_test.("fbTest_run-1_condition"), 'repaired') & ...
                    onsets_table_test.("fbTest_run-1_accuracy") == 1;
    fb_run1_repaired_onset = {onsets_table_test.("fbTest_run-1_onset")(is_repaired)};

    % RT 
    fb_run1_rt_intact_onset = rmmissing(onsets_table_test.('fbTest_run-1_rt')(is_intact));
    fb_run1_rt_intact_onset_c =  fb_run1_rt_intact_onset - mean(fb_run1_rt_intact_onset, 'omitnan');

    fb_run1_rt_repaired_onset = rmmissing(onsets_table_test.('fbTest_run-1_rt')(is_repaired));
    fb_run1_rt_repaired_onset_c =  fb_run1_rt_repaired_onset - mean(fb_run1_rt_repaired_onset, 'omitnan');
    
    % onsets fb run 2
    is_intact = strcmp(onsets_table_test.("fbTest_run-2_condition"), 'intact') & ...
                    onsets_table_test.("fbTest_run-2_accuracy") == 1;
    fb_run2_intact_onset = {onsets_table_test.("fbTest_run-2_onset")(is_intact)};

    is_repaired = strcmp(onsets_table_test.("fbTest_run-2_condition"), 'repaired') & ...
                    onsets_table_test.("fbTest_run-2_accuracy") == 1;
    fb_run2_repaired_onset = {onsets_table_test.("fbTest_run-2_onset")(is_repaired)};

    % RT 
    fb_run2_rt_intact_onset = rmmissing(onsets_table_test.('fbTest_run-2_rt')(is_intact));
    fb_run2_rt_intact_onset_c =  fb_run2_rt_intact_onset - mean(fb_run2_rt_intact_onset, 'omitnan');

    fb_run2_rt_repaired_onset = rmmissing(onsets_table_test.('fbTest_run-2_rt')(is_repaired));
    fb_run2_rt_repaired_onset_c =  fb_run2_rt_repaired_onset - mean(fb_run2_rt_repaired_onset, 'omitnan');
    


    %% build batch


    %START
    matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(first_level_dir);
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = n_slices;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = floor(n_slices/2);
  

    %% FULL-BINDING RUN1
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).scans = cellstr(spm_select('expand', path_epi_fbTest_session1));

    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).name = 'full-binding_intact';
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).onset = fb_run1_intact_onset{1};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).duration = picture_duration;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).tmod = 0;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).pmod(1).name = 'RT';
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).pmod(1).param = fb_run1_rt_intact_onset_c;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).pmod(1).poly = 1;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(1).orth = 1;

    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).name = 'full-binding_repaired';
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).onset = fb_run1_repaired_onset{1};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).duration = picture_duration;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).tmod = 0;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).pmod(1).name = 'RT';
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).pmod(1).param = fb_run1_rt_repaired_onset_c;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).pmod(1).poly = 1;
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).cond(2).orth = 1;

    matlabbatch{1}.spm.stats.fmri_spec.sess(1).multi = {''};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).regress = struct('name', {}, 'val', {});
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).multi_reg = {fullfile(func_dir, 'motion_regressors_fbTest_run1.txt')};
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).hpf = 128;

    %% FULL-BINDING RUN2
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).scans = cellstr(spm_select('expand', path_epi_fbTest_session2));

    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).name = 'full-binding_intact';
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).onset = fb_run2_intact_onset{1};
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).duration = picture_duration;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).tmod = 0;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).pmod(1).name = 'RT';
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).pmod(1).param = fb_run2_rt_intact_onset_c;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).pmod(1).poly = 1;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(1).orth = 1;

    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).name = 'full-binding_repaired';
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).onset = fb_run2_repaired_onset{1};
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).duration = picture_duration;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).tmod = 0;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).pmod(1).name = 'RT';
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).pmod(1).param = fb_run2_rt_repaired_onset_c;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).pmod(1).poly = 1;
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).cond(2).orth = 1;


    matlabbatch{1}.spm.stats.fmri_spec.sess(2).multi = {''};
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).regress = struct('name', {}, 'val', {});
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).multi_reg = {fullfile(func_dir, 'motion_regressors_fbTest_run2.txt')};
    matlabbatch{1}.spm.stats.fmri_spec.sess(2).hpf = 128;

    % BATCH VARS

    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';


    % ESTIMATION
    matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr(sprintf('%s/SPM.mat', first_level_dir));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 1;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    spm_jobman('run', matlabbatch);

end