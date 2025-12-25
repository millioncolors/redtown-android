import 'dart:convert';
import 'dart:io';
import 'dart:async';

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

/* ===========================
   HOME SCREEN
=========================== */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _folderPath;
  String _status = 'Select folder, then RIP ME';

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _folderPath = prefs.getString('folder_path');
      if (_folderPath != null) {
        _status = 'Folder: $_folderPath';
      }
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('folder_path', path);

    setState(() {
      _folderPath = path;
      _status = 'Folder selected:\n$path';
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
      "job_id": jobId.replace(".json", ""),
      "target": input,
      "created_at": DateTime.now().toIso8601String(),
      "state": "queued"
    };

    final file = File('$_folderPath/$jobId');
    await file.writeAsString(jsonEncode(job), flush: true);

    setState(() {
      _status = 'Job created: ${job["job_id"]}';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RedTown'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadCenter()),
              );
            },
          )
        ],
      ),
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
                labelText: 'Subreddit or Username (e.g. r/pics)',
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

/* ===========================
   DOWNLOAD CENTER
=========================== */

class DownloadCenter extends StatefulWidget {
  const DownloadCenter({super.key});

  @override
  State<DownloadCenter> createState() => _DownloadCenterState();
}

class _DownloadCenterState extends State<DownloadCenter> {
  final String basePath = "/storage/emulated/0/Download/RedTown";
  List<Map<String, dynamic>> jobs = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadJobs());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    final statusDir = Directory("$basePath/status");
    if (!await statusDir.exists()) return;

    final files = statusDir.listSync()
      ..sort((a, b) => b.path.compareTo(a.path));

    final List<Map<String, dynamic>> loaded = [];

    for (final f in files) {
      if (!f.path.endsWith(".json")) continue;
      try {
        final data = jsonDecode(await File(f.path).readAsString());
        loaded.add(data);
      } catch (_) {}
    }

    setState(() {
      jobs = loaded;
    });
  }

  Color _stateColor(String state) {
    switch (state) {
      case "running":
        return Colors.orange;
      case "completed":
        return Colors.green;
      case "failed":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Download Center")),
      body: jobs.isEmpty
          ? const Center(child: Text("No jobs yet"))
          : ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (_, i) {
                final j = jobs[i];
                return Card(
                  child: ListTile(
                    title: Text(j["target"] ?? "Unknown"),
                    subtitle: Text(j["job_id"]),
                    trailing: Text(
                      j["state"],
                      style: TextStyle(
                        color: _stateColor(j["state"]),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
