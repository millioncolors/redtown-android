import 'package:flutter/material.dart';

void main() {
  runApp(const RedTownApp());
}

class RedTownApp extends StatelessWidget {
  const RedTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedTown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedTown"),
      ),
      body: const Center(
        child: Text(
          "RedTown APK is running",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
