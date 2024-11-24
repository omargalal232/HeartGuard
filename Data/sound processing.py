import os
import librosa
import librosa.display
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# # List of directories containing audio files
# audio_dirs = ['raw/set_a', 'raw/set_b']  # Add more directories if needed

# # Output directory to save the generated images
# output_dir = 'output_images'
# os.makedirs(output_dir, exist_ok=True)  # Create the output directory if it doesn't exist

# # Loop through each directory in the list
# for audio_dir in audio_dirs:
#     print(f"Processing directory: {audio_dir}")

#     # Loop through all files in the current directory
#     for file_name in os.listdir(audio_dir):
#         # Process only .wav files
#         if file_name.endswith('.wav'):
#             file_path = os.path.join(audio_dir, file_name)
#             print(f"Processing file: {file_path}")

#             try:
#                 # Load the audio file
#                 y, sr = librosa.load(file_path, sr=None)
                
#                 # Plot and save the waveform
#                 plt.figure(figsize=(10, 4))
#                 librosa.display.waveshow(y, sr=sr)
#                 plt.title(f'Waveform: {file_name}')
#                 waveform_output_path = os.path.join(output_dir, f'{file_name}_waveform.png')
#                 plt.savefig(waveform_output_path)
#                 plt.close()
#                 print(f"Saved waveform plot: {waveform_output_path}")
                
#                 # Plot and save the MFCCs
#                 mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
#                 plt.figure(figsize=(10, 4))
#                 librosa.display.specshow(mfccs, x_axis='time', sr=sr)
#                 plt.colorbar()
#                 plt.title(f'MFCC: {file_name}')
#                 mfcc_output_path = os.path.join(output_dir, f'{file_name}_mfcc.png')
#                 plt.savefig(mfcc_output_path)
#                 plt.close()
#                 print(f"Saved MFCC plot: {mfcc_output_path}")

#             except Exception as e:
#                 print(f"Error processing {file_path}: {e}")

#=================================================================================================================
#=================================================================================================================




# List of directories containing audio files
audio_dirs = ['raw/set_a', 'raw/set_b']  # Add more directories if needed

# Prepare lists to collect data
features = []
labels = []

# Loop through each directory in the list
for audio_dir in audio_dirs:
    print(f"Processing directory: {audio_dir}")

    # Loop through all files in the current directory
    for file_name in os.listdir(audio_dir):
        # Process only .wav files
        if file_name.endswith('.wav'):
            file_path = os.path.join(audio_dir, file_name)
            print(f"Processing file: {file_path}")

            try:
                # Load the audio file
                y, sr = librosa.load(file_path, sr=None)
                
                # Extract MFCCs
                mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13).mean(axis=1)
                
                # Add MFCCs and label to lists
                features.append(mfccs)
                
                # Here, replace with actual labels (0 for normal, 1 for abnormal)
                # For example, if 'set_a' is normal, label as 0, otherwise as 1.
                label = 0 if 'set_a' in audio_dir else 1
                labels.append(label)

            except Exception as e:
                print(f"Error processing {file_path}: {e}")

# Convert to arrays and save
X = np.array(features)
y = np.array(labels)
np.save('X.npy', X)
np.save('y.npy', y)
print("Feature extraction complete. Features and labels saved.")


