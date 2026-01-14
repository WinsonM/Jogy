import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alice Chen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Digital nomad & coffee enthusiast ☕️',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton('关注', true),
                const SizedBox(width: 16),
                _buildActionButton('私信', false),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  _buildTabItem('喜欢', true),
                  _buildVerticalDivider(),
                  _buildTabItem('收藏', false),
                  _buildVerticalDivider(),
                  _buildTabItem('历史', false),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              padding: const EdgeInsets.all(2),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.grey[200],
                  child: Image.network(
                    'https://picsum.photos/200/200?random=$index',
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.black : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPrimary ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabItem(String text, bool isSelected) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3));
  }
}
