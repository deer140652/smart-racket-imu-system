import 'package:flutter/material.dart';

import 'pose_page.dart';
import 'setting_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.accessibility)),
                // Tab(icon: Icon(Icons.monitor_heart)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
            title: Text(widget.title),
          ),
          body: TabBarView(children: [PosePage(), SettingPage()]),
        ),
      ),
    );
  }
}
