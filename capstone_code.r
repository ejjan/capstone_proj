# 3-model-fullterm-glm.R
# Model drop-out given full term activity data using glm
# logistic regression

###
# Setup
###

setwd("/Users/ej/code")
# disable scientific notation
options(scipen = 999)
set.seed(42)

# libraries
library(dplyr)
library(caret)
library(pROC)
library(doMC) # parallel processing
registerDoMC(detectCores() - 2) # save 2 cores

###
# load data
###
# Data loaded
# class labels
# Q1 and Q2 cumulative engagement
# Attendance Rate
# Survey Data

# Load class labels
dfDropId <- readRDS("../output/dfDropId.rds")

# load Q2 cumulative engagement data
dfEngageQ2 <- readRDS("../output/dfEngagementIdUserQ2Cumm.rds")

# load rate of attendance data (addtl feature)
dfAttendRate <- readRDS("../output/dfAttendanceIdQtrWide.rds")

# load survey data
dfSurvey <- read.csv("../output/dfSurveyVariable.csv", na.strings = '',
                     stringsAsFactors = F)

# remove last column which is note
# remove name
dfSurvey <- dfSurvey[,1:9]
dfSurvey$Name <- NULL

# Set Factor Var
dfSurvey$Motivation <- as.factor(dfSurvey$Motivation)

###
# Merge the survey data with class labels.
###

# The training data set consists of Q2 engagement activty with the predicted
# class label based on incompletes in Q3 (classQ3)
dfTrainQ2Engage <- merge(x = dfEngageQ2, y = dfDropId,
                         by.x = "Uploader User Id",
                         by.y = "Student ID")

# Drop students who incomplete in Q1 or Q2
dfTrainQ2Engage <- subset(dfTrainQ2Engage, DropDateQtr %in% c('Q3','Q4',NA))

# Confirm don't have any students to drop in Q1 or Q2
table(dfTrainQ2Engage$DropDateQtr)

# Merge the attendance data with cumulative engagement data
dfTrainQ2EngageAttend <- merge(x = dfTrainQ2Engage, y = dfAttendRate,
                               by.x = "Uploader User Id",
                               by.y = "Student ID")

# Merge the attendance data with cumulative engagement data
dfTrainQ2EngageAttendSurvey <- merge(x = dfTrainQ2EngageAttend, y = dfSurvey,
                                     by.x = "Uploader User Id",
                                     by.y = "Student ID")

# Build model formulas for base model with engagement metrics
# with attendance
# with survey

# set predicted class and predictors
colResponse <- 'classQ3'

# hand coded predictors to remove IDs or values that should not be used in predictions


colPredEngage <- c("rec_cnt","date_cnt", "date_range", "week_cnt", "week_range",
                   "hour_cnt", "action_cnt", class_id_cnt", "class_type_cnt",
                   "studentactioncode_cnt", "title_cnt", "body_cnt", "context_id_cnt",
                   "adultrolecode_cnt", "artifact_creator_id_cnt",
                   "rec_avg_day", "rec_avg_hr", "rec_avg_action", "rec_avg_title",
                   "date_cnt_perc", "rec_avg_week")

colPredAttend <- c("attendRateQ1", "attendRateQ2")

colPredSurvey <- c("Current.identity", "Interest", "Past.experience",
                   "Future.identity" , "Motivation")


colPredEngageAttend <- c(colPredEngage, colPredAttend)
colPredEngageAttendSurvey <- c(colPredEngageAttend, colPredSurvey)

# create base model formula with engagement
frmla_Engage <- as.formula(paste(colResponse,
                                 paste(colPredEngage, collapse = " + "),
                                 sep = " ~ "))

# Create formula with attendance
frmla_EngageAttend <- as.formula(paste(colResponse,
                                       paste(colPredEngageAttend, collapse = " + "),
                                       sep = " ~ "))

# Create formula with attendance
frmla_EngageAttendSurvey <- as.formula(paste(colResponse,
                                             paste(colPredEngageAttendSurvey, collapse = " + "),
                                             sep = " ~ "))

# create formula w/o high cor
frmla_cor <- as.formula("classQ3 ~ rec_cnt + adultrolecode_cnt +
                                   rec_avg_title+ attendRateQ2")


modGlmcor <- train(frmla_cor, method = "glm", family = binomial,
                   data = dfTrainQ2EngageAttendSurvey,
                   trControl = fitCtrlBoot,
                   metric = "ROC")
modGlmcor$results
summary(modGlmcor)

frmla_cor1 <- as.formula("classQ3 ~ Current.identity + Interest + Past.experience +
                                    Future.identity + Motivation + rec_cnt + week_cnt+
                                    adultrolecode_cnt + rec_avg_title + attendRateQ1 +
                                    attendRateQ2")

###
# Stepwise feature selection
###

# EngageAttend model to use for step-wise features selection
glmEngageAttend <- glm(frmla_EngageAttend,
                       data = dfTrainQ2EngageAttend,
                       family = "binomial")

# step-wise regression selection of features
glmStep <- step(glmEngageAttend)


frmla_step1 <- as.formula("classQ3 ~ date_range + week_cnt + week_range + hour_cnt +
                                     action_cnt + title_cnt + body_cnt + adultrolecode_cnt +
                                     rec_avg_hr + rec_avg_title + date_cnt_perc +
                                     rec_avg_week + attendRateQ1 + attendRateQ2")

frmla_step2 <- as.formula("classQ3 ~ date_range + week_cnt + week_range + hour_cnt +
                                     action_cnt + title_cnt + body_cnt + adultrolecode_cnt +
                                     rec_avg_hr + rec_avg_action + rec_avg_title +
                                     date_cnt_perc + rec_avg_week + attendRateQ1 +
                                     attendRateQ2")

frmla_step3 <- as.formula("classQ3 ~ date_range + week_cnt + week_range + hour_cnt +
                                     action_cnt + title_cnt + body_cnt + adultrolecode_cnt +
                                     artifact_creator_id_cnt + rec_avg_hr + rec_avg_action +
                                     rec_avg_title + date_cnt_perc + rec_avg_week +
                                     attendRateQ1 + attendRateQ2")

# EngageAttendSurvey model to use for step-wise features selection
glmEngageAttendSurvey <- glm(frmla_EngageAttendSurvey,
                             data = dfTrainQ2EngageAttendSurvey,
                             family = "binomial")

# step-wise regression selection of features
glmStep <- step(glmEngageAttendSurvey)

frmla_step3_s <- as.formula("classQ3 ~ rec_cnt + date_cnt + week_cnt + week_range +
                                       hour_cnt + action_cnt + class_id_cnt + title_cnt +
                                       adultrolecode_cnt + date_cnt_perc + rec_avg_week +
                                       Past.experience")

frmla_step4_s <- as.formula("classQ3 ~ rec_cnt + date_cnt + week_cnt + week_range +
                                       hour_cnt + action_cnt + class_id_cnt + title_cnt +
                                       adultrolecode_cnt + date_cnt_perc + rec_avg_week +
                                       attendRateQ2 + Past.experience")

frmla_step5_s <- as.formula("classQ3 ~ rec_cnt + date_cnt + week_cnt + week_range +
                                       hour_cnt + action_cnt + class_id_cnt + title_cnt +
                                       adultrolecode_cnt + date_cnt_perc + rec_avg_week +
                                       attendRateQ2 + Interest + Past.experience")
# Reference for choosing 1500 resamples
# https://stats.stackexchange.com/a/207683
fitCtrlBoot <- trainControl(method = 'boot',
                            number = 1500,
                            classProbs = TRUE,
                            savePredictions = TRUE,
                            summaryFunction = twoClassSummary)

#######
# full model
# engagement data only
modGlmBase <- train(frmla_base,
                    method = "glm",
                    family = binomial,
                    data = dfTrainQ2Engage,
                    trControl = fitCtrlBoot,
                    metric = "ROC")

# engagement + attend
modGlmEngageAttend <- train(frmla_EngageAttend,
                            method = "glm",
                            family = binomial,
                            data = dfTrainQ2EngageAttend,
                            trControl = fitCtrlBoot,
                            metric = "ROC")
# engagement + attend +survey
modGlmEngageAttendSurvey <- train(frmla_EngageAttendSurvey,
                                  method = "glm",
                                  family = binomial,
                                  data = dfTrainQ2EngageAttendSurvey,
                                  trControl = fitCtrlBoot,
                                  metric = "ROC")

modGlmstep1 <- train(frmla_step1,
                     method = "glm",
                     family = binomial,
                     data = dfTrainQ2EngageAttend,
                     trControl = fitCtrlBoot,
                     metric = "ROC")

modGlmstep1$results

modGlmstep2 <- train(frmla_step2,
                     method = "glm",
                     family = binomial,
                     data = dfTrainQ2EngageAttend,
                     trControl = fitCtrlBoot,
                     metric = "ROC")

modGlmstep2$results

modGlmstep3 <- train(frmla_step3,
                     method = "glm",
                     family = binomial,
                     data = dfTrainQ2EngageAttend,
                     trControl = fitCtrlBoot,
                     metric = "ROC")

modGlmstep3$results

modGlmstep3_s <- train(frmla_step3_s,
                       method = "glm",
                       family = binomial,
                       data = dfTrainQ2EngageAttendSurvey,
                       trControl = fitCtrlBoot,
                       metric = "ROC")

modGlmstep3_s$results
modGlmstep4_s <- train(frmla_step4_s,
                       method = "glm",
                       family = binomial,
                       data = dfTrainQ2EngageAttendSurvey,
                       trControl = fitCtrlBoot,
                       metric = "ROC")

modGlmstep4_s$results
summary(modGlmstep4_s)
modGlmstep5_s <- train(frmla_step5_s,
                       method = "glm",
                       family = binomial,
                       data = dfTrainQ2EngageAttendSurvey,
                       trControl = fitCtrlBoot,
                       metric = "ROC")

modGlmstep5_s$results

###
# Model Variable Improtance
###
varImpGlm <- varImp(modGlmBase, scale = T)
plot(varImpGlm, top = 10, main = "Scaled Q3 (Engage) Variable Importance (Top 10)")

varImpGlm <- varImp(modGlmEngageAttend, scale = T)
plot(varImpGlm, top = 10, main = "Scaled Q3 (Engage+Attend) Importance (Top 10)")

varImpGlm <- varImp(modGlmEngageAttendSurvey, scale = T)
plot(varImpGlm, top = 10, main = "Scaled Q3 (Engage+Attend+Survey) Importance (Top 10)")

varImpGlm <- varImp(modGlmstep1, scale = T)
plot(varImpGlm, top = 10, main = "Scaled Q3 stepwise (Engage+Attend) Importance (Top 10)")

varImpGlm <- varImp(modGlmstep4_s, scale = T)
plot(varImpGlm, top = 10, main = "Scaled Q3 stepwise (All data) Importance (Top 10)")

###
# Model Comparison
###

# Calculate the performance of the bootstrapped models
# using the metrics from each of the resamples

modGlmBase$results #
mean(modGlmBase$resample$ROC, na.rm = TRUE) # 0.5169195
sd(modGlmBase$resample$ROC, na.rm = TRUE) # 0.1190626

modGlmEngageAttend$results #
mean(modGlmEngageAttend$resample$ROC, na.rm = TRUE) # 0.5459151
sd(modGlmEngageAttend$resample$ROC, na.rm = TRUE) #  0.1217312

modGlmEngageAttendSurvey$results #
mean(modGlmEngageAttendSurvey$resample$ROC, na.rm = TRUE) # 0.5459151
sd(modGlmEngageAttendSurvey$resample$ROC, na.rm = TRUE) #  0.1217312


# save models
saveRDS(modGlmEngageAttendSurvey, "../output/modGlmQ3EngageAttendSurvey.rds")
saveRDS(modGlmstep1, "../output/modGlmQ3EngageAttend_step1.rds")
saveRDS(modGlmstep4_s, "../output/modGlmQ3EngageAttendSurvey_step4.rds")

# Create a function that returns the 95% confidence interval
calc_mean_ci <- function(listNum){
                                  n <- length(listNum)
                                  calcMean <- mean(listNum, na.rm = TRUE)
                                  calcSE <- sd(listNum, na.rm = TRUE) / sqrt(n)
                                  E <- qt(0.975, df = n-1) *  calcSE
                                  calcMeanCi95 <- calcMean + c(-E, E)

                                  calcList <- list("mean" = calcMean,
                                                   "ci95Low" = calcMeanCi95[1],
                                                   "ci95Hi" = calcMeanCi95[2],
                                                   "me" = E)

                                  return(calcList)
                                  }

# Create a list of ROCs across resamples
lstGlmBaseRoc <- modGlmBase$resample$ROC
lstGlmEngageAttendRoc <- modGlmEngageAttend$resample$ROC
lstGlmEngageAttendSurveyRoc <- modGlmEngageAttendSurvey$resample$ROC
lstGlmstep4Roc <- modGlmstep4_s$resample$ROC

lstGlmBaseRocMetrics <- calc_mean_ci(lstGlmBaseRoc)
lstGlmEngageAttendMetrics <- calc_mean_ci(lstGlmEngageAttendRoc)
lstGlmEngageAttendSurveyMetrics <- calc_mean_ci(lstGlmEngageAttendSurveyRoc)
lstGlmstep4RocMetrics <- calc_mean_ci(lstGlmstep4Roc)

lstQ2RocMetrics <- list(lstGlmBaseRocMetrics, lstGlmEngageAttendMetrics,
                        lstGlmEngageAttendSurveyMetrics, lstGlmstep4RocMetrics)

# Convert list of ROC metrics into data frame
dfQ2RocMetrics <- plyr::ldply(lstQ2RocMetrics, data.frame)
Model <- c("Engagement", "EngageAttend", "EngageAttendSurvey", "Step4")
dfQ2RocMetrics <- cbind(Model, dfQ2RocMetrics)

print.data.frame(dfQ2RocMetrics, digits = 4)
t.test(lstGlmBaseRoc, lstGlmEngageAttendRoc, paired = TRUE)
t.test()

#t = -6.5062, df = 1499, p-value = 0.0000000001048
#alternative hypothesis: true difference in means is not equal to 0