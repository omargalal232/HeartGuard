import 'package:flutter/material.dart';

/// A custom text field widget with consistent styling and accessibility features.
/// 
/// This widget provides a standardized text input field with:
/// - Consistent styling across the app
/// - Built-in accessibility support
/// - Input validation
/// - Keyboard action handling
/// - Password visibility toggle for password fields
class CustomTextField extends StatefulWidget {
  /// Controller for managing the text input
  final TextEditingController controller;
  
  /// Hint text to display when the field is empty
  final String hintText;
  
  /// Whether the text field should obscure text (for passwords)
  final bool isPassword;

  /// The type of keyboard to show (e.g., email, number)
  final TextInputType? keyboardType;

  /// The action button to show on the keyboard
  final TextInputAction? textInputAction;

  /// Callback when the keyboard action button is pressed
  final Function(String)? onSubmitted;

  /// Optional validation function
  final String? Function(String?)? validator;

  /// Optional helper text to display below the field
  final String? helperText;

  /// Optional prefix icon
  final IconData? prefixIcon;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.helperText,
    this.prefixIcon,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      onChanged: _validateInput,
      decoration: InputDecoration(
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: _errorText,
        prefixIcon: widget.prefixIcon != null 
          ? Icon(widget.prefixIcon) 
          : null,
        suffixIcon: widget.isPassword
          ? IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility : Icons.visibility_off,
                semanticLabel: _obscureText ? 'Show password' : 'Hide password',
              ),
              onPressed: () {
                setState(() => _obscureText = !_obscureText);
              },
            )
          : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  void _validateInput(String value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() {
        _errorText = error;
      });
    }
  }
} 