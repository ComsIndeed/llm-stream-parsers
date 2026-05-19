import 'package:flutter/material.dart';
import 'pages/interactive_demo.dart';
import 'pages/readme_demos.dart';

class Homepage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const Homepage({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.bolt), text: 'Interactive Playground'),
                    Tab(icon: Icon(Icons.menu_book), text: 'Readme Use Cases'),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<bool>(widget.isDarkMode),
                onPressed: widget.onThemeToggle,
                icon: Icon(
                  widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: 'Toggle theme mode',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [InteractiveDemoPage(), ReadmeDemosPage()],
            ),
          ),
        ],
      ),
    );
  }
}
