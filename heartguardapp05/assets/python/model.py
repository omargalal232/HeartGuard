import numpy as np
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
import joblib
from imblearn.over_sampling import SMOTE  # Import SMOTE for oversampling

# Load the datasets
X = np.load(r"X.npy")
y = np.load(r"y.npy")

# Standardize the features
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Apply PCA for noise cancellation
pca = PCA(n_components=0.95, random_state=42)
X_denoised = pca.fit_transform(X_scaled)
print("Original shape:", X.shape)
print("Shape after noise cancellation:", X_denoised.shape)

# Oversample the dataset using SMOTE
smote = SMOTE(random_state=42)
X_resampled, y_resampled = smote.fit_resample(X_denoised, y)
print("Shape after oversampling:", X_resampled.shape)

# Split the oversampled data into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(X_resampled, y_resampled, test_size=0.2, random_state=42)

# Train the SVM with fixed parameters
svm = SVC(C=1.0, kernel='rbf', gamma='scale', random_state=42)
svm.fit(X_train, y_train)

# Evaluate the model
y_pred = svm.predict(X_test)

print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

print("Classification Report:")
print(classification_report(y_test, y_pred))

balanced_acc = balanced_accuracy_score(y_test, y_pred)
print(f"Balanced Accuracy: {balanced_acc}")

print("================================================================")
print("================================================================")

# Save the trained SVM model to a file
joblib.dump(svm, 'ML model/svm_model.pkl')
print("SVM model saved as 'svm_model.pkl'")

# Save the scaler
joblib.dump(scaler, 'ML model/scaler.pkl')
# Save the PCA
joblib.dump(pca, 'ML model/pca.pkl')
