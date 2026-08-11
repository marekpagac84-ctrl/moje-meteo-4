import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Text(
          'Aplikácia funguje!',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    ),
  ));
}
