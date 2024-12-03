
###################################PREP AUDIO

setwd("D:/KMMA_documents/side_projects/FenBirdsID/")
library(tidyverse)
library(abind)
library(caret)
library(warbleR)
library(av)
library(tuneR)
library(snow)
library(furrr)
library(fs)
library(abind)
source("funs.R")


#################
####GET FILES####
#################


# Create mp3/ if necessary
if(!dir.exists("mp3/")){
  dir.create("mp3/")
}
if(!dir.exists("mp3/nc")){
  dir.create("mp3/nc")
}


#TARGET SPECIES
#### Download HQ male song recordings for target species > 20s & <180s ####
species_list_song <- c("Gallinago gallinago", "Porzana porzana", "Crex crex", "Luscinia svecica",
                  "Aegolius funereus", "Luscinia megarhynchos", "Bubo bubo", "Coturnix coturnix", "Aegolius funereus")
species_list_mixed <- c("Grus grus", "Perdix perdix", "Porzana parva", "Porzana pusilla", "Anas crecca")

query_song <- XN_listquery_song(species_list_song)
query_mixed <- XN_listquery_mixed(species_list_mixed)
query <- rbind(query_song, query_mixed)
query$Species <- with(query, paste(Genus, Specific_epithet)) #add full species name column
#now balance number of recordings per species
balancedClassesQ <- lapply(c(species_list_song, species_list_mixed), function(x){
  set.seed(100)
  sample(which(query$Species == x), 60, replace = FALSE) #here balancing is set to 150 samples/target species
}) %>% unlist()
query_selection <- query[balancedClassesQ,]
# Download using updated query
query_xc(X = query_selection, download = T, path = "mp3/", parallel = 1)
query_xc(X = filter(query_selection, Recording_ID != "153408"), download = T, path = "mp3/", parallel = 1) # because that entry is corrupted


#NO CLASS GROUP --> /mp3/sounds.zip contains recorded sounds (chatter, machine noises, rain, thunderstorm):they are named /mp3/no-class-1000
#### download mp3 of common birds in the same area so the CNN can recognize noise
nc_list_song <- c("Acrocephalus scirpaceus", "Acrocephalus palustris", "Turdus merula", "Erithacus rubecula",
             "Sturnus vulgaris", "Hirundo rustica", "Linaria cannabina", "Fringilla coelebs","Sylvia communis", 
             "Sylvia atricapilla", "Parus major", "Turdus philomelos", "Troglodytes troglodytes",
             "Prunella modularis", "Anthus trivialis", "Lullula arborea", "Saxicola rubicola", "Sylvia borin", "Cuculus canorus")
nc_list_mixed <- c("Gallinula chloropus", "Vanellus vanellus", "Numenius arquata")
nc_song <- XN_listquery_song(nc_list_song)
nc_mixed <- XN_listquery_mixed(nc_list_mixed)
nc <- rbind(nc_song, nc_mixed)
nc <- rbind(nc, query_xc("Anser anser type:flight len_gt:20")[2:50,0:25]) #add geese afterwards because they have flight calls
nc <- rbind(nc, query_xc("Alopochen aegyptiaca type:flight len_gt:20")[2:50,0:25])
nc$Species <- with(nc, paste(Genus, Specific_epithet)) #add full species name column
nc <- na.omit(nc)
#now balance number of recordings per species
balancedClassesNC <- lapply(nc_list, function(x){
  set.seed(100)
  sample(which(nc$Species == x), 15, replace = FALSE) #we sample 50 recordings / species
}) %>% unlist()
nc <- nc[balancedClassesNC, ]
# Download using updated query
query_xc(X = nc, download = T, path = "mp3/nc/", parallel = 1)



##############
####ENCODE####
##############


#rename all no-class files in mp3/nc and move them to the /mp3 folder
nc_files <- list.files("mp3/nc", full.names = T, patt = "*.mp3")
new_name <- paste0("mp3/nc/no-class-",1:length(nc_files),".mp3")
file.copy(from = nc_files, to = new_name)
file.remove(nc_files)
for (f in new_name) {
  file_move(f, "D:/KMMA_documents/side_projects/FenBirdsID/mp3/")
}


#### Pre-processing ####
# Read files
fnames <- list.files("mp3/", full.names = T, patt = "*.mp3")

# view spectrogram of random defined species / play 
s <- grep("bubo", fnames, value = TRUE)
p <- sample(s, 1)
fft_data <- read_audio_fft(p, end_time = 10.0)
dim(fft_data)
plot(fft_data)
m <- readMP3(p)
plot(m)
play(m)


# Encode species from fnames regex
species <- str_extract(fnames, patt = "[A-Za-z]+-[a-z]+") %>%
  gsub(patt = "-", rep = " ") %>% factor()
unique(species)

# Stratified sampling: train (80%), val (10%) and test (10%)
set.seed(100)
idx <- createFolds(species, k = 10)
valIdx <- idx$Fold01
testIdx <- idx$Fold02
# Define samples for train, val and test
fnamesTrain <- fnames[-c(valIdx, testIdx)]
fnamesVal <- fnames[valIdx]
fnamesTest <- fnames[testIdx]

# Take multiple readings per sample for training 

source("funs.R")

Xtrain <-  audioProcess(files = fnamesTrain,
                         limit = 10, ws = 10, stride = 5)
Xval <- audioProcess(files = fnamesVal,
                     limit = 10, ws = 10, stride = 5)
Xtest <- audioProcess(files = fnamesTest,
                      limit = 10, ws = 10, stride = 5)



# Define targets and augment data
target <- model.matrix(~0+species)

targetTrain <- do.call("rbind", lapply(1:(dim(Xtrain)[1]/length(fnamesTrain)),
                                       function(x) target[-c(valIdx, testIdx),]))
targetVal <- do.call("rbind", lapply(1:(dim(Xval)[1]/length(fnamesVal)),
                                     function(x) target[valIdx,]))
targetTest <- do.call("rbind", lapply(1:(dim(Xtest)[1]/length(fnamesTest)),
                                      function(x) target[testIdx,]))
# Assemble Xs and Ys
train <- list(X = Xtrain, Y = targetTrain)
val <- list(X = Xval, Y = targetVal)
test <- list(X = Xtest, Y = targetTest)

# Plot spectrogram from random training sample - range is 0-22.05 kHz
image(train$X[sample(dim(train$X)[1], 1),,,],
      xlab = "Time (s)",
      ylab = "Frequency (kHz)",
      axes = F)
image(train$X[3,,,], # or pick one
      xlab = "Time (s)",
      ylab = "Frequency (kHz)",
      axes = F)
# Generate mel sequence from Hz points, standardize to plot
freqs <- c(0, 1, 5, 15, 22.05)
mels <- 2595 * log10(1 + (freqs*1e3) / 700) # https://en.wikipedia.org/wiki/Mel_scale
mels <- mels - min(mels)
mels <- mels / max(mels)

axis(1, at = seq(0, 1, by = .2), labels = seq(0, 10, by = 2))
axis(2, at = mels, las = 2,
     labels = round(freqs, 2))
axis(3, labels = F); axis(4, labels = F)

#### Save ####
save(train, val, test, file = "prepAudio_highquality.RData")


###################
####BUILD MODEL####
###################

#for first use of keras:
#install.packages("keras")
#library("keras")
#install_keras()

library(keras)
library(tidyverse)
library(caret)
library(e1071)
library(pheatmap)
library(RColorBrewer)

# Read processed data
load("prepAudio.RData")

# Build model

model <- keras_model_sequential() %>% 
  layer_conv_2d(input_shape = dim(train$X)[2:4], 
                filters = 16, kernel_size = c(3, 3),
                activation = "relu") %>% 
  layer_max_pooling_2d(pool_size = c(2, 2)) %>% 
  layer_dropout(rate = .2) %>% 
  
  layer_conv_2d(filters = 32, kernel_size = c(3, 3),
                activation = "relu") %>% 
  layer_max_pooling_2d(pool_size = c(2, 2)) %>% 
  layer_dropout(rate = .2) %>% 
  
  layer_conv_2d(filters = 64, kernel_size = c(3, 3),
                activation = "relu") %>% 
  layer_max_pooling_2d(pool_size = c(2, 2)) %>%
  layer_dropout(rate = .2) %>% 
  
  layer_conv_2d(filters = 128, kernel_size = c(3, 3),
                activation = "relu") %>% 
  layer_max_pooling_2d(pool_size = c(28, 2)) %>%
  layer_dropout(rate = .2) %>%
  
  layer_flatten() %>% 
  
  layer_dense(units = 128, activation = "relu", kernel_regularizer = regularizer_l1(0.001)) %>% 
  layer_dropout(rate = .5) %>% 
  layer_dense(units = ncol(train$Y), activation = "softmax")


# Print summary
summary(model)
model %>% compile(optimizer = optimizer_adam(decay = 1e-5),
                  loss = "categorical_crossentropy",
                  metrics = "accuracy")

history <- fit(model, x = train$X, y = train$Y,
               batch_size = 16, epochs = 15,
               validation_data = list(val$X, val$Y))

plot(history)

# Save model
model %>% save_model_hdf5("model.qualitysounds")



##################
####VALIDATION####
##################


# Grep species, set colors for heatmap
speciesClass <- gsub(colnames(train$Y), pat = "species", rep = "")
save(speciesClass, file = "speciesClass.Rdata")
cols <- colorRampPalette(rev(brewer.pal(n = 7, name = "RdGy")))
# Validation predictions
predProb <- predict(model, val$X)
predClass <- speciesClass[apply(predProb, 1, which.max)]
trueClass <- speciesClass[apply(val$Y, 1, which.max)]
# Plot confusion matrix
confMat <- confusionMatrix(data = factor(predClass, levels = speciesClass),
                           reference = factor(trueClass, levels = speciesClass))

pheatmap(confMat$table, cluster_rows = F, cluster_cols = F,
         border_color = NA, show_colnames = F,
         labels_row = speciesClass,
         color = cols(max(confMat$table)+1))
# Accuracy in validation set
mean(predClass == trueClass) #0.85



# Test set prediction
predXProb <- predict(model, test$X)
predXClass <- speciesClass[apply(predXProb, 1, which.max)]
trueXClass <- speciesClass[apply(test$Y, 1, which.max)]
# Plot confusion matrix
confMatTest <- confusionMatrix(data = factor(predXClass, levels = speciesClass),
                               reference = factor(trueXClass, levels = speciesClass))

pheatmap(confMatTest$table, cluster_rows = F, cluster_cols = F,
         border_color = NA, show_colnames = F,
         labels_row = speciesClass,
         color = cols(max(confMatTest$table)+1))
# Accuracy in test set 
mean(predXClass == trueXClass) #0.87
evaluate(model, test$X, test$Y, verbose = 0)


# make link to mp3 file
testmp3 <- rep(fnamesTest, dim(Xtest)[1]/length(fnamesTest)) #we have multiple window iterations over 20s file
length(predXClass)
testmp3[41] # take for example id 331
tt <- readMP3(testmp3[41])
play(tt)
image(train$X[41,,,],
      xlab = "Time (s)",
      ylab = "Frequency (kHz)",
      axes = F)

predXClass[40]




# Write sessioninfo
writeLines(capture.output(sessionInfo()), "sessionInfo")