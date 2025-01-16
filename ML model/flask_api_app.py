import joblib
import numpy as np
import librosa
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

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

# Flask route to handle file uploads and predictions
@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # Save the uploaded file temporarily
    file_path = os.path.join(os.path.dirname(__file__), file.filename)
    file.save(file_path)

    # Predict the abnormality
    result = predict_abnormality(file_path)

    # Return the result as a JSON response
    if result:
        return jsonify({"result": result}), 200
    else:
        return jsonify({"error": "Prediction failed"}), 500

if __name__ == "__main__":
    # Run the Flask app
    app.run(debug=True)
