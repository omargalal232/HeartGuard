import numpy as np
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.metrics import classification_report, confusion_matrix, balanced_accuracy_score
import matplotlib.pyplot as plt
import seaborn as sns
from imblearn.over_sampling import SMOTE
from collections import Counter

# Load the datasets
datasets = [
    {"X": np.load(r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\x.npy"), 
     "y": np.load(r"C:\Users\Egy Sky\Documents\GitHub\SWE-project\HeartGuard\Data\y.npy")}
]

# Loop through each dataset
for dataset in datasets:
    X = dataset["X"]
    y = dataset["y"]

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    # Apply SMOTE to handle class imbalance
    smote = SMOTE(random_state=42)
    X_train_res, y_train_res = smote.fit_resample(X_train, y_train)

    print("Class distribution before SMOTE:", Counter(y_train))
    print("Class distribution after SMOTE:", Counter(y_train_res))

    # List of different k values to test (for GridSearchCV)
    param_grid = {
        'n_neighbors': range(1, 21),  # Values for k (number of neighbors)
        'weights': ['uniform', 'distance'],  # Options for weights (uniform or distance)
    }

    # Initialize the KNN classifier
    knn = KNeighborsClassifier()

    # Initialize GridSearchCV to tune hyperparameters
    grid_search = GridSearchCV(estimator=knn, param_grid=param_grid, cv=5, n_jobs=-1, scoring='accuracy')

    # Fit the grid search to the resampled training data
    grid_search.fit(X_train_res, y_train_res)

    # Print the best parameters from GridSearchCV
    print(f"Best parameters: {grid_search.best_params_}")
    best_knn = grid_search.best_estimator_

    # Train the best model and predict on the test set
    y_pred = best_knn.predict(X_test)

    # Confusion Matrix
    conf_matrix = confusion_matrix(y_test, y_pred)
    print("Confusion Matrix:")
    print(conf_matrix)

    # Plotting the Confusion Matrix
    plt.figure(figsize=(8, 6))
    sns.heatmap(conf_matrix, annot=True, fmt='d', cmap='Blues', xticklabels=np.unique(y), yticklabels=np.unique(y))
    plt.title('Confusion Matrix')
    plt.xlabel('Predicted')
    plt.ylabel('Actual')
    plt.show()

    # Classification Report
    class_report = classification_report(y_test, y_pred, output_dict=True)
    print("Classification Report:")
    print(classification_report(y_test, y_pred))

    # Extracting precision, recall, f1-score
    precision = [class_report[str(cls)]['precision'] for cls in np.unique(y)]
    recall = [class_report[str(cls)]['recall'] for cls in np.unique(y)]
    f1_score = [class_report[str(cls)]['f1-score'] for cls in np.unique(y)]

    # Plotting the Classification Report (Precision, Recall, F1-score)
    x_labels = np.unique(y)
    x = np.arange(len(x_labels))

    # Create a plot with subplots for Precision, Recall, and F1-Score
    fig, ax = plt.subplots(figsize=(10, 6))

    bar_width = 0.25
    opacity = 0.8

    rects1 = ax.bar(x - bar_width, precision, bar_width, label='Precision')
    rects2 = ax.bar(x, recall, bar_width, label='Recall')
    rects3 = ax.bar(x + bar_width, f1_score, bar_width, label='F1-score')

    ax.set_xlabel('Classes')
    ax.set_ylabel('Scores')
    ax.set_title('Classification Report: Precision, Recall, and F1-score')
    ax.set_xticks(x)
    ax.set_xticklabels(x_labels)
    ax.legend()

    plt.tight_layout()
    plt.show()

    # Balanced Accuracy
    balanced_acc = balanced_accuracy_score(y_test, y_pred)
    print(f"Balanced Accuracy: {balanced_acc}")
