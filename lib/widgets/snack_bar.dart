import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showSuccessSnackbar(String message) {
  Get.snackbar(
    "Success",
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.green,
    colorText: Colors.white,
    borderRadius: 12,
    margin: EdgeInsets.all(12),
    duration: Duration(seconds: 3),
    icon: Icon(Icons.check_circle, color: Colors.white),
    shouldIconPulse: false,
  );
}

void showErrorSnackbar(String message) {
  Get.snackbar(
    "Error",
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red,
    colorText: Colors.white,
    borderRadius: 12,
    margin: EdgeInsets.all(12),
    duration: Duration(seconds: 3),
    icon: Icon(Icons.error, color: Colors.white),
    shouldIconPulse: false,
  );
}
