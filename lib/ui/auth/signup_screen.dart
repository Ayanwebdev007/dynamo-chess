import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter a username");
      return;
    }
    
    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter an email");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
      );
      if (mounted) {
        // Pop twice to go back to Main Menu (Login -> SignUp -> Main)
        Navigator.pop(context); 
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFD4AF37)),
          tooltip: "Back",
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "CREATE ACCOUNT",
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD4AF37),
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.5,
            colors: [
              Color(0xFF1E3A20), // Subtle Green Glow
              Color(0xFF0A0E0A), // Black
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 25, spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "JOIN DYNAMO CHESS",
                        style: GoogleFonts.cinzel(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign up to play online, create custom puzzles, and track your ratings.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 28),

                      _buildTextField("Username", _usernameController, Icons.person),
                      const SizedBox(height: 18),
                      _buildTextField("Email", _emailController, Icons.email),
                      const SizedBox(height: 18),
                      _buildTextField("Password", _passwordController, Icons.lock, isPassword: true),
                      
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 28),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 5,
                          ),
                          child: _isLoading 
                             ? const CircularProgressIndicator(color: Colors.black)
                             : Text("CREATE ACCOUNT", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.0)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Return to Log In Link
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 13),
                      children: [
                        TextSpan(
                          text: "Log In",
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
        filled: true,
        fillColor: Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37))),
      ),
    );
  }
}
