// lib/main.dart
import 'package:flutter/material.dart';
import 'features/home_wrapper.dart'; // 引入主框架

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jogy App',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        primarySwatch: Colors.blue,
      ),
      home: const HomeWrapper(), // 这里指向一个主框架页面
    );
  }
}