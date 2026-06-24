import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dynamo Chess Privacy Policy',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFD4AF37),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Last Updated: June 2026\n\n'
                  'Welcome to Dynamo Chess. We are committed to protecting your personal information and your right to privacy.\n\n'
                  '1. Information We Collect\n'
                  'We may collect personal information that you provide to us, such as your username, email address, and gameplay statistics when you register an account or interact with the application.\n\n'
                  '2. How We Use Your Information\n'
                  'We use the information we collect to operate, maintain, and provide you with the features and functionality of the game. We may also use it to communicate with you about updates, security alerts, and support messages.\n\n'
                  '3. Sharing Your Information\n'
                  'We do not share, sell, rent, or trade your information with any third parties for their promotional purposes. We may share information with third-party service providers that perform services for us or on our behalf.\n\n'
                  '4. Security\n'
                  'We implement a variety of security measures to maintain the safety of your personal information. However, no electronic transmission over the internet or information storage technology can be guaranteed to be 100% secure.\n\n'
                  '5. Contact Us\n'
                  'If you have questions or comments about this policy, you may contact us through our official support channels.',
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
