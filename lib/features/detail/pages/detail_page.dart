import 'package:flutter/material.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('详情页')),
      body: const Center(child: Text('这里是点击气泡后的详情页内容')),
    );
  }
}
