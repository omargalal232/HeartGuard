import numpy as np
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns

# Load features and labels
X = np.load('X.npy')  # Ensure you have your features here
y = np.load('y.npy')  # Ensure you have your labels here

# Split data into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# List of different k values to test
k_values = range(1, 21)
accuracy_scores = []

# Loop through different k values to calculate accuracy
for k in k_values:
    knn = KNeighborsClassifier(n_neighbors=k)
    knn.fit(X_train, y_train)
    accuracy = knn.score(X_test, y_test)
    accuracy_scores.append(accuracy)

# Plot accuracy vs. k
plt.figure(figsize=(8, 6))
plt.plot(k_values, accuracy_scores, marker='o', linestyle='-', color='b')
plt.title('Accuracy vs. Number of Neighbors (k)', fontsize=14)
plt.xlabel('Number of Neighbors (k)', fontsize=12)
plt.ylabel('Accuracy', fontsize=12)
plt.grid(True)
plt.show()

# Train the model using the best k value (max accuracy)
best_k = k_values[np.argmax(accuracy_scores)]
print(f"Best k value: {best_k}")

# Train with the best k and predict on the test set
knn = KNeighborsClassifier(n_neighbors=best_k)
knn.fit(X_train, y_train)
y_pred = knn.predict(X_test)

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
