import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void navigateToInvestorPortal(BuildContext context) {
  // No-op: Investor portal removed from Flutter project
}

void openExternalUrl(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
