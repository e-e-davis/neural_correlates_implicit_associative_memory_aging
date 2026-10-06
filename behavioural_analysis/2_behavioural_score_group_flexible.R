# BEHAVIOURAL GROUP DATA --------------------------------------------------
# Reads in tsv files for each task, trims RTs, and computes 
# variables for group analysis (wide format)

library(tidyverse)
library(readxl)

# Global Variables --------------------------------------------------------
# RT trim values 
minRT <- 200
sd_cuttoff <- 2.5

# Trial numbers
encode_trial_num <- 88
test_trial_num <- 44

# Directories -------------------------------------------------------------
data_directory <- '/media/lab/bigbrains/COFA/COFA_bids/raw_data'
participant_list <- dir(data_directory, "sub")
# participant_list <- c("sub-Y304")

# Functions ---------------------------------------------------------------
source('/media/lab/bigbrains/COFA/COFA_bids/code/behav_score_group_functions.R')

# Output folder
folder <- "/media/lab/bigbrains/COFA/COFA_bids/derivatives/behav/"

# Demographics
demo_ya <- read_excel("/media/lab/bigbrains/COFA/COFA_bids/code/data_demographics.xlsx", 
                      na = "NA", sheet = 1) %>% 
  mutate(Subject = paste0("sub-Y", subject_id))

demo_oa <- read_excel("/media/lab/bigbrains/COFA/COFA_bids/code/data_demographics.xlsx",  
                      na = "NA", sheet = 2) %>% 
  mutate(Subject = paste0("sub-O", subject_id))

demo <- full_join(demo_oa, demo_ya)

# Score the data ----------------------------------------------------------

for (behav_p in seq_along(participant_list)) {
  cur_participant <- participant_list[behav_p]
  
  # Read in all files
  list_files <- dir(file.path(data_directory, cur_participant, "func"), "task-fb.*\\.tsv$") 
  if (is_empty(list_files)) next
  
  df <- map(list_files, ~ read_delim(file.path(data_directory, cur_participant, "func", .x),
                                     "\t", escape_double = FALSE, trim_ws = TRUE, id = "path"))
  
  # Preprocess ------------------------------------------------------------
  for (i in seq_along(df)) {
    if (df[[i]]$task[1] == "encoding") {
      df[[i]]$cycle <- ifelse(df[[i]]$Sample > encode_trial_num/2, "cycle_2", "cycle_1")
    }
    
    df[[i]]$Subject <- cur_participant
    df[[i]]$run_num <- ifelse(str_detect(df[[i]]$path, "run-1"), "run1", "run2") 
  }
  
  # Task index ------------------------------------------------------------
  tasks <- tibble(
    tasks = seq_along(list_files),
    binding_level = map_chr(df, ~ .x$binding_level[1]),
    run = map_chr(df, ~ .x$run_num[1]),
    task = map_chr(df, ~ .x$task[1])
  )
  
  # Find indices
  index_fb_encode <- which(tasks$binding_level == "fb" & tasks$task == "encoding")
  index_fb_test   <- which(tasks$binding_level == "fb" & tasks$task == "test")
  
  tasks_to_write <- list()
  
  # Day 2 explicit memory (example block — unchanged)
  day2_avail_data <- c(index_fb_test)
  if (length(day2_avail_data) > 0) {
    day2_test <- map(day2_avail_data, function(idx) {
      if ("day2_rt" %in% colnames(df[[idx]])) {
        df[[idx]] %>% 
          group_by(task_condition) %>% 
          summarise(sum_acc = sum(day2_acc), .groups = "drop") %>% 
          mutate(block = df[[idx]]$Block[1],
                 run = df[[idx]]$run_num[1]) %>% 
          pivot_wider(names_from = c(block, run, task_condition), values_from = sum_acc)
      } else {
        NULL
      }
    }) %>% compact()
    
    if (length(day2_test) > 0) {
      explicit_data <- bind_rows(day2_test) %>% mutate(Subject = cur_participant)
      tasks_to_write <- append(tasks_to_write, list(explicit_data))
    }
  }
  
  # Trim RTs ---------------------------------------------------------------
  for (i in seq_along(df)) {
    trial_num <- ifelse(df[[i]]$task[1] == "encoding", encode_trial_num, test_trial_num)
    df[[i]] <- trim_data(df[[i]], trial_num)
  }
  
  # Score tasks ------------------------------------------------------------
  fb_encode <- merge_files(index_fb_encode, df)
  fb_test   <- merge_files(index_fb_test, df)
  
  if (!is.null(fb_encode)) tasks_to_write <- append(tasks_to_write, list(score_rt_acc(fb_encode)))
  if (!is.null(fb_test))   tasks_to_write <- append(tasks_to_write, list(score_rt_acc(fb_test)))
  
  tasks_to_write <- tasks_to_write[sapply(tasks_to_write, nrow) > 0]
  
  if (length(tasks_to_write) > 0) {
    p_df <- reduce(tasks_to_write, full_join, by = "Subject")
    
    if (behav_p == 1) {
      all_data <- p_df
    } else {
      all_data <- full_join(all_data, p_df, by = "Subject")
    }
  }
}

# Join demographics --------------------------------------------------------
all_data <- left_join(all_data, demo, by = "Subject")

# Write out
write_csv(all_data, file.path(folder, paste0("ca-fmri-", Sys.Date(), ".csv")))
