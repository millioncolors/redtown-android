import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const RedTownApp());
}

class RedTownApp extends StatelessWidget {
  const RedTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _status = 'Select folder, then RIP ME';
  String? _folderPath;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _folderPath = prefs.getString('folder_path');
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_path', path);

    setState(() {
      _folderPath = path;
      _status = 'Folder selected';
    });
  }

  Future<void> _ripMe() async {
    if (_folderPath == null) {
      setState(() => _status = 'Please select folder first');
      return;
    }

    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}.json';

    final job = {
      "job_id": jobId,
      "target": input,
      "created_at": DateTime.now().toIso8601String(),
      "state": "queued"
    };

    final file = File('$_folderPath/$jobId');
    await file.writeAsString(jsonEncode(job), flush: true);

    setState(() {
      _status = 'Job created: $jobId';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RedTown')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickFolder,
              child: const Text('Select RedTown Folder'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Subreddit (e.g. r/pics)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _ripMe,
              child: const Text('RIP ME'),
            ),
            const SizedBox(height: 20),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
