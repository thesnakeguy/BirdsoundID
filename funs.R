# Tue Feb 11 21:15:22 2020 ------------------------------
library(abind)
library(tuneR)
library(bioacoustics)
library(stringr)


# batch query a list of species in Xeno Canto
XN_listquery_song <- function(x) {
        l <- data.frame()
        for (i in (1:length(x))) {
                print(x[i])
                escaped <- paste(x[i], "type:song len_gt:25 len_lt:180 q_gt:C" )
                qEsc <- query_xc(escaped)
                lenEsc <- dim(qEsc)[1]
                l <- (rbind(l, qEsc[2:lenEsc,0:25]))
        }
        l <- na.omit(l)
        return(l)
}

XN_listquery_mixed <- function(x) {
        l <- data.frame()
        for (i in (1:length(x))) {
                print(x[i])
                escaped <- paste(x[i], "len_gt:25 len_lt:180 q_gt:C" )
                qEsc <- query_xc(escaped)
                lenEsc <- dim(qEsc)[1]
                l <- (rbind(l, qEsc[2:lenEsc,0:25]))
        }
        l <- na.omit(l)
        return(l)
}

# function to determine lenght of .wav or .mp3 file
det.length <- function(x) { if (str_sub(tolower(x), -3, -1)=="mp3") {
        return(round(length(readMP3(x)@left) / readMP3(x)@samp.rate, 2))} else if (str_sub(tolower(x), -3, -1)=="wav") {
                return(round(length(read_wav(x)@left) / read_wav(x)@samp.rate, 2))} else
                        (print('Unknown file type of search query, please select a .mp3 or .wav file'))
}


# read, stereo to mono, downsample, clip, mel spec, normalize and remove noise
# make melspec function for .wav and .mp3 files
melspec <- function(x, start, end){
        if (str_sub(tolower(x),-3,-1)=="mp3") {
                prep <- if (nchannel(readMP3(x))==2) {mono(readMP3(x), "both")} else {readMP3(x)}  # stereo to mono
                mp3 <- prep %>% extractWave(xunit = "time",from = start, to = end)
                
                # return log-spectrogram with 256 Mel bands and compression
                sp <- melfcc(mp3, nbands = 256, usecmp = T,
                             spec_out = T,
                             hoptime = (end-start) / 256)$aspectrum
                
                # Median-based noise reduction
                noise <- apply(sp, 1, median)
                sp <- sweep(sp, 1, noise)
                sp[sp < 0] <- 0
                
                # Normalize to max
                sp <- sp / max(sp)
        
                return(sp)}
        else if (str_sub(tolower(x),-3,-1)=="wav") {
                prep <- if (nchannel(read_wav(x))==2) {mono(read_wav(x), "both")} else {read_wav(x)}  # stereo to mono
                wav <- prep %>% extractWave(xunit = "time",from = start, to = end)
                
                # return log-spectrogram with 256 Mel bands and compression
                sp <- melfcc(wav, nbands = 256, usecmp = T,
                             spec_out = T,
                             hoptime = (end-start) / 256)$aspectrum
                
                # Median-based noise reduction
                noise <- apply(sp, 1, median)
                sp <- sweep(sp, 1, noise)
                sp[sp < 0] <- 0
                
                # Normalize to max
                sp <- sp / max(sp)
                
                return(sp)}
        else {print("Unknown file type, please convert to .mp3 or .wav")}
        
        
}

# iterate melspec over all samples, arrange output into array
melslice <- function(x, from, to){
        lapply(X = x, FUN = melspec,
               start = from, end = to) %>%
                simplify2array()
}


# iterate melslice over all different time windows
audioProcess <- function(files, limit = 10, ws = 10, stride = 5){
        windowSize <- seq(0, limit, by = stride)
        melfu <- function(w){
                melslice(files, from = w, to = w+ws)
        }
        # iterate and parallelise
        batches <- lapply(windowSize, melfu)
        # combine output into single array
        out <- abind(batches, along = 3)
        # reorder dimensions after adding single-channel as 4th
        dim(out) <- c(dim(out), 1)
        out <- aperm(out, c(3,1,2,4))
        return(out)
}

#seconds to days, hours, minutes, seconds
dhms <- function(t){
        paste(t %/% (60*60*24) 
              ,paste(formatC(t %/% (60*60) %% 24, width = 2, format = "d", flag = "0")
                     ,formatC(t %/% 60 %% 60, width = 2, format = "d", flag = "0")
                     ,formatC(t %% 60, width = 2, format = "d", flag = "0")
                     ,sep = ":"
              )
        )
}


        