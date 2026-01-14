import 'package:flutter/material.dart';
import 'features/home/home_wrapper.dart'; // 引入主框架

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jogy', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        useMaterial3: true,
        fontFamily: 'PingFang SC',
      ),
      // 指向 HomeWrapper
      home: const HomeWrapper(),
    );
  }
}
