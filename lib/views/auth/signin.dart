import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'signup.dart'; // Import the SignUpPage
import '../../dashboard/chats&calls_button.dart'; // Correct the path to the actual location of HomePage
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:loading_animation_widget/loading_animation_widget.dart'; // Import loading animation

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = true; // Start with loading true
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Sign out any existing user to prevent auto sign-in
    await _auth.signOut();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. First attempt email/password sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null) {
        setState(() {
          _errorMessage = 'Sign in failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // 2. Strictly enforce email verification
      if (!user.emailVerified) {
        await _auth.signOut(); // Sign out since email isn't verified
        setState(() {
          _errorMessage =
              'Please verify your email first. Check your inbox for the verification link.';
          _isLoading = false;
        });
        return;
      }

      // 3. Verify Firestore record exists and is synced
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut(); // Sign out since user record doesn't exist
        setState(() {
          _errorMessage = 'Account not properly set up. Please sign up again.';
          _isLoading = false;
        });
        return;
      }

      // 4. Update Firestore verification status if needed
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null || (userData['emailVerified'] != true)) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'emailVerified': true});
      }

      // 5. Successful login - navigate to home
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage =
              'No account found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please check your email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed. Please try again.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
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
                'Sign in',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Chivo',
                    color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                'Stay updated on your professional world.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[600],
                  fontFamily: 'Chivo',
                ),
              ),
              SizedBox(height: 35),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Chivo',
                ),
              ),
              SizedBox(height: 16),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscureText, // Use the state variable here
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Toggle the state
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Chivo',
                ),
              ),
              SizedBox(height: 0),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot-password');
                    print('Forgot Password clicked');
                  },
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Chivo',
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          color: Colors.black,
                          height: 2,
                          width: 124,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),

              // Sign In Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor: Colors.blue,
                ),
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                    ? LoadingAnimationWidget.threeRotatingDots(
                        color: Colors.white,
                        size: 24,
                      )
                    : Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.white,
                          fontFamily: 'Chivo',
                        ),
                      ),
              ),
              SizedBox(height: 12),

              // Privacy Policy Text
              Text(
                'You agree to User Agreement, Privacy Policy, and Cookie Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.0,
                  color: Colors.grey[600],
                  fontFamily: 'Chivo',
                ),
              ),
              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Chivo',
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 16),

              // Create a New Account Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  side: BorderSide(color: Colors.grey),
                ),
                icon: Icon(
                  Icons.person_add,
                  size: 22.0,
                  color: Colors.blue,
                ),
                label: Text(
                  'Create a New Account',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Chivo',
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                  );
                },
              ),
              SizedBox(height: 16),

              // Divider with "or"
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Chivo'),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 10),

              Text(
                'Agree and sign in with',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey[600],
                  fontFamily: 'Chivo',
                ),
              ),

              SizedBox(height: 10),

              // Google Sign In Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  side: BorderSide(color: Colors.grey),
                ),
                icon: Image.asset(
                  'assets/images/google_icon.png',
                  height: 18.0,
                ),
                label: Text(
                  'Continue with Google',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Chivo',
                  ),
                ),
                onPressed: () {
                  print('Google Sign-In clicked');
                },
              ),
              SizedBox(height: 8),

              // Apple Sign In Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  side: BorderSide(color: Colors.grey),
                ),
                icon: Icon(
                  Icons.apple,
                  size: 24.0,
                  color: Colors.black,
                ),
                label: Text(
                  'Sign in with Apple',
                  style: TextStyle(color: Colors.black, fontFamily: 'Chivo'),
                ),
                onPressed: () {
                  print('Apple Sign-In clicked');
                },
              ),

              SizedBox(height: 16),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
