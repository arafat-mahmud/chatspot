import 'dart:async';
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
  bool _isLoading = true;
  bool _obscureText = true;
  Timer? _sessionTimer;
  bool _isDisposed = false; // Track disposed state

  @override
  void initState() {
    super.initState();
    _initializeAuthCheck();
  }

  Future<void> _initializeAuthCheck() async {
    try {
      await _handleReturningUser();
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error initializing authentication check';
        });
      }
    }
  }

  Future<void> _checkLastLogin(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final lastLogin = userDoc['lastLogin'] as Timestamp?;
      final now = Timestamp.now();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'lastLogin': now});

      if (lastLogin != null) {
        final difference = now.toDate().difference(lastLogin.toDate());
        if (difference.inDays >= 7) {
          await _auth.signOut();
          if (!_isDisposed && mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Session expired. Please sign in again.';
            });
          }
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error checking session. Please sign in again.';
        });
      }
    }
  }

  Future<void> _handleReturningUser() async {
    final user = _auth.currentUser;
    if (user != null && user.emailVerified) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = true);
      }

      try {
        await _checkLastLogin(user);
        if (!_isDisposed && mounted && _auth.currentUser != null) {
          _startSessionTimer(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }
      } catch (e) {
        if (!_isDisposed && mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      await _auth.signOut();
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSessionTimer(User user) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(hours: 1), (timer) async {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final lastLogin = userDoc['lastLogin'] as Timestamp?;
        if (lastLogin != null) {
          final difference = DateTime.now().difference(lastLogin.toDate());
          if (difference.inDays >= 7) {
            timer.cancel();
            await _auth.signOut();
            if (!_isDisposed && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignInPage()),
              );
            }
          }
        }
      } catch (e) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _emailController.dispose();
    _passwordController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _signIn() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null || _isDisposed || !mounted) {
        setState(() {
          _errorMessage = 'Sign in failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      if (!user.emailVerified) {
        await _auth.signOut();
        if (!_isDisposed && mounted) {
          setState(() {
            _errorMessage = 'Please verify your email first.';
            _isLoading = false;
          });
        }
        return;
      }

      // Get or create user document
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Use set with merge to create or update the document
      await userDocRef.set({
        'email': user.email,
        'emailVerified': true,
        'lastLogin': FieldValue.serverTimestamp(), // Use server timestamp
      }, SetOptions(merge: true));

      // Now get the document to check if it exists
      DocumentSnapshot userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        await _auth.signOut();
        if (!_isDisposed && mounted) {
          setState(() {
            _errorMessage =
                'Account not properly set up. Please sign up again.';
            _isLoading = false;
          });
        }
        return;
      }

      // Start session timer
      if (_isDisposed || !mounted) return;
      _startSessionTimer(user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (_isDisposed || !mounted) return;

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please check your email.';
          break;
        case 'user-disabled':
          errorMessage = 'Account disabled. Contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Try again later.';
          break;
        default:
          errorMessage = 'Login failed. Please try again.';
      }

      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
          _isLoading = false;
        });
      }
    }
  }

  // [REST OF YOUR EXISTING BUILD METHOD REMAINS EXACTLY THE SAME]
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
