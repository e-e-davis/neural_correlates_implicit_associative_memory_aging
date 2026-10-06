# Emily E. Davis 
# Behavioural analysis for full-binding block from COFA_fMRI
# 2025-03-12
# Reads output from behavioural_score_group_flexible.R  
# Analyses behavioural data 

# LIBRARIES ---------------------------------------------------------------
library(tidyverse)
library(lme4)

# IMPORT DATA -------------------------------------------------------------
date_data_output <- "2025-09-26"
data_directory <- '/media/lab/bigbrains/COFA/COFA_bids/derivatives/behav/'
df <- read_csv(paste(data_directory, "ca-fmri-", date_data_output, ".csv", sep ="")) %>% 
  select(Subject, everything()) 

#source('/media/lab/bigbrains/COFA/COFA_bids/code/behavioural_analysis/summary_SE.R')

is_outlier <- function(x) {
  return(x < quantile(x, 0.25) - 1.5 * IQR(x) | x > quantile(x, 0.75) + 1.5 * IQR(x))
}

# DATA CLEANUP ------------------------------------------------------------
young_colour = "#2A9D8F"   # deeper teal
old_colour   = "#B2182B"   # brick red

df <- df %>% 
  mutate(agegroup = ifelse(subject_id > 400, "Old", "Young"))

df %>% 
  group_by(agegroup) %>% 
  summarize(num = n(), 
            min_age = min(age, na.rm = TRUE),
            max_age = max(age, na.rm = TRUE))

df_check_edu <- df %>% 
  select(subject_id, edu_yrs) 
## Fix inflated values 
df_check_edu$edu_yrs[df_check_edu$subject_id == 404] = 19
df_check_edu$edu_yrs[df_check_edu$subject_id == 404] = 19
df_check_edu$edu_yrs[df_check_edu$subject_id == 409] = 17
df_check_edu$edu_yrs[df_check_edu$subject_id == 422] = 18

df_check_edu <- df_check_edu %>% 
  rename(edu_yrs_fixed_inflation = edu_yrs)

df <- left_join(df, df_check_edu, by = "subject_id")

# Exclusions
# 307 = anxious about scanner and completed nearly no tasks
# 428 = outlying accuracy on test tasks + participant notes about movement/cooperation
# 427 = outlying accuracy on test tasks + participant notes about movement/cooperation
# 325 = outlying accuracy on test tasks + participant notes about movement/cooperation
# 403 = outlying accuracy on test tasks + participant notes about movement/cooperation
exclude <-  c(307, 403, 427, 334, 405, 421, 423)


df_accuracy <- df %>% 
  filter(subject_id %in% exclude) %>% 
  select(fb_test_acc_intact, fb_test_acc_repaired)


df_c <- df %>% 
  filter(!subject_id %in% exclude) %>% 
  mutate(day2_fb_intact = (day2_test.fb_run1_intact + day2_test.fb_run2_intact)/44,
         day2_fb_rearranged = (day2_test.fb_run1_repaired + day2_test.fb_run2_repaired)/44,
         subject_id = as.factor(subject_id))

# Number of participants
df_c %>% 
  group_by(agegroup) %>% 
  summarize(num = n())

# Age differences in demographics
t.test(shipley ~ agegroup,
       data = df_c, var.equal = TRUE)

t.test(edu_yrs ~ agegroup,
       data = df_c, var.equal = TRUE)

t.test(edu_yrs_fixed_inflation ~ agegroup,
       data = df_c, var.equal = TRUE)


# Report demographics
demo <- df_c %>%
  select(-subject_id) %>%
  group_by(agegroup) %>%
  summarise(
    across(
      c(shipley, edu_yrs_fixed_inflation, moca, age),
      list(
        mean = ~mean(.x, na.rm = TRUE),
        sd   = ~sd(.x, na.rm = TRUE)
      )
    ),
    n = n(),
    n_female = sum(sex == "F", na.rm = TRUE),
    n_male = sum(sex == "M", na.rm = TRUE),
    .groups = "drop"
  )

demo

# EXPLICIT DATA - DAY 2  --------------------------------------------------
# 423 - completed 4 days later.
# 419 - wrong day 2 
exclude_day2 = c("423", "419") #423 already excluded above. 
df_c %>% 
  filter(!subject_id %in% exclude_day2) %>%  
  group_by(agegroup) %>% 
  summarize(num = n())

day2_df <- df_c %>% 
  filter(!subject_id %in% exclude_day2) %>%  
  select(subject_id, age, agegroup, day2_fb_intact:day2_fb_rearranged) %>% 
  drop_na() %>% 
  pivot_longer(names_to = "condition", values_to = "accuracy", cols = c(day2_fb_intact:day2_fb_rearranged)) %>% 
  mutate(pair_type = as.factor(ifelse(str_detect(condition, "intact"), "Intact", ifelse(str_detect(condition, "new"), "New", "Rearranged"))))

day2_df %>% 
  group_by(agegroup) %>% 
  summarize(num = n())

anova_result <- aov(accuracy ~ agegroup *  pair_type + Error(subject_id/(pair_type)), data = day2_df)
summary(anova_result)


day2_summary <- summarySEwithin2(day2_df, measurevar="accuracy", betweenvars = "agegroup", withinvars=c("pair_type"),
                                 idvar="subject_id", na.rm=TRUE, conf.interval=.95)

summarySE2(day2_df, measurevar="accuracy", groupvars = "agegroup", na.rm=TRUE, conf.interval=.95)


summarySEwithin2(day2_df, measurevar="accuracy", withinvars=c("pair_type"),
                 idvar="subject_id", na.rm=TRUE, conf.interval=.95)

day2_df %>% 
  filter(agegroup =="Old") %>% 
  pull(accuracy) %>% 
  t.test(mu = .5)

day2_df %>% 
  filter(agegroup =="Young") %>% 
  pull(accuracy) %>% 
  t.test(mu = .5)

result_explicit_panel <- day2_summary %>%
  ggplot(aes(agegroup, accuracy, fill = pair_type)) +
  geom_bar(stat = "identity", position = "dodge2", alpha = .8) +
  geom_errorbar(aes(ymin = accuracy - ci, ymax = accuracy + ci),
                width = .2, position = position_dodge(.9)) +
  scale_fill_manual(
    name = "Pair Type",
    values = c("Rearranged" = "navy", "Intact" = "#E07B39")
  ) +
  labs(x = "", y = "Proportion Correct", title = "Explicit Associative Memory (2AFC)") +
  theme_classic() +
  theme(text = element_text(face = "bold", size = 15))+
  scale_y_continuous(limits = c(0, 1), expand = c(0, 0))

result_explicit_panel <- day2_df %>%
  ggplot(aes(x = agegroup, y = accuracy, fill = pair_type)) +
  geom_violin(alpha = 0.4, colour = NA, trim = FALSE,
              position = position_dodge(0.9)) +
  geom_boxplot(width = 0.15, alpha = 0.6, outlier.shape = NA,
               position = position_dodge(0.9)) +
  geom_point(position = position_jitterdodge(jitter.width = 0.08,
                                             dodge.width = 0.9),
             alpha = 0.4, size = 1.5, colour = "black") +
  scale_fill_manual(name = "Pair Type",
                    values = c("Rearranged" = "navy", "Intact" = "#E07B39")) +
  labs(x = "", y = "Proportion Correct", title = "Explicit Associative Memory (2AFC)") +
  theme_bw() +
  theme(text = element_text(face = "bold", size = 16)) +
  scale_y_continuous(limits = c(0, 1), expand = c(0, 0))



## intact pairs

day2_df_intact <- day2_df %>% 
  filter(pair_type == "Intact")
head(day2_df_intact)

Rmisc::summarySE(day2_df_intact, measurevar="accuracy", groupvars=c("agegroup"), 
                 na.rm=TRUE, conf.interval=.95)

t.test(accuracy ~ agegroup,
       data = day2_df_intact)

## rearranged pairs

day2_df_rearranged <- day2_df %>% 
  filter(pair_type == "Rearranged")
head(day2_df_rearranged)

t.test(accuracy ~ agegroup,
       data = day2_df_rearranged)
day2_df_rearranged %>% 
  pull(accuracy) %>% 
  t.test(mu = 0)

day2_df_rearranged %>% 
  pull(accuracy) %>% 
  t.test(mu = 0)

# IMPLICIT  ----------------------------------------------------------

# accuracy encode
implicit_acc_encode_df <- df_c %>% 
  select(subject_id, order_cb, agegroup, accuracy = fb_encode_acc) %>% 
  mutate(subject_id = as.factor(subject_id))

implicit_acc_encode_df  %>%
  group_by(agegroup) %>% 
  mutate(outlier = ifelse(is_outlier(accuracy), subject_id, as.numeric(NA))) %>%
  ungroup() %>% 
  ggplot(aes(agegroup, accuracy)) +
  geom_boxplot() +
  geom_text(aes(label = outlier), na.rm = TRUE, hjust = -0.3)

implicit_acc_encode_df %>% 
  t.test(accuracy ~ agegroup,
         data = ., var.equal = TRUE)

implicit_acc_encode_df %>% 
  group_by(agegroup) %>% 
  summarize(mean = mean(accuracy),
            sd = sd(accuracy))

# accuracy test 
implicit_acc_df <- df_c %>% 
  select(subject_id, order_cb, agegroup, fb_test_acc_intact, fb_test_acc_repaired) %>% 
  pivot_longer(names_to = "condition", values_to = "accuracy", cols = c(fb_test_acc_intact:fb_test_acc_repaired)) %>% 
  mutate(pair_type = as.factor(ifelse(str_detect(condition, "intact"), "Intact", ifelse(str_detect(condition, "new"), "New", "Rearranged"))))

implicit_acc_df  %>%
  group_by(agegroup) %>% 
  mutate(outlier = ifelse(is_outlier(accuracy), subject_id, as.numeric(NA))) %>%
  ungroup() %>% 
  ggplot(aes(pair_type, accuracy, fill = pair_type)) +
  geom_boxplot() +
  geom_text(aes(label = outlier), na.rm = TRUE, hjust = -0.3) +
  facet_grid(~agegroup)

anova_result <- aov(accuracy ~ agegroup * pair_type + Error(subject_id/(pair_type)), data = implicit_acc_df)
summary(anova_result)


implicit_acc_df %>% 
  group_by(agegroup, pair_type) %>% 
  summarize(mean = mean(accuracy),
            sd = sd(accuracy))



## PRIMING ENCODING -- TEST 
df_priming <- df_c %>% 
  select(subject_id, agegroup, fb_encode_rt_acc1_cycle_1, fb_encode_rt_acc1_cycle_2, fb_test_rt_acc1_intact) %>% 
  pivot_longer(names_to = "condition", values_to = "rt", cols = c(fb_encode_rt_acc1_cycle_1:fb_test_rt_acc1_intact)) %>% 
  mutate(
    condition_priming_names = as.factor(case_when(
      str_detect(condition, "cycle_1") ~ "Time 1",
      str_detect(condition, "cycle_2") ~ "Time 2",
      TRUE ~ "Time 3")
    )
  )

anova_result_priming <- aov(rt ~ agegroup * condition_priming_names + Error(subject_id/(condition_priming_names)), data = df_priming)
summary(anova_result_priming)

emm <- emmeans(anova_result_priming, ~ condition_priming_names)
pairs(emm, adjust = "bonferroni")

df_priming %>% 
  group_by(condition_priming_names) %>% 
  summarize(mean = mean(rt, na.rm = TRUE))

df_priming %>% 
  group_by(agegroup, condition_priming_names) %>% 
  summarize(mean = mean(rt, na.rm = TRUE),
            sd = sd(rt, na.rm = TRUE))

df_priming %>%
  ggplot(aes(condition_priming_names, rt, group = subject_id, colour = agegroup)) +
  geom_line(alpha = .2) +
  stat_summary(
    aes(group = agegroup),
    fun = mean,
    geom = "line",
    linewidth = 1.5
  ) +
  scale_colour_manual(values = c("Young" = young_colour, "Old" = old_colour))+
  labs(y = "Reaction time (ms)", x = "")+
  theme_classic() +
  theme(text=element_text(face="bold", size=15), legend.position = "none")+
  scale_x_discrete(expand = expansion(mult = 0.05))

results_priming_pane = df_priming %>%
  ggplot(aes(condition_priming_names, rt, colour = agegroup, fill = agegroup, group = agegroup)) +
  annotate("rect", xmin = 2.5, xmax = Inf, ymin = -Inf, ymax = Inf, 
           fill = "gray93", alpha = 1) +
  annotate("text", x = 1.5, y = Inf, label = "Encoding", vjust = 2, fontface = "bold", size = 5, color = "gray40") +
  annotate("text", x = 2.8, y = Inf, label = "Test", vjust = 2, fontface = "bold", size = 5, color = "gray40") +
  stat_summary(fun = mean, geom = "line", linewidth = 1.5) +
  stat_summary(fun.data = mean_se, geom = "ribbon", alpha = 0.2, colour = NA) +
  scale_colour_manual(values = c("Young" = young_colour, "Old" = old_colour)) +
  scale_fill_manual(values = c("Young" = young_colour, "Old" = old_colour)) +
  theme_classic()+
  labs(y = "Reaction time (ms)", x = "", title = "Priming Effects for Intact Pairs",
       colour = "Age Group", fill = "Age Group")+
  theme(text=element_text(face="bold", size=15))+
  scale_x_discrete(expand = expansion(mult = 0.05))

df_priming <- df_c %>% 
  select(subject_id, agegroup, fb_encode_, fb_encode_rt_acc1_cycle_2, fb_test_rt_acc1_intact) %>% 
  pivot_longer(names_to = "condition", values_to = "rt", cols = c(fb_encode_rt_acc1_cycle_1:fb_test_rt_acc1_intact)) %>% 
  mutate(
    condition_priming_names = as.factor(case_when(
      str_detect(condition, "cycle_1") ~ "Time 1",
      str_detect(condition, "cycle_2") ~ "Time 2",
      TRUE ~ "Time 3")
    )
  )


#includes all RTs across runs

implicit_test_df <- df_c %>% 
  select(subject_id, age, awareness_01, order_cb, agegroup, fb_test_rt_acc1_intact, fb_test_rt_acc1_repaired) %>% 
  pivot_longer(names_to = "condition", values_to = "rt", cols = c(fb_test_rt_acc1_intact:fb_test_rt_acc1_repaired)) %>% 
  mutate(pair_type = as.factor(ifelse(str_detect(condition, "intact"), "Intact", ifelse(str_detect(condition, "new"), "New", "Rearranged"))))

implicit_test_df %>%
  ggplot(aes(pair_type, rt, fill = pair_type)) +
  geom_boxplot() +
  facet_grid(~agegroup)


implicit_test_summary <- summarySEwithin2(implicit_test_df, measurevar="rt", betweenvars = "agegroup", withinvars=c("pair_type"),
                                          idvar="subject_id", na.rm=TRUE, conf.interval=.95)
implicit_test_summary %>%
  ggplot(aes(pair_type, rt, fill = pair_type)) +
  geom_bar(stat="identity", position = "dodge2") +
  geom_errorbar(aes(ymin=rt-ci, ymax=rt+ci), width=.2,
                position=position_dodge(.9)) +
  facet_grid(~agegroup)+
  scale_fill_hue(c = 40, name = "Pair Type") +
  labs(x = "", y = "Reaction time (ms)") +
  theme_bw() +
  theme(text=element_text(face="bold", size=15))

test_model <- lmerTest::lmer(rt ~ agegroup * pair_type + (1|subject_id),
                             data = implicit_test_df)
summary(test_model)


emm <- emmeans:emmeans(test_model, ~ agegroup * pair_type)
emm
emm_df <- as.data.frame(emm)

implicit_test_df %>% 
  group_by(agegroup, pair_type) %>% 
  summarize(mean = mean(rt, na.rm = TRUE),
            sd = sd(rt, na.rm = TRUE))

anova_result <- aov(rt ~ agegroup *  pair_type + Error(subject_id/(pair_type)), data = implicit_test_df)
summary(anova_result)


implicit_test_df %>% 
  filter(agegroup == "Old") %>% 
  t.test(rt ~ pair_type,
         data = ., paired = TRUE)


implicit_test_df %>% 
  filter(agegroup == "Young") %>% 
  t.test(rt ~ pair_type,
         data = ., paired = TRUE)


implicit_test_df_wide <- implicit_test_df %>% 
  pivot_wider(id_cols = c(subject_id, agegroup), names_from = "pair_type", values_from = "rt") %>% 
  mutate(fullbinding_diff = Rearranged-Intact)

implicit_test_summary <- summarySE2(implicit_test_df_wide, measurevar="fullbinding_diff", groupvars = "agegroup",
                                    na.rm=TRUE, conf.interval=.95)

# BAR PLOT 
implicit_test_summary %>%
  ggplot(aes(agegroup, fullbinding_diff, fill = agegroup)) +
  geom_bar(stat="identity", position = "dodge2") +
  geom_errorbar(aes(ymin=fullbinding_diff-ci, ymax=fullbinding_diff+ci), width=.2,
                position=position_dodge(.9)) +
  scale_fill_manual(values  = c("Young" = young_colour, "Old" = old_colour)) +
  labs(x = "", y = "RT Difference (rearranged-intact) (ms)")+
  theme_bw() +
  theme(text=element_text(face="bold", size=15), legend.position = "none")

# BAR PLOT WITH INDIVIDUAL DATA POINTS. 
implicit_test_summary %>%
  ggplot(aes(agegroup, fullbinding_diff, fill = agegroup)) +
  geom_bar(stat="identity", position = "dodge2") +
  geom_jitter(data = implicit_test_df_wide,
              aes(agegroup, fullbinding_diff),
              width = 0.1, alpha = 0.4, size = 1.5,
              inherit.aes = FALSE) +
  geom_errorbar(aes(ymin=fullbinding_diff-ci, ymax=fullbinding_diff+ci), width=.1,
                position=position_dodge(.9)) +
  scale_fill_manual(values  = c("Young" = young_colour, "Old" = old_colour)) +
  labs(x = "", y = "RT Difference (rearranged-intact) (ms)", caption = "Error bars: 95% CI") +
  theme_bw() +
  theme(text=element_text(face="bold", size=15), legend.position = "none")


results_implicit_panel <- implicit_test_df_wide %>%
  ggplot(aes(x = agegroup, y = fullbinding_diff, fill = agegroup)) +
  geom_violin(alpha = 0.4, colour = NA, trim = FALSE) +
  geom_boxplot(width = 0.15, alpha = 0.6, outlier.shape = NA) +
  geom_jitter(width = 0.08, alpha = 0.4, size = 1.5, colour = "black") +
  scale_fill_manual(values = c("Young" = young_colour, "Old" = old_colour)) +
  labs(x = "", y = "Rearranged - Intact (ms)", title = "Associative Priming") +
  theme_bw() +
  theme(text = element_text(face="bold", size=15), legend.position = "none")


library(patchwork)
(results_priming_pane | results_implicit_panel | result_explicit_panel) + plot_layout(guides = "collect")

(results_priming_pane | (results_implicit_panel / result_explicit_panel)) + 
  plot_layout(guides = "collect") +
  plot_annotation(tag_levels = 'A')


