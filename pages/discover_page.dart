import 'package:flutter/material.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore, size: 80, color: Colors.teal),
            SizedBox(height: 12),
            Text(
              '发现更多理财灵感，敬请期待',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
