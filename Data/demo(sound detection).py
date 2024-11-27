import joblib
import numpy as np
import librosa
import os
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.svm import SVC
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score
from imblearn.over_sampling import SMOTE

def preprocess_audio(file_path):
    # Load the MP3 file using librosa
    y, sr = librosa.load(file_path, sr=None)  # sr=None to preserve the original sample rate
    
    # Extract MFCC features
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=30)  # Extract 13 MFCCs
    
    # Average the MFCCs across time (axis=1) and flatten it into a 1D array
    features = np.mean(mfcc.T, axis=0)
    
    # Reshape to 2D array (1 sample, 13 features)
    features = features.reshape(1, -1)
    
    return features

def predict_abnormality(file_path):
    """
    This function uses the pre-trained SVM model to predict whether the heart sound from an MP3 file is abnormal.
    """
    # Load the trained models (SVM, scaler, PCA)
    svm = joblib.load(r"Data\svm_model.pkl")  # Ensure the path is correct
    scaler = joblib.load(r"Data\scaler.pkl")
    pca = joblib.load(r"Data\pca.pkl")

    # Step 1: Preprocess the outsourced heart sound (MP3 file)
    X_input = preprocess_audio(file_path)  # Use the passed file_path here

    # Step 2: Standardize the features using the same scaler used during training
    X_scaled = scaler.transform(X_input)

    # Step 3: Apply PCA for noise cancellation using the same PCA model
    X_denoised = pca.transform(X_scaled)

    # Step 4: Predict the class (normal or abnormal)
    prediction = svm.predict(X_denoised)
    
    # Step 5: Return the result
    if prediction == 0:
        return "Normal"
    else:
        return "Abnormal"

def process_all_audio_files(directory_path):
    # List all files in the directory
    for filename in os.listdir(directory_path):
        # Check if the file is an audio file (e.g., MP3)
        if filename.endswith(".mp3"):
            file_path = os.path.join(directory_path, filename)
            result = predict_abnormality(file_path)
            print(f"File: {filename}, Heart sound is: {result}")

# Example usage:
if __name__ == "__main__":
    # Specify the path to the directory containing the audio files
    directory_path = r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\raw\demo sounds"

    # Process all audio files in the directory
    process_all_audio_files(directory_path)
