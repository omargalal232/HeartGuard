import '../models/user_model.dart';

class UserController {
  User? currentUser;

  void login(String name, String email) {
    currentUser = User(name: name, email: email);
    // Additional login logic (e.g., API calls) can be added here
  }

  void updateProfile(String name, String email, String profilePicture) {
    if (currentUser != null) {
      currentUser!.name = name;
      currentUser!.email = email;
      currentUser!.profilePicture = profilePicture;
    }
  }
}
