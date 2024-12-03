# BirdsoundID

This repository contains code to build and train a custom Convolutional Neural Network (CNN) that identifies bird sounds. The model uses recordings from the Xeno-Canto database, focusing on a user-specified list of species. The repository also includes tools for preprocessing audio files and evaluating the model's performance.

## Features

- Fetch bird sound recordings from the Xeno-Canto database.
- Preprocess audio files into spectrograms suitable for CNN input.
- Train a CNN model using Keras to classify bird sounds.
- Validate and test the model's accuracy on unseen data.
- Visualize confusion matrices and spectrograms.

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

### 1. Fetching Audio Data
- The script retrieves recordings for target species and background noise species from the Xeno-Canto database.
- It balances the number of recordings per species to ensure model fairness.

### 2. Preprocessing
- Audio files are converted into spectrograms.
- Data is stratified into training (80%), validation (10%), and testing (10%) sets.

### 3. Training the CNN
- The CNN model has multiple convolutional, pooling, and dropout layers for robust feature extraction.
- The model uses categorical crossentropy as the loss function and Adam optimizer.

### 4. Evaluation
- The script evaluates the model's performance on validation and test datasets.
- Outputs include accuracy metrics and confusion matrices.

---

## Example Workflow

1. **Preprocess Audio Files**:
    - Run the preprocessing script to fetch, balance, and encode audio files into spectrograms.
    ```r
    source("funs.R")
    ```

2. **Train the Model**:
    - Build and train the CNN model on preprocessed data.
    ```r
    history <- fit(model, x = train$X, y = train$Y,
                   batch_size = 16, epochs = 15,
                   validation_data = list(val$X, val$Y))
    ```

3. **Evaluate the Model**:
    - Assess the model using confusion matrices and accuracy metrics on test data.
    ```r
    mean(predXClass == trueXClass) # Test accuracy
    ```

---

## Results

- **Validation Accuracy**: 85%
- **Test Accuracy**: 87%
- Visualization of confusion matrices for validation and test sets is included in the code.

---

## Dependencies

- [Xeno-Canto API](https://www.xeno-canto.org/)
- R (≥ 4.0.0)
- Keras and TensorFlow backend

---

## Notes

- Background noise data can be augmented by including additional files (e.g., chatter, machine noise).
- Ensure a stable internet connection for downloading recordings from Xeno-Canto.

---

## Acknowledgments

- Bird sound data sourced from the Xeno-Canto database.
- The `warbleR` package for Xeno-Canto queries and audio handling.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
