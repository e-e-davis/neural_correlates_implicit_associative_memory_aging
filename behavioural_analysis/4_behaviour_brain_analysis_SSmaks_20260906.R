library(tidyverse)
library(interactions)
library(emmeans)
library(patchwork)
#setwd('/media/lab/bigbrains/COFA/COFA_bids/')
# Load data ---------------------------------------------------------------

df <- read_csv("./code/roi_analysis/behaviour_brain_test_2mm_2026-09-17.csv")

# Derived behavioural variables -------------------------------------------
df_mod <- df %>% 
  mutate(
    fb_score_resid        = residuals(lm(fb_test_rt_acc1_repaired ~ fb_test_rt_acc1_intact,       data = df, na.action = na.exclude)),
    priming_fb_resid      = residuals(lm(fb_encode_rt_acc1_cycle_2 ~ fb_encode_rt_acc1_cycle_1,   data = df, na.action = na.exclude)),
    priming_fb            = fb_encode_rt_acc1_cycle_1 - fb_encode_rt_acc1_cycle_2,
    age_group_str         = as.factor(ifelse(age_group == 0.5, "Old", "Young")),
    subject_id            = as.factor(subject_id)
  )

old_df   <- df_mod %>% filter(age_group ==  0.5)
young_df <- df_mod %>% filter(age_group == -0.5)

# ROI lists ---------------------------------------------------------------
fb_rois <- c("fb_leftAnteriorHipp", "fb_rightAnteriorHipp",
             "fb_leftPosteriorHipp", "fb_rightPosteriorHipp",
             "fb_leftPHC",           "fb_rightPHC",
             "fb_leftPRC", "fb_rightPRC")

bonferroni = .05/length(fb_rois)
bonferroni_hipp = .05/4
# ROI age differences -----------------------------------------------------
cat("\n--- FB ROI age differences ---\n")
for (roi in fb_rois) {
  cat("\n====", roi, "====\n")
  print(summary(aov(as.formula(paste(roi, "~ age_group")), data = df_mod)))
}


cat("\n--- FB ROI: overall difference from zero ---\n")
for (roi in fb_rois) {
  cat("\n====", roi, "====\n")
  print(t.test(df_mod[[roi]], mu = 0))
}

df_mod %>% 
  filter(age_group_str == "Old") %>% 
  pull(fb_rightPosteriorHipp) %>% 
  t.test(., mu = 0)

df_mod %>% 
  filter(age_group_str == "Young") %>% 
  pull(fb_rightPosteriorHipp) %>% 
  t.test(., mu = 0)

df_mod %>% 
  select(subject_id, age_group, fb_rightPosteriorHipp) %>% 
  group_by(age_group) %>% 
  summarize(average_activation = mean(fb_rightPosteriorHipp),
            sd = sd(fb_rightPosteriorHipp))


# ROI visualisation -------------------------------------------------------
df_brain <- df_mod %>%
  select(subject, age_group, age_group_str, all_of(fb_rois)) %>%
  pivot_longer(
    cols      = all_of(fb_rois),
    names_to  = "brain_region",
    values_to = "contrast"
  ) %>%
  mutate(
    hemisphere         = ifelse(str_detect(brain_region, "left"), "Left", "Right"),
    roi                = ifelse(str_detect(brain_region, "PHC"), "PHC", 
                                ifelse(str_detect(brain_region, "Hipp"), "HPC", "PRC")),
    anterior_posterior = case_when(
      str_detect(brain_region, "Anterior")  ~ "anterior",
      str_detect(brain_region, "Posterior") ~ "posterior"
    ))

df_brain %>%
  filter(!roi %in% c("PRC", "PHC")) %>%
  ggplot(aes(x = interaction(anterior_posterior, roi, sep = "\n"),
             y = contrast, fill = age_group_str)) +
  geom_boxplot(
    position = position_dodge(width = 0.9),
    outlier.shape = NA, alpha = 0.7
  ) +
 # geom_jitter(
#    aes(color = age_group_str),
#    position = position_jitterdodge(jitter.width = 0.15, dodge.width = 0.9),
#    alpha = 0.4, size = 2
 # ) +
  scale_fill_manual(values  = c("Young" = "#69b3a2", "Old" = "#404080")) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  facet_wrap(~hemisphere) +
  labs(x = "", y = "← Intact                  Rearranged →",
       title = "Hippocampus", subtitle = "Mean contrast estimate",
       fill = "Age group", color = "Age group") +
  scale_x_discrete(labels = function(x) tools::toTitleCase(x)) +
  theme_bw(base_size = 16)

df_brain %>%
  filter(roi %in% c("PRC", "PHC")) %>%
  ggplot(aes(x = roi, y = contrast, fill = age_group_str)) +
  geom_boxplot(
    position = position_dodge(width = 0.9),
    outlier.shape = NA, alpha = 0.7
  ) +
 # geom_jitter(
#    aes(color = age_group_str),
#    position = position_jitterdodge(jitter.width = 0.15, dodge.width = 0.9),
#    alpha = 0.4, size = 2
#  ) +
  scale_fill_manual(values  = c("Young" = "#69b3a2", "Old" = "#404080")) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  facet_wrap(~ hemisphere) +
  labs(x = "", y = "← Intact                     Rearranged →",
       title = "PHC & PRC",
       fill = "Age group", color = "Age group") +
  theme_bw(base_size = 16)


## BAR PLOT 
df_hipp_summary <- df_brain %>%
  filter(!roi %in% c("PRC", "PHC")) %>%
  group_by(hemisphere, anterior_posterior, roi, age_group_str) %>%
  summarise(
    mean_contrast = mean(contrast, na.rm = TRUE),
    se            = sd(contrast, na.rm = TRUE) / sqrt(sum(!is.na(contrast))),
    .groups = "drop"
  )

hipp = df_hipp_summary %>%
ggplot(aes(x = interaction(anterior_posterior, roi, sep = "\n"),
             y = mean_contrast, fill = age_group_str)) +
  geom_col(position = position_dodge(width = 0.9), alpha = 0.7) +
  geom_errorbar(
    aes(ymin = mean_contrast - se, ymax = mean_contrast + se),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(values  = c("Young" = "#69b3a2", "Old" = "#404080")) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  facet_wrap(~hemisphere) +
  labs(y = "Contrast estimate (Rearranged − Intact)", x= "",
     #  title = "Hippocampus",
       fill = "Age group", color = "Age group") +
  scale_x_discrete(labels = function(x) tools::toTitleCase(x)) +
  theme_bw(base_size = 16)

df_summary <- df_brain %>%
  filter(roi %in% c("PRC", "PHC")) %>%
  group_by(hemisphere, roi, age_group_str) %>%
  summarise(
    mean_contrast = mean(contrast, na.rm = TRUE),
    se            = sd(contrast, na.rm = TRUE) / sqrt(sum(!is.na(contrast))),
    .groups = "drop"
  )

phc_prc = df_summary %>%
  ggplot(aes(x = roi, y = mean_contrast, fill = age_group_str)) +
  geom_col(position = position_dodge(width = 0.9), alpha = 0.7) +
  geom_errorbar(
    aes(ymin = mean_contrast - se, ymax = mean_contrast + se),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(values  = c("Young" = "#69b3a2", "Old" = "#404080")) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  facet_wrap(~hemisphere) +
  labs(y = "Contrast estimate (Rearranged − Intact)", x = "",
     #  title = "Perirhinal & Parahippocampal Cortex", 
       fill = "Age group", color = "Age group") +
  theme_bw(base_size = 16)

hipp + phc_prc + 
  plot_layout(guides = "collect", axes = "collect") +
  plot_annotation(tag_levels = 'A')


# Priming at test ~ neural ------------------------------------------------
cat("\n--- FB: Priming at test ~ neural ---\n")
for (roi in fb_rois) {
  cat("\n====", roi, "====\n")
  print(summary(lm(as.formula(paste("fb_score_resid ~", roi, "* age_group")), data = df_mod)))
}

left_prc = ggplot(df_mod, aes(fb_leftPRC, fb_score_resid, color = age_group_str)) +
  geom_jitter() +
  geom_smooth(method = "lm", se = FALSE) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  labs(x = "Estimate (Left)", y = "Behavioural associative priming",
      # title = "Repetition suppression and behaviour",
      # subtitle = "Rearranged > Intact",
       color = "Age Group") +
  theme_bw() +
  theme(text = element_text(face = "bold", size = 25))

right_prc = ggplot(df_mod, aes(fb_rightPRC, fb_score_resid, color = age_group_str)) +
  geom_jitter() +
  geom_smooth(method = "lm", se = FALSE) +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  labs(x = "Estimate (Right)", y = "Behavioural associative priming",
     #  title = "Repetition supression and behaviour",
     #   subtitle = "Rearranged > Intact",
       color = "Age Group") +
  theme_bw() +
  theme(text = element_text(face = "bold", size = 25))

left_prc + right_prc + 
  plot_layout(guides = "collect", axes = "collect") +
  plot_annotation(tag_levels = 'A')



ggplot(df_mod, aes(fb_leftAnteriorHipp, fb_score_resid, color = age_group_str)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  scale_color_manual(values = c("Young" = "#69b3a2", "Old" = "#404080")) +
  labs(x = "Parameter estimate (Left Anterior Hipp)", y = "Behavioural associative priming",
       title = "Repetition suppression and behaviour",
       subtitle = "Rearranged > Intact",
       color = "Age Group") +
  theme_bw() +
  theme(text = element_text(face = "bold", size = 25))

