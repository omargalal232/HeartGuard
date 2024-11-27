import os
import librosa
import numpy as np
import pandas as pd

# Directory containing the PhysioNet dataset
data_dir = [r"Data\raw\dataset'\training-a", r"Data\raw\dataset'\training-b", r"Data\raw\dataset'\training-c", r"Data\raw\dataset'\training-d", r"Data\raw\dataset'\training-e", r"Data\raw\dataset'\training-f"]  # Add more directories if needed

label_file = os.path.join(data_dir[0], r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\raw\dataset'\annotations\Online_Appendix_training_set.csv")  # Adjust the path if needed

# Read the label file
labels_df = pd.read_csv(label_file)

# Ensure correct columns are present
if 'Challenge record name' not in labels_df.columns or 'Class (-1=normal 1=abnormal)' not in labels_df.columns:
    raise ValueError("Label file must contain 'Challenge record name' and 'Class (-1=normal 1=abnormal)' columns")

# Rename columns to match the expected names
labels_df = labels_df.rename(columns={
    'Challenge record name': 'file_name',
    'Class (-1=normal 1=abnormal)': 'label'
})

# Initialize feature and label lists
features = []
labels = []

# Process audio files
for _, row in labels_df.iterrows():
    file_name = row["file_name"] + ".wav"
    label = 0 if row["label"] == -1 else 1  # Map -1 to 0 (normal) and 1 to 1 (abnormal)
    file_path = None

    # Check in all directories
    for audio_dir in data_dir:
        potential_file_path = os.path.join(audio_dir, file_name)
        if os.path.exists(potential_file_path):
            file_path = potential_file_path
            break

    if file_path:
        try:
            # Load audio and extract features
            y, sr = librosa.load(file_path, sr=None)
            mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=30).mean(axis=1)
            
            features.append(mfccs)
            labels.append(label)
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
    else:
        print(f"File not found: {file_name}")

# Convert to arrays and save
X = np.array(features)
y = np.array(labels)
np.save('X.npy', X)
np.save('y.npy', y)
print("Feature extraction complete. Features and labels saved.")
