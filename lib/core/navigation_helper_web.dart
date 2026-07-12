import 'package:flutter/material.dart';
import 'dart:html' as html;

void navigateToInvestorPortal(BuildContext context) {
  html.window.location.href = '/investor/';
}
