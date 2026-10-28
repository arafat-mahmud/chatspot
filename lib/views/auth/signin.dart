import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'signup.dart'; // Import the SignUpPage
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
  bool _isLoading = false;
  bool _obscureText = true;
  bool _canResendVerification = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Signing in is one auth call plus one write. The auth gate opens the app
  /// as soon as Firebase reports the verified user; nothing to navigate.
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _canResendVerification = false;
    });

    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = credential.user!;

      if (!user.emailVerified) {
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Please verify your email first. '
              'Check your inbox for the link.';
          _canResendVerification = true;
          _isLoading = false;
        });
        return;
      }

      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'emailVerified': true,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((Object e) {
        debugPrint('Recording sign-in failed: $e');
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' => 'No account found. Please sign up first.',
          'wrong-password' ||
          'invalid-credential' =>
            'Incorrect email or password. Please try again.',
          'invalid-email' => 'Invalid email format. Please check your email.',
          'user-disabled' => 'Account disabled. Contact support.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          'network-request-failed' => 'No internet connection.',
          _ => 'Login failed. Please try again.',
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  /// Unverified accounts are signed out right away, so sign in briefly with
  /// the same credentials to send a fresh link.
  Future<void> _resendVerification() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await credential.user?.sendEmailVerification();
      await _auth.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification link sent. Check your inbox.';
        _canResendVerification = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            "Couldn't send the link right now. Try again in a minute.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              SizedBox(height: 8),
              Text(
                'Stay updated on your professional world.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'Chivo',
                ),
              ),
              SizedBox(height: 35),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'Chivo',
                  ),
                  floatingLabelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontFamily: 'Chivo',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Chivo',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscureText, // Use the state variable here
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'Chivo',
                  ),
                  floatingLabelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontFamily: 'Chivo',
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Toggle the state
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Chivo',
                  color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Chivo',
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          color: Theme.of(context).colorScheme.onSurface,
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
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                icon: Icon(
                  Icons.person_add,
                  size: 22.0,
                  color: Theme.of(context).iconTheme.color,
                ),
                label: Text(
                  'Create a New Account',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'Chivo'),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                icon: Image.asset(
                  'assets/images/google_icon.png',
                  height: 18.0,
                ),
                label: Text(
                  'Continue with Google',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                icon: Icon(
                  Icons.apple,
                  size: 24.0,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                label: Text(
                  'Sign in with Apple',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Chivo'),
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
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_canResendVerification)
                TextButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  child: const Text('Resend verification link'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
