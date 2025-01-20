from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import joblib
import numpy as np
import librosa
import os

app = FastAPI()

# Ensure the temp directory exists
if not os.path.exists("temp"):
    os.makedirs("temp")

# Load models
svm = joblib.load('svm_model.pkl')
scaler = joblib.load('scaler.pkl')
pca = joblib.load('pca.pkl')

def preprocess_audio(file_path):
    try:
        # Load the audio file
        y, sr = librosa.load(file_path, sr=None)
        
        # Extract MFCC features
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=30)
        
        # Take the mean of MFCC coefficients
        features = np.mean(mfcc.T, axis=0).reshape(1, -1)
        return features
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing the audio: {e}")

def predict_abnormality(file_path):
    try:
        # Preprocess the audio to extract features
        X_input = preprocess_audio(file_path)
        
        # Scale and apply PCA transformation
        X_scaled = scaler.transform(X_input)
        X_denoised = pca.transform(X_scaled)
        
        # Make prediction
        prediction = svm.predict(X_denoised)
        
        # Return result
        return "Normal" if prediction == 0 else "Abnormal"
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error making the prediction: {e}")

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        # Save the uploaded file to the 'temp' directory
        file_path = os.path.join("temp", file.filename)
        with open(file_path, "wb") as f:
            f.write(await file.read())
        
        # Predict if the audio is normal or abnormal
        result = predict_abnormality(file_path)
        
        # Remove the temporary file after prediction
        os.remove(file_path)
        
        # Return the result as JSON
        return JSONResponse(content={"result": result})
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error handling the request: {e}")
