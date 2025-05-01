import 'package:flutter/material.dart';

/// A custom button widget with consistent styling
class CustomButton extends StatelessWidget {
  /// The text to display on the button
  final String label;
  
  /// Callback function when the button is pressed
  final VoidCallback onPressed;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
} 