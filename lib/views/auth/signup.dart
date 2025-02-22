import 'package:flutter/material.dart';
import 'signin.dart'; // Import the SignInPage
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController =
      TextEditingController(); // Add email controller
  final TextEditingController _passwordController =
      TextEditingController(); // Add password controller
  final TextEditingController _confirmPasswordController =
      TextEditingController(); // Add this line
  final FocusNode _passwordFocusNode =
      FocusNode(); // Add FocusNode for password field
  String? _selectedGender; // Variable to store selected gender

  // Add these variables to track password validation status
  bool _isUpperCaseValid = false;
  bool _isLowerCaseValid = false;
  bool _isNumberValid = false;
  bool _isSpecialCharValid = false;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {}); // Update the UI when focus changes
    });
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose(); // Dispose of the FocusNode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Sign up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Make the most of your professional life',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),

              // Name Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Email Field
              TextField(
                controller: _emailController, // Use the email controller
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Date of Birth Field
              TextField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    _dobController.text =
                        "${pickedDate.toLocal()}".split(' ')[0];
                  }
                },
              ),
              SizedBox(height: 16),

              // Gender Field
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value; // Update selected gender
                  });
                },
              ),
              SizedBox(height: 16),

              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller:
                        _passwordController, // Use the password controller
                    obscureText: true,
                    focusNode: _passwordFocusNode, // Attach FocusNode
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isPasswordValid(value); // Validate password on change
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // Show password requirements only if the password field is focused
                  if (_passwordFocusNode.hasFocus) _buildPasswordRequirements(),
                ],
              ),
              SizedBox(height: 8),

              // Confirm Password Field
              TextField(
                controller:
                    _confirmPasswordController, // Use the confirm password controller
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onTap: () {
                  // When the Confirm Password field is tapped, unfocus the password field
                  _passwordFocusNode.unfocus();
                },
              ),
              SizedBox(height: 16),

              // Sign-Up Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor: Colors.blue,
                ),
                onPressed: () async {
                  if (_selectedGender == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please select a gender')),
                    );
                    return; // Prevent sign-up if no gender is selected
                  }

                  if (!_isPasswordValid(_passwordController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Password must include uppercase, lowercase, numbers, special characters, and be at least 8 characters long.')),
                    );
                    return; // Prevent sign-up if password is invalid
                  }

                  // Check if Password and Confirm Password match
                  if (_passwordController.text !=
                      _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Passwords do not match')),
                    );
                    return; // Prevent sign-up if passwords do not match
                  }

                  try {
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                    // Navigate to SignInPage after successful sign-up
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SignInPage()),
                    );
                  } on FirebaseAuthException {
                    // Handle error (e.g., show a message)
                    print('Error occurred during sign-up');
                  }
                },
                child: Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Already have an account? Link
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignInPage()),
                  );
                },
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update the _isPasswordValid method to set the validation status
  bool _isPasswordValid(String password) {
    _isUpperCaseValid = RegExp(r'[A-Z]').hasMatch(password);
    _isLowerCaseValid = RegExp(r'[a-z]').hasMatch(password);
    _isNumberValid = RegExp(r'[0-9]').hasMatch(password);
    _isSpecialCharValid = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return _isUpperCaseValid &&
        _isLowerCaseValid &&
        _isNumberValid &&
        _isSpecialCharValid &&
        password.length >= 8;
  }

  // Add this method to build the password requirements list
  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _buildRequirement(
            '6 to 32 characters',
            _passwordController.text.length >= 6 &&
                _passwordController.text.length <= 32),
        _buildRequirement('At least one uppercase letter', _isUpperCaseValid),
        _buildRequirement('At least one lowercase letter', _isLowerCaseValid),
        _buildRequirement('At least one number', _isNumberValid),
        _buildRequirement(
            'At least one special character', _isSpecialCharValid),
      ],
    );
  }

  // Helper method to build individual requirement
  Widget _buildRequirement(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check : Icons.check,
          color: isValid ? Colors.green : Colors.red,
        ),
        SizedBox(width: 8),
        Text(text,
            style: TextStyle(color: isValid ? Colors.green : Colors.red)),
      ],
    );
  }
}
