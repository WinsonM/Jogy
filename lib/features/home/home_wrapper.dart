import 'package:flutter/material.dart';
// 引入通用导航栏组件
import '../../widgets/glass_nav_bar.dart';
// 引入两个主要页面
import '../map/pages/map_page.dart';
import '../message/pages/message_page.dart';
import '../profile/pages/myprofile_page.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [MapPage(), MessagePage(), MyProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 核心：让body延伸到导航栏下面
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
