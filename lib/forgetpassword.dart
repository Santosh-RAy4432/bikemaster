// ignore_for_file: prefer_const_constructors, library_private_types_in_public_api, use_build_context_synchronously

import 'package:bikemaster/login_page_rider.dart';
import 'package:bikemaster/login_page_mender.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({Key? key}) : super(key: key);

  @override
  _ForgetPasswordState createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _resetPasswordError = '';

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    try {
      final String email = _emailController.text.trim();
      final String newPassword = _newPasswordController.text.trim();
      final String confirmPassword = _confirmPasswordController.text.trim();

      if (newPassword != confirmPassword) {
        setState(() {
          _resetPasswordError = 'Passwords do not match!';
        });
        return;
      }

      await _auth.sendPasswordResetEmail(email: email);
      Fluttertoast.showToast(
        msg: 'Password reset successfully!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }

      if (_isLoginPage()) {
        _navigateToLoginPage();
      } else if (_isLoginPageMender()) {
        _navigateToLoginPageMender();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _resetPasswordError = 'An error occurred. Please try again later.';
      });
    }
  }

  void _navigateToLoginPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => LoginPage()),
    );
  }

  void _navigateToLoginPageMender() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => LoginPageMender()),
    );
  }

  bool _isLoginPage() {
    return ModalRoute.of(context)?.settings.name == LoginPage.routeName;
  }

  bool _isLoginPageMender() {
    return ModalRoute.of(context)?.settings.name == LoginPageMender.routeName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_isLoginPage()) {
              _navigateToLoginPage();
            } else if (_isLoginPageMender()) {
              _navigateToLoginPageMender();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _resetPassword,
              child: Text('Reset Password'),
            ),
            SizedBox(height: 8),
            if (_resetPasswordError.isNotEmpty)
              Text(
                _resetPasswordError,
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
