import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:document_file_save_plus/document_file_save_plus.dart';

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
  String? _folderUri;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _folderUri = prefs.getString('folder_uri');
    });
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_uri', result);

    setState(() {
      _folderUri = result;
      _status = 'Folder selected';
    });
  }

  Future<void> _ripMe() async {
    if (_folderUri == null) {
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

    await DocumentFileSavePlus.saveFile(
      utf8.encode(jsonEncode(job)),
      jobId,
      "application/json",
      _folderUri!,
    );

    setState(() {
      _status = 'Job created';
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
