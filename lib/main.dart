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

/* ================= HOME ================= */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = TextEditingController();
  String? folder;
  String status = "Select folder, then RIP ME";

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("folder_path");
    if (saved != null) {
      setState(() {
        folder = saved;
        status = "Folder: $saved";
      });
    }
  }

  Future<void> pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("folder_path", path);

    setState(() {
      folder = path;
      status = "Folder selected:\n$path";
    });
  }

  Future<void> ripMe() async {
    if (folder == null || controller.text.isEmpty) return;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final jobId = "job_$ts";
    final jobFile = File("$folder/$jobId.json");

    await jobFile.writeAsString(jsonEncode({
      "job_id": jobId,
      "target": controller.text.trim(),
      "created_at": DateTime.now().toIso8601String()
    }));

    setState(() {
      status = "Job created: $jobId";
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RedTown"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadCenter()),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          ElevatedButton(
            onPressed: pickFolder,
            child: const Text("Select RedTown Folder"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Subreddit or Username (e.g. r/pics)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: ripMe,
            child: const Text("RIP ME"),
          ),
          const SizedBox(height: 20),
          Text(status),
        ]),
      ),
    );
  }
}

/* =============== DOWNLOAD CENTER =============== */

class DownloadCenter extends StatefulWidget {
  const DownloadCenter({super.key});

  @override
  State<DownloadCenter> createState() => _DownloadCenterState();
}

class _DownloadCenterState extends State<DownloadCenter> {
  List<Map<String, dynamic>> jobs = [];
  Timer? timer;
  String? folder;

  @override
  void initState() {
    super.initState();
    _loadFolderAndJobs();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadJobs());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadFolderAndJobs() async {
    final prefs = await SharedPreferences.getInstance();
    folder = prefs.getString("folder_path");
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    if (folder == null) return;

    final List<Map<String, dynamic>> list = [];
    final jobDir = Directory(folder!);
    final statusDir = Directory("${folder!}/status");

    if (await jobDir.exists()) {
      for (final f in jobDir.listSync()) {
        if (f.path.endsWith(".json") && !f.path.contains("/status/")) {
          try {
            final j = jsonDecode(await File(f.path).readAsString());
            j["state"] = "queued";
            list.add(j);
          } catch (_) {}
        }
      }
    }

    if (await statusDir.exists()) {
      for (final f in statusDir.listSync()) {
        try {
          final j = jsonDecode(await File(f.path).readAsString());
          list.removeWhere((e) => e["job_id"] == j["job_id"]);
          list.add(j);
        } catch (_) {}
      }
    }

    setState(() {
      jobs = list;
    });
  }

  Color stateColor(String s) {
    switch (s) {
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
          : ListView(
              children: jobs.map((j) => Card(
                child: ListTile(
                  title: Text(j["target"] ?? ""),
                  subtitle: Text(j["job_id"] ?? ""),
                  trailing: Text(
                    j["state"] ?? "",
                    style: TextStyle(
                      color: stateColor(j["state"] ?? ""),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )).toList(),
            ),
    );
  }
}
