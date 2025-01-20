from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import joblib
import numpy as np
import librosa
import os

app = FastAPI()

# Load models
svm = joblib.load('svm_model.pkl')
scaler = joblib.load('scaler.pkl')
pca = joblib.load('pca.pkl')

def preprocess_audio(file_path):
    y, sr = librosa.load(file_path, sr=None)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=30)
    features = np.mean(mfcc.T, axis=0).reshape(1, -1)
    return features

def predict_abnormality(file_path):
    X_input = preprocess_audio(file_path)
    X_scaled = scaler.transform(X_input)
    X_denoised = pca.transform(X_scaled)
    prediction = svm.predict(X_denoised)
    return "Normal" if prediction == 0 else "Abnormal"

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    file_path = os.path.join("temp", file.filename)
    with open(file_path, "wb") as f:
        f.write(await file.read())
    result = predict_abnormality(file_path)
    os.remove(file_path)  # Clean up the temporary file
    return JSONResponse(content={"result": result})