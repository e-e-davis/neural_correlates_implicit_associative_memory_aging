check_stim_issues <- function(data) {
  data %>% 
    group_by(Subject, task, list) %>% 
    summarise(
      CB = mean(CB, na.rm = TRUE),
      trials = n(),
      unique_pic = n_distinct(pic_num),
      unique_word = n_distinct(word_num),
      .groups = "drop"
    )
}

trim_data <- function(data, trial_num) {
  data <- data %>% filter(rt > minRT)
  
  if (data$task[1] == "encoding") {
    cutoff <- mean(data$rt, na.rm = TRUE) + sd_cuttoff * sd(data$rt, na.rm = TRUE)
    dat <- data %>% filter(rt < cutoff)
    
    trimmed <- dat %>%
      count(Subject) %>%
      mutate(trimmed = n / trial_num) %>%
      select(-n)
    
  } else {
    dat <- data %>%
      group_by(Subject, task_condition) %>%
      mutate(cutoff = mean(rt, na.rm = TRUE) + sd_cuttoff * sd(rt, na.rm = TRUE)) %>%
      ungroup() %>%
      filter(rt < cutoff) %>%
      select(-cutoff)
    
    trimmed <- dat %>%
      count(Subject, task_condition) %>%
      mutate(trimmed = n / (test_trial_num / 2)) %>%
      pivot_wider(id_cols = "Subject", names_from = "task_condition", values_from = "trimmed")
  }
  
  dat <- left_join(dat, trimmed, by = "Subject")
  return(dat)
}

merge_files <- function(index, dfs) {
  if (length(index) == 0) return(NULL)
  if (length(index) == 1) return(dfs[[index[1]]])
  if (length(index) == 2) return(bind_rows(dfs[[index[1]]], dfs[[index[2]]]))
  stop("Unexpected number of indices")
}

score_rt_acc <- function(data) {
  binding <- data$binding_level[1]
  
  if (data$task[1] == "encoding") {
    # Overall means
    df <- data %>% 
      group_by(Subject) %>% 
      summarise(
        encode_rt = mean(rt, na.rm = TRUE),
        encode_acc = mean(accuracy, na.rm = TRUE),
        encode_rt_acc1 = mean(rt[accuracy == 1], na.rm = TRUE),
        .groups = "drop"
      )
    
    # By run
    by_run <- data %>%
      filter(accuracy == 1) %>%
      group_by(Subject, run_num) %>%
      summarise(encode_rt_acc1 = mean(rt, na.rm = TRUE), .groups = "drop") %>%
      pivot_wider(names_from = run_num, values_from = encode_rt_acc1,
                  names_prefix = "encode_rt_acc1_") %>%
      complete(run_num = c("run1","run2"))
    
    df <- left_join(df, by_run, by = "Subject")
    
    # By cycle
    by_cycle <- data %>%
      filter(accuracy == 1) %>%
      group_by(Subject, cycle) %>%
      summarise(encode_rt_acc1 = mean(rt, na.rm = TRUE), .groups = "drop") %>%
      pivot_wider(names_from = cycle, values_from = encode_rt_acc1,
                  names_prefix = "encode_rt_acc1_")
    
    df <- left_join(df, by_cycle, by = "Subject")
    
  } else {
    # Test tasks
    x <- data %>% 
      group_by(Subject, task_condition) %>% 
      summarise(test_rt = mean(rt, na.rm = TRUE),
                test_acc = mean(accuracy, na.rm = TRUE), .groups = "drop") %>% 
      pivot_wider(names_from = task_condition, values_from = c(test_rt, test_acc))
    
    y <- data %>% 
      filter(accuracy == 1) %>% 
      group_by(Subject, task_condition) %>% 
      summarise(test_rt_acc1 = mean(rt, na.rm = TRUE), .groups = "drop") %>% 
      pivot_wider(names_from = task_condition, values_from = test_rt_acc1,
                  names_prefix = "test_rt_acc1_") %>%
      mutate(condition_diff = test_rt_acc1_repaired - test_rt_acc1_intact)
    
    z <- data %>% 
      filter(accuracy == 1) %>% 
      group_by(Subject, task_condition, run_num) %>% 
      summarise(test_rt_acc1 = mean(rt, na.rm = TRUE), .groups = "drop") %>% 
      pivot_wider(names_from = c(task_condition, run_num), values_from = test_rt_acc1,
                  names_prefix = "test_rt_acc1_")
    
    df <- list(x, y, z) %>% reduce(full_join, by = "Subject")
  }
  
  # Prefix with binding level
  df <- df %>%
    rename_with(~ paste0(binding, "_", .x), -Subject)
  
  return(df)
}

