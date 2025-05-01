import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import os

# Initialize Firebase App
def init_firebase(firebase_credentials_path):
    """Initialize Firebase Admin SDK with service account credentials"""
    cred = credentials.Certificate(firebase_credentials_path)
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://heart-guard-1c49e-default-rtdb.firebaseio.com'
    })
    print("Firebase initialized successfully")

# List all paths in Firebase
def list_all_paths(root_path='/'):
    """List all paths in Firebase database recursively"""
    print(f"Exploring path: {root_path}")
    
    # Get the reference for this path
    ref = db.reference(root_path)
    data = ref.get()
    
    # If no data at this path
    if data is None:
        print(f"No data found at {root_path}")
        return
    
    # If this is a leaf node (not a dictionary)
    if not isinstance(data, dict):
        print(f"Found data at {root_path}: {type(data)}")
        # If it's a list, print its length
        if isinstance(data, list):
            print(f"List length: {len(data)}")
        return
    
    # Print all keys at this level
    print(f"Found {len(data)} keys at {root_path}:")
    for key in data.keys():
        print(f"  - {key}")
    
    # Recursively explore each child path, but limit depth to avoid excessive output
    if len(root_path.split('/')) < 4:  # Limit recursion depth
        for key in data.keys():
            new_path = f"{root_path}/{key}" if root_path != '/' else f"/{key}"
            list_all_paths(new_path)

# Examine a specific path for ECG data
def examine_path(path):
    """Examine a specific path for ECG data"""
    print(f"\nExamining path: {path}")
    
    # Get the reference for this path
    ref = db.reference(path)
    data = ref.get()
    
    # If no data at this path
    if data is None:
        print(f"No data found at {path}")
        return
    
    # If this is a leaf node (not a dictionary)
    if not isinstance(data, dict):
        print(f"Found data at {path}: {type(data)}")
        return
    
    # Print all keys and examine a sample
    print(f"Found {len(data)} items at {path}")
    
    # Examine up to 3 sample items
    sample_keys = list(data.keys())[:3]
    for key in sample_keys:
        print(f"\nSample item key: {key}")
        item = data[key]
        if isinstance(item, dict):
            print("Fields:")
            for field_key, field_value in item.items():
                print(f"  - {field_key}: {type(field_value)}")
                # Print a snippet of the value
                if isinstance(field_value, str) and len(field_value) > 50:
                    print(f"    Value: {field_value[:50]}...")
                elif not isinstance(field_value, (dict, list)):
                    print(f"    Value: {field_value}")

# Main function
def main():
    # Path to Firebase credentials file
    firebase_credentials_path = 'heart-guard-1c49e-firebase-adminsdk-fbsvc-c26e006c2f.json'
    
    # Check if credentials file exists
    if not os.path.exists(firebase_credentials_path):
        print(f"Error: Firebase credentials file {firebase_credentials_path} not found.")
        print("Please ensure your Firebase service account key is in this directory.")
        return
    
    # Initialize Firebase
    init_firebase(firebase_credentials_path)
    
    # List all top-level paths
    print("\n=== Exploring all paths in Firebase database ===")
    list_all_paths()
    
    # List of potential ECG data paths to examine
    potential_ecg_paths = [
        '/readings',
        '/ecgData',
        '/users',
        '/ecg_values',
        '/ecg-readings',
        '/ecg',
        '/data',
        '/sensor_data'
    ]
    
    print("\n=== Examining potential ECG data paths ===")
    for path in potential_ecg_paths:
        examine_path(path)

if __name__ == "__main__":
    main() 