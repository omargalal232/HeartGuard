import numpy as np
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from imblearn.over_sampling import SMOTE
from collections import Counter
import joblib



# Load the datasets
datasets = [
    {
        "X": np.load(r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\x.npy"), 
        "y": np.load(r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\y.npy")
    }
]

# Loop through each dataset
for dataset in datasets:
    X = dataset["X"]
    y = dataset["y"]

    # Step 1: Standardize the features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # Step 2: Apply PCA for noise cancellation
    pca = PCA(n_components=0.95, random_state=42)
    X_denoised = pca.fit_transform(X_scaled)
    print("Original shape:", X.shape)
    print("Shape after noise cancellation:", X_denoised.shape)

    # Step 3: Apply SMOTE to handle class imbalance
    smote = SMOTE(random_state=42)
    X_res, y_res = smote.fit_resample(X_denoised, y)
    print("Class distribution before SMOTE:", Counter(y))
    print("Class distribution after SMOTE:", Counter(y_res))

    # Step 4: Split the resampled data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X_res, y_res, test_size=0.2, random_state=42)

    # Step 5: Train the SVM with fixed parameters
    svm = SVC(C=1.0, kernel='rbf', gamma='scale', random_state=42)
    svm.fit(X_train, y_train)

    # Step 6: Evaluate the model
    y_pred = svm.predict(X_test)

    print("Confusion Matrix:")
    print(confusion_matrix(y_test, y_pred))

    print("Classification Report:")
    print(classification_report(y_test, y_pred))

    balanced_acc = balanced_accuracy_score(y_test, y_pred)
    print(f"Balanced Accuracy: {balanced_acc}")
    
    
#===============================================================================================================
#===============================================================================================================

svm.fit(X_train, y_train)

# Save the trained SVM model to a file
joblib.dump(svm, 'Data/svm_model.pkl')
print("SVM model saved as 'svm_model.pkl'")

# Save the scaler
joblib.dump(scaler, 'Data/scaler.pkl')
print("Scaler saved as 'scaler.pkl'")

# Save the PCA
joblib.dump(pca, 'Data/pca.pkl')
print("PCA model saved as 'pca.pkl'")