import 'package:flutter/material.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
    );
  }
}
