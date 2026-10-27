import 'package:flutter/material.dart';
import 'services/auth_gate.dart';

void main() => runApp(const ParkirApp());

class ParkirApp extends StatelessWidget {
  const ParkirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkVisi',
      debugShowCheckedModeBanner: false,
      // tema kamu yang sudah ada tetap dipakai di sini
      home: const AuthGate(),
    );
  }
}