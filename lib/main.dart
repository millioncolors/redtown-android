import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class JobInfo {
  final String jobId;
  final String target;
  final String state;
  final Map<String, dynamic> stats;
  final String? error;

  JobInfo({
    required this.jobId,
    required this.target,
    required this.state,
    required this.stats,
    this.error,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  String? baseDir;
  final TextEditingController controller = TextEditingController();
  List<JobInfo> jobs = [];
  Timer? poller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    poller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && baseDir != null) {
      startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RedTown")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: pickFolder,
              child: Text(
                baseDir == null
                    ? "Choose RedTown Folder"
                    : "Folder: ${p.basename(baseDir!)}",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Subreddit",
                hintText: "e.g. r/pics",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: baseDir == null ? null : createJob,
                child: const Text("Rip Me"),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Download Center",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(child: buildJobList()),
          ],
        ),
      ),
    );
  }

  Widget buildJobList() {
    if (jobs.isEmpty) {
      return const Center(child: Text("No jobs yet"));
    }

    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];

        Color color;
        switch (job.state) {
          case "running":
            color = Colors.orange;
            break;
          case "completed":
            color = Colors.green;
            break;
          case "failed":
            color = Colors.red;
            break;
          default:
            color = Colors.grey;
        }

        return Card(
          child: ListTile(
            leading: Icon(Icons.circle, color: color, size: 12),
            title: Text(job.target),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.state),
                if (job.state == "failed" && job.error != null)
                  Text(
                    job.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
            trailing: job.stats.isNotEmpty
                ? Text("${job.stats["files_downloaded"] ?? 0} files")
                : null,
          ),
        );
      },
    );
  }

  Future<void> pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    setState(() {
      baseDir = dir;
    });

    startPolling();
  }

  Future<void> createJob() async {
    final target = controller.text.trim();
    if (target.isEmpty || baseDir == null) return;

    final jobId = "job_${DateTime.now().millisecondsSinceEpoch}";
    final jobFile = File(p.join(baseDir!, "$jobId.json"));

    await jobFile.writeAsString(jsonEncode({
      "job_id": jobId,
      "target": target,
      "created_at": DateTime.now().toIso8601String(),
    }));

    controller.clear();

    refreshJobs();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Job created: $jobId")),
    );
  }

  void startPolling() {
    poller?.cancel();
    refreshJobs();
    poller = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshJobs(),
    );
  }

  Future<void> refreshJobs() async {
    if (baseDir == null) return;

    final jobsDir = Directory(baseDir!);
    final statusDir = Directory(p.join(baseDir!, "status"));

    if (!await jobsDir.exists()) return;

    final jobFiles = jobsDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith("job_"))
        .toList();

    List<JobInfo> loaded = [];

    for (final jobFile in jobFiles) {
      final jobData = jsonDecode(await jobFile.readAsString());
      final jobId = jobData["job_id"];
      final target = jobData["target"];

      final statusFile = File(p.join(statusDir.path, "$jobId.json"));

      if (await statusFile.exists()) {
        final statusData = jsonDecode(await statusFile.readAsString());
        loaded.add(JobInfo(
          jobId: jobId,
          target: target,
          state: statusData["state"],
          stats: statusData["stats"] ?? {},
          error: statusData["error"],
        ));
      } else {
        loaded.add(JobInfo(
          jobId: jobId,
          target: target,
          state: "queued",
          stats: const {},
        ));
      }
    }

    loaded.sort((a, b) => b.jobId.compareTo(a.jobId));

    setState(() {
      jobs = loaded;
    });
  }
}
