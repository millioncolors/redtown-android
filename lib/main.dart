import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _status = 'Enter subreddit and tap RIP ME';

  Future<bool> _ensureAllFilesAccess() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final uri = Uri.parse(
      'android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION'
      '?package=com.redtown.app',
    );

    await launchUrl(uri);

    setState(() {
      _status =
          'Enable "All files access" for RedTown, then return and tap RIP ME again';
    });

    return false;
  }

  Future<void> _ripMe() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _status = 'Please enter a subreddit or username');
      return;
    }

    final ok = await _ensureAllFilesAccess();
    if (!ok) return;

    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

    final job = {
      "job_id": jobId,
      "target": input,
      "media": ["images", "videos", "gifs", "albums"],
      "listing": ["new", "hot", "top", "rising", "controversial"],
      "time_range": "all",
      "created_at": DateTime.now().toIso8601String(),
      "state": "queued"
    };

    final dir = Directory('/storage/emulated/0/RedTown/jobs');
    await dir.create(recursive: true);

    final file = File('${dir.path}/$jobId.json');
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
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Subreddit or Username (e.g. r/pics)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _ripMe,
                child: const Text('RIP ME', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
