setwd("D:/KMMA_documents/side_projects//FenBirdsID")
library(tidyverse)
library(abind)
library(caret)
library(tuneR)
library(warbleR)
library(av)
library(tuneR)
library(future.apply)
library(ggplot2)
source("D:/KMMA_documents/side_projects/FenBirdsID/funs.R")


##################
####PREP AUDIO####
##################

windsiz = 10
strid = 5
query = "D:/KMMA_documents/side_projects/FenBirdsID/testfiles/testX.mp3"
query_dur <- det.length(x = query)
queryX <- audioProcess(files = query, limit = (query_dur-windsiz), ws = windsiz, stride = strid)

#####################
####PREDICT AUDIO####
#####################

library(keras)
library(tidyverse)
library(caret)
library(e1071)
library(pheatmap)
library(RColorBrewer)

load("D:/KMMA_documents/side_projects/FenBirdsID/speciesClass.Rdata")
model <- load_model_tf(filepath = "D:/KMMA_documents/side_projects/FenBirdsID/model.qualitysounds")
model %>% compile(optimizer = optimizer_adam(decay = 1e-5),
                  loss = "categorical_crossentropy",
                  metrics = "accuracy")

#make predications for each 10s window
predXquery <- predict(model, queryX)
colnames(predXquery) <- speciesClass
predXClass <- speciesClass[apply(na.omit(predXquery), 1, which.max)]


# make link to mp3 file / spectrogram
#TABLE
timestamp <- dhms(seq(0, query_dur-windsiz, strid))
accuracy <- apply(predXquery, 1, max)
lengthmax <- max(length(timestamp), length(accuracy), length(predXClass)) #because there is NA line at end of predXClass
length(timestamp) <- lengthmax
length(accuracy) <- lengthmax
length(predXClass) <- lengthmax
queryTable <- data.frame(cbind(timestamp, predXClass, as.numeric(accuracy)))
colnames(queryTable) <- c("timestamp(s)", "ID", "accuracy")
queryTable$filter <- ifelse(queryTable$accuracy >=0.9 & queryTable$ID != "no class", "PASS", "-")
queryTable <- na.omit(queryTable)
queryTable

#PIECHART
counts <- filter(queryTable, filter=="PASS") %>% count(ID)
ggplot(counts, aes(x="", y=n, fill=ID)) +
  geom_bar(stat="identity", width=1, color="white") +
  coord_polar("y", start=0) + 
  labs(title = "Pie chart of detected species") +
  theme_void() 

#SPECTROGRAM
image(queryX[33,,,],
      xlab = "Time (s)",
      ylab = "Frequency (kHz)",
      axes = F)



