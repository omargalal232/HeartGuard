import joblib
import numpy as np
from sklearn.datasets import make_classification
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.metrics import confusion_matrix, classification_report, balanced_accuracy_score
from sklearn.model_selection import train_test_split
from imblearn.over_sampling import SMOTE
from sklearn.svm import SVC

# Function to generate a simple synthetic dataset for testing purposes
def generate_test_data():
    X_test_case, y_test_case = make_classification(n_samples=10, n_features=5, n_classes=2, random_state=42)
    return X_test_case, y_test_case

# Function to train and evaluate the SVM model
def train_and_evaluate_svm(X_train_case, y_train_case, X_test_case, y_test_case):
    # Standardize the features (use the same scaler for both training and testing)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train_case)
    X_test_scaled = scaler.transform(X_test_case)

    # Apply PCA for noise cancellation
    pca = PCA(n_components=0.95, random_state=42)
    X_train_denoised = pca.fit_transform(X_train_scaled)
    X_test_denoised = pca.transform(X_test_scaled)

    # Apply SMOTE to handle class imbalance
    smote = SMOTE(random_state=42)
    X_res, y_res = smote.fit_resample(X_train_denoised, y_train_case)

    # Train the SVM model
    svm = SVC(C=1.0, kernel='rbf', gamma='scale', random_state=42)
    svm.fit(X_res, y_res)

    # Save the scaler, PCA models, and SVM model
    joblib.dump(scaler, 'scaler.pkl')
    joblib.dump(pca, 'pca.pkl')
    joblib.dump(svm, 'svm_model.pkl')

    # Load the trained model and transformers
    loaded_svm = joblib.load('svm_model.pkl')
    loaded_scaler = joblib.load('scaler.pkl')
    loaded_pca = joblib.load('pca.pkl')

    # Evaluate the model
    y_pred = loaded_svm.predict(X_test_denoised)
    confusion = confusion_matrix(y_test_case, y_pred)
    report = classification_report(y_test_case, y_pred)
    balanced_acc = balanced_accuracy_score(y_test_case, y_pred)

    return confusion, report, balanced_acc

# Function to run test cases
def test_svm_model():
    X_test_case, y_test_case = generate_test_data()

    # Split the data into training and testing sets
    X_train_case, X_test_case, y_train_case, y_test_case = train_test_split(X_test_case, y_test_case, test_size=0.2, random_state=42)

    confusion, report, balanced_acc = train_and_evaluate_svm(X_train_case, y_train_case, X_test_case, y_test_case)

    # Perform assertions
    assert confusion.shape == (2, 2), f"Expected confusion matrix of shape (2, 2), got {confusion.shape}"
    assert isinstance(balanced_acc, float), f"Expected balanced accuracy to be a float, got {type(balanced_acc)}"
    assert 0 <= balanced_acc <= 1, f"Expected balanced accuracy to be between 0 and 1, got {balanced_acc}"
    assert 'precision' in report, "Precision not found in classification report"
    assert 'recall' in report, "Recall not found in classification report"
    assert 'f1-score' in report, "F1-score not found in classification report"
    
    print("All tests passed!")

# Run the test
if __name__ == "__main__":
    test_svm_model()
