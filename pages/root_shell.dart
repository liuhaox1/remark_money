import 'package:flutter/material.dart';

import '../widgets/quick_add_sheet.dart';
import 'home_page.dart';
import 'stats_page.dart';
import 'discover_page.dart';
import 'profile_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    StatsPage(),
    DiscoverPage(),
    ProfilePage(),
  ];

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }

  void _handleDestination(int value) {
    if (value == 2) {
      _openQuickAddSheet();
      return;
    }
    final mappedIndex = value > 2 ? value - 1 : value;
    setState(() => _index = mappedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final buildStart = DateTime.now();
    final scaffold = Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index >= 2 ? _index + 1 : _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '记一笔',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
        onDestinationSelected: _handleDestination,
      ),
    );
    debugPrint(
        'RootShell build: ${DateTime.now().difference(buildStart).inMilliseconds}ms');
    return scaffold;
  }
}
