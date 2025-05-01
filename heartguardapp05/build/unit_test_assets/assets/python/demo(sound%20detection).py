import joblib
import numpy as np
import librosa
import os
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.svm import SVC
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score
from imblearn.over_sampling import SMOTE

# Function to preprocess audio and extract MFCC features
def preprocess_audio(file_path):
    """
    This function extracts MFCC features from an audio file for prediction.
    """
    # Load the MP3 file using librosa
    # sr=None to preserve the original sample rate
    y, sr = librosa.load(file_path, sr=None)  
    
    # Extract MFCC features (same number of MFCCs as used in training)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=30) 
    
    # Average the MFCCs across time (axis=1) and flatten it into a 1D array
    features = np.mean(mfcc.T, axis=0)
    
    # Reshape to 2D array (1 sample, 30 features) as required by the model
    features = features.reshape(1, -1)
    
    return features

# Function to predict if a heart sound is abnormal
def predict_abnormality(file_path):
    # Function to load models with a check for existence
    def load_model(filename):
        if not os.path.exists(filename):
            print(f"Error: {filename} not found.")
            return None
        return joblib.load(filename)
    
    # Load the trained models (SVM, scaler, PCA)
    svm = load_model(os.path.join(os.path.dirname(__file__), 'svm_model.pkl'))  
    scaler = load_model(os.path.join(os.path.dirname(__file__), 'scaler.pkl'))
    pca = load_model(os.path.join(os.path.dirname(__file__), 'pca.pkl'))

    if svm is None or scaler is None or pca is None:
        print("Error loading one or more models.")
        return None

    # Preprocess the outsourced heart sound (MP3 file)
    X_input = preprocess_audio(file_path) 

    # Standardize the features using the same scaler used during training
    X_scaled = scaler.transform(X_input)

    # Apply PCA for noise cancellation using the same PCA model
    X_denoised = pca.transform(X_scaled)

    # Predict the class (normal or abnormal)
    prediction = svm.predict(X_denoised)
    
    # Return the result
    if prediction == 0:
        return "Normal"
    else:
        return "Abnormal"

# Function to process all audio files in a directory
def process_all_audio_files(directory_path):
    # Check if the directory exists
    if not os.path.exists(directory_path):
        print(f"Error: Directory {directory_path} does not exist.")
        return
    
    files = [filename for filename in os.listdir(directory_path) if filename.endswith(".mp3")]
    
    if not files:
        print("No MP3 files found in the directory.")
        return

    for filename in files:
        print(f"Processing file: {filename}")
        file_path = os.path.join(directory_path, filename)
        result = predict_abnormality(file_path)
        if result:
            print(f"File: {filename}, Heart sound is: {result}")

# Main block to process audio files
if __name__ == "__main__":
    # Specify the relative path to the directory containing the audio files
    directory_path = "ML model/raw/demo sounds"

    # Process all audio files in the directory
    process_all_audio_files(directory_path)

