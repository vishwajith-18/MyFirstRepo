import 'package:flutter/material.dart';
import 'team_list_screen.dart';
import 'match_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.sports_cricket, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'VISH_CRIC',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TeamListScreen())),
              icon: const Icon(Icons.group),
              label: const Text('Manage Teams'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchHistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Match History'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}
