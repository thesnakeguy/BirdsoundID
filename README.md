# Bird Sound Classifier using Custom CNN

This repository contains code to build, train, and use a custom Convolutional Neural Network (CNN) for identifying bird species from audio recordings. The system processes recordings from the Xeno-Canto database, trains on spectrograms of bird sounds, and can analyze new audio files to classify species.

---

## Features

- Fetch bird sound recordings from the Xeno-Canto database.
- Preprocess audio files into spectrograms suitable for CNN input.
- Train a CNN model to classify bird sounds.
- Use the trained model to analyze query audio files for bird species identification.
- Generate detailed outputs including classifications, timestamps, and visualizations.

---

## Installation

1. Clone this repository:
    ```bash
    git clone https://github.com/your-username/bird-sound-classifier.git
    cd bird-sound-classifier
    ```

2. Install the required R packages:
    ```r
    install.packages(c("tidyverse", "warbleR", "av", "tuneR", "snow", "furrr", 
                       "fs", "abind", "caret", "keras", "e1071", "pheatmap", "RColorBrewer"))
    ```

3. Install TensorFlow for Keras:
    ```r
    library(keras)
    install_keras()
    ```

---

## Usage

### 1. **Training the Model**
This part involves preprocessing audio data, building a CNN model, and training it.

#### Preprocessing:
- Fetch and balance bird sound recordings for target and background species.
- Convert audio files into spectrograms and stratify data into training, validation, and testing sets.

#### Training:
- Use the following code to train the CNN:
    ```r
    source("funs.R") # Load utility functions

    # Train the model
    history <- fit(model, x = train$X, y = train$Y,
                   batch_size = 16, epochs = 15,
                   validation_data = list(val$X, val$Y))
    ```

#### Evaluation:
- Validate the model and test its accuracy on unseen data.

### 2. **Using the Model**
Once trained, the model can be used to classify bird species from a query audio file.

#### Step-by-step Instructions:

1. **Prepare the Query Audio File**:
    - Split the audio into overlapping windows of specified size and stride.
    ```r
    query = "path/to/your/query_audio.mp3"
    windsiz = 10 # Window size in seconds
    strid = 5    # Stride length in seconds
    queryX <- audioProcess(files = query, limit = (query_dur - windsiz), ws = windsiz, stride = strid)
    ```

2. **Load the Model and Predict**:
    - Load the trained CNN and classify species in each time window.
    ```r
    model <- load_model_tf(filepath = "path/to/your/saved_model")
    predXquery <- predict(model, queryX)
    ```

3. **Output Results**:
    - Create a detailed table of predictions, including timestamps, species IDs, and classification accuracy.
    - Filter results by accuracy and visualize them using a pie chart and spectrogram.
    ```r
    # Create summary table
    queryTable <- data.frame(cbind(timestamp, predXClass, as.numeric(accuracy)))
    queryTable <- filter(queryTable, accuracy >= 0.9 & ID != "no class")

    # Generate pie chart
    ggplot(queryTable, aes(x="", y=n, fill=ID)) +
      geom_bar(stat="identity", width=1, color="white") +
      coord_polar("y", start=0) +
      labs(title = "Pie chart of detected species") +
      theme_void()

    # Spectrogram visualization
    image(queryX[33,,,],
          xlab = "Time (s)",
          ylab = "Frequency (kHz)",
          axes = F)
    ```

---

## Example Workflow

1. **Train the Model**:
    - Preprocess audio and train the CNN as described above.

2. **Test a Query Audio File**:
    - Use the code provided in the "Using the Model" section to predict bird species in a new audio file.

3. **Visualize Results**:
    - Generate visualizations like pie charts of detected species and spectrograms of audio segments.

---

## Dependencies

- [Xeno-Canto API](https://www.xeno-canto.org/)
- R (≥ 4.0.0)
- Keras with TensorFlow backend

---

## Acknowledgments

- Bird sound data sourced from the Xeno-Canto database.
- The `warbleR` package for Xeno-Canto queries and audio handling.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
