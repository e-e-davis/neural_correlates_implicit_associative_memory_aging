# BEHAVIOURAL DATA CURATION -----------------------------------------------
# 2023-07-07
# This script looks in the behavioural data folders and determines whether 
# the current participant has data for all the tasks. If the participant 
# has a behavioural data file, the e-dat and onset files are read in and 
# converted to .tsv files and saved in the func folder in BIDS format. 

# 2023-08-23
# Add day 2 explicit task data to tsvs 

# 2025-09-26
# Finally fixed this so it will loop through participants. 

# LIBRARIES ---------------------------------------------------------------
library(tidyverse)
library(rprime)
library(readxl)

##### GET  PARTICIPANT INFO
exclude <-  c(310, 302, 307, 403, 427, 334, 405, 421, 423)

tracking <- read_excel("/media/lab/bigbrains/COFA/COFA_bids/sourcedata/tracking_sheet_fmri_restart.xlsx",  na = "NA") %>% 
  select(subj_ID, run_cb) %>% 
  mutate(age_letter = ifelse(subj_ID > 400, "O", "Y"), 
         run_cb = tolower(run_cb)) %>% 
  filter(subj_ID > 300,
         !subj_ID == 305) %>% 
  filter(subj_ID %in% exclude) 



# Start loop 
for (participant_loop in 1:nrow(tracking)) {
  #participant_number = '425'
  #age = "O" 
  #run_cb = "b"
  
  participant_number = paste0(tracking$subj_ID[participant_loop])
  age = tracking$age_letter[participant_loop]
  run_cb = tracking$run_cb[participant_loop]
    
  # DIRECTORIES -------------------------------------------------------------
  data_dir <- "/media/lab/bigbrains/COFA/COFA_bids/sourcedata/behav/"
  output_dir <- paste0("/media/lab/bigbrains/COFA/COFA_bids/raw_data/sub-", age, participant_number, "/func/")
  # Test loop and output without overwriting
  #output_dir <- paste0("/media/lab/bigbrains/COFA/COFA_bids/raw_dataTEST/sub-", age, participant_number, "/func/")
  data_files_day2 <- list.files(paste0(data_dir, "day2/"))
  df_day2 <- map_df(data_files_day2, ~read_csv(paste0(data_dir, "day2/", .), col_types = cols(participant_ID = col_character()))) %>% 
    mutate(participant_ID = str_remove(participant_ID, "^0+"))
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # CHECK IF PARTICIPANT HAS DATA FOR ALL TASKS  -----------------------------
  task_list = c("fb_first_a", "fb_first_b", "fb_second_a", "fb_second_b")
  
  for (i in 1:length(task_list)){
    files_in_task_folder <- list.files(paste0(data_dir, task_list[i]))
    file_exists <- any(str_detect(files_in_task_folder, participant_number) == TRUE)
    
    # drop task from list if there is no data 
    if (!file_exists == TRUE){
      #task_list <- task_list[task_list != task_list[i]]
      task_list[i] <- NA
    }
  }
  task_list <- na.omit(task_list)
  
  
  # READ IN DATA AND CONVERT TO TSV -----------------------------------------
  for (x in 1:length(task_list)) {
    
    ## set directories and file names
    cur_task = task_list[x]
    print(cur_task)
    block_type <- "fb"
    run_type <- ifelse(str_detect(cur_task, "_a"), "a", "b")
    task_type <-
      ifelse(str_detect(cur_task, "first") == TRUE, "first", "second")
    task_type_onset_label <-
      ifelse(task_type == "first", "encode", "test")
    
    trial_length <- ifelse(task_type_onset_label == "encode", 88, 44)
  
      # read in onset file
    onset_file <-
      paste0(data_dir,
        "onsets_", toupper(run_type),"/OnsetTimes_",
        toupper(block_type),
        "_",
        task_type_onset_label,
        "_",
        toupper(run_type),
        "_",
        participant_number,
        ".txt"
      )
    
    # Only preprocess data here if onset files exist
    if (file.exists(onset_file)) {
      onsets <- read.table(onset_file, header = TRUE) 
      
       # remove button presses - inline script in eprime doesn't accept responses between 2000 and 2500 ms 
       onsets <- onsets %>% 
         filter(!Task_condition %in% c("ButtonPress", "filler")) %>%
         mutate(Sample = 1:trial_length,
                Sample = as.character(Sample))
      
      ## read in e-prime txt file
      lines <-
        read_eprime(paste0(data_dir, cur_task, '/', cur_task, '-', participant_number, '.txt'))
      data <- FrameList(lines)
      preview_levels(data)
      keep_blocklist <- keep_levels(data, 3)
      df <- to_data_frame(keep_blocklist)
      
      ## get trial accuracy
      # Participant 412 has a few entire tasks where their hand was shifted. 
      if(participant_number == "412"){
        index_response_shift <- which(df$PicWord.RESP == 3)
        if(!is_empty(index_response_shift)){
        vals <- seq(first(index_response_shift), last(index_response_shift))
        df <- df %>%
          mutate(
            PicWord.RESP = case_when(
              Sample %in% vals & PicWord.RESP == 3 ~ 2,
              Sample %in% vals & PicWord.RESP == 2 ~ 1,
              !Sample %in% vals & PicWord.RESP == 1 ~ 1,
              !Sample %in% vals & PicWord.RESP == 2 ~ 2
            ))
        }
      }
      
      df <- df %>%
        mutate(
          accuracy = case_when(
            fit == "YES" & PicWord.RESP == 1 ~ 1,
            fit == "YES" & PicWord.RESP == 2 ~ 0,
            fit == "NO" & PicWord.RESP == 1 ~ 0,
            fit == "NO" & PicWord.RESP == 2 ~ 1
          )
        )
      
      # join edat data with onset files & create key press onset
      df_w_onsets <- left_join(df, onsets, by = "Sample") %>% 
        mutate(keypress_onset = Onset + (as.integer(PicWord.RT)/1000),
               keypress_onset_corr = ifelse(as.integer(PicWord.RT) == 0, NA, keypress_onset)) %>% 
        rename(onset = Onset, duration = Dur, rt = PicWord.RT)
      
      # deal with fact that a & b runs are counterbalanced across participant 
      run_first <- case_when(run_cb == "a" & run_type == "a" ~ "run-1",
                             run_cb == "a" & run_type == "b" ~ "run-2", 
                             run_cb == "b" & run_type == "a" ~ "run-2", 
                             run_cb == "b" & run_type == "b" ~ "run-1")
      
      # day 2 data 
        if(participant_number %in% as.double(df_day2$participant_ID)){
        df_day2_cur <- df_day2 %>%  
        rename_with( ~ paste0("day2_", .x)) %>% 
        mutate(day2_participant_ID = as.character(day2_participant_ID),
               day2_block_type = ifelse(str_detect(day2_list_block, "FB"), "FB", NA)) %>% 
        filter(day2_participant_ID == participant_number,
               day2_run_d2 == run_type,
               day2_block_type== toupper(block_type) ) %>% 
        rename(participant_number = day2_participant_ID) %>% 
        mutate(pic_num = as.character(day2_pic_num),
               day2_sub_memory = ifelse(day2_acc == 1, "rem", "for"))
      
      df_w_onsets <- left_join(df_w_onsets, df_day2_cur, by = "pic_num") %>% 
        mutate(sub_memory = paste(task_condition, day2_sub_memory, sep = "_"))
      
        }
      
      
      # write tsv in raw_data func file in BIDS specification. 
      write_tsv(df_w_onsets, paste0(output_dir, "sub-", age, participant_number, "_", "task-", block_type, str_to_title(task_type_onset_label), "_", run_first, "_events.tsv"))
      
    } else {
      # warn me if a participant is missing onset files and I will create them
      missing_onsets <- list()
      missing_onsets[x] <- task_list[x] 
    }
    
    if (exists("missing_onsets")) {
      warning(paste0("sub-", participant_number, " missing onset file: ", missing_onsets, "  "))
    }
  }
}