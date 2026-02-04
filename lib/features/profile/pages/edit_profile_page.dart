import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class EditProfilePage extends StatefulWidget {
  final String userName;
  final String avatarUrl;
  final String bio;

  const EditProfilePage({
    super.key,
    required this.userName,
    required this.avatarUrl,
    required this.bio,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _userNameController;
  late TextEditingController _bioController;
  late String _currentAvatarUrl;
  File? _localAvatarFile; // 本地选择的头像文件
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.userName);
    _bioController = TextEditingController(text: widget.bio);
    _currentAvatarUrl = widget.avatarUrl;
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null) {
        final sourceFile = File(image.path);
        if (!await sourceFile.exists()) {
          throw Exception('Selected image file not found.');
        }

        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Lock 1:1
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          cropStyle: CropStyle.circle,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '裁剪头像',
              toolbarColor: const Color(0xFF3FAAF0),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              showCropGrid: false,
              cropFrameColor: Colors.white,
              cropGridColor: Colors.transparent,
              dimmedLayerColor: Colors.black.withOpacity(0.7),
              cropFrameStrokeWidth: 2,
              hideBottomControls: true,
            ),
            IOSUiSettings(
              title: '裁剪头像',
              doneButtonTitle: '保存',
              cancelButtonTitle: '取消',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true,
              rotateButtonsHidden: true,
              resetButtonHidden: true,
              showCancelConfirmationDialog: false,
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          setState(() {
            _localAvatarFile = File(croppedFile.path);
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选取照片失败: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  void _saveProfile() {
    final newUserName = _userNameController.text.trim();
    final newBio = _bioController.text.trim();

    if (newUserName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('用户名不能为空')));
      return;
    }

    // 返回编辑后的数据
    Navigator.pop(context, {
      'userName': newUserName,
      'avatarUrl': _currentAvatarUrl,
      'bio': newBio,
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 主要内容
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: topPadding + 60),
                // 头像编辑区域
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _localAvatarFile != null
                            ? FileImage(_localAvatarFile!) as ImageProvider
                            : NetworkImage(_currentAvatarUrl),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3FAAF0),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击更换头像',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                // 表单区域
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 用户名
                      _buildLabel('用户名'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _userNameController,
                        hintText: '请输入用户名',
                        maxLength: 20,
                      ),
                      const SizedBox(height: 24),
                      // 个性签名
                      _buildLabel('个性签名'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _bioController,
                        hintText: '请输入个性签名',
                        maxLength: 100,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 顶部导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(top: topPadding),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '编辑资料',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 保存按钮
                  TextButton(
                    onPressed: _saveProfile,
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3FAAF0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3FAAF0), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        counterStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}
