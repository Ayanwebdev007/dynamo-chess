import 'package:flutter/material.dart';
import 'dart:html' as html;

void navigateToInvestorPortal(BuildContext context) {
  html.window.location.href = '/investor/';
}

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}
