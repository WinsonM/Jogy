// lib/features/home_wrapper.dart
import 'package:flutter/material.dart';
import '../widgets/glass_nav_bar.dart'; // 引入通用组件
import 'map/pages/map_page.dart';       // 引入三个具体页面
import 'message/pages/message_list_page.dart';
import 'profile/pages/profile_page.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;
  
  // 页面数组
  final List<Widget> _pages = const [
    MapPage(),
    MessageListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}