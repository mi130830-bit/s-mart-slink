import 'package:flutter/material.dart';
import '../services/alert_service.dart';

class SnackbarUtils {
  static void showLeft(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
    AlertService.show(
      context: context,
      message: message,
      type: isError ? 'error' : 'success',
    );
  }
}
