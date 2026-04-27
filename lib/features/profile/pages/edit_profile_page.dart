import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../data/models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  final String userName;
  final String avatarUrl;
  final String bio;
  final String gender;
  final DateTime? birthday;

  const EditProfilePage({
    super.key,
    required this.userName,
    required this.avatarUrl,
    required this.bio,
    required this.gender,
    this.birthday,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final RemoteDataSource _remote = RemoteDataSource();
  late TextEditingController _userNameController;
  late TextEditingController _bioController;
  late String _currentAvatarUrl;
  late String _gender;
  DateTime? _birthday;
  File? _localAvatarFile; // 本地选择的头像文件
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.userName);
    _bioController = TextEditingController(text: widget.bio);
    _currentAvatarUrl = widget.avatarUrl;
    _gender = widget.gender;
    _birthday = widget.birthday;
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

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final newUserName = _userNameController.text.trim();
    final newBio = _bioController.text.trim();

    if (newUserName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('用户名不能为空')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? uploadedAvatarUrl;
      if (_localAvatarFile != null) {
        uploadedAvatarUrl = await _remote.uploadImage(_localAvatarFile!.path);
      }

      final updatedUser = await _remote.updateProfile(
        username: newUserName,
        avatarUrl: uploadedAvatarUrl,
        bio: newBio,
        gender: _gender,
        birthday: _formatBirthday(_birthday),
      );

      if (!mounted) return;
      context.read<AuthService>().updateCurrentUser(updatedUser);
      Navigator.pop<UserModel>(context, updatedUser);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败：${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  String? _formatBirthday(DateTime? value) {
    if (value == null) return null;
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
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
                  onTap: _isSaving ? null : _changeAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _localAvatarFile != null
                            ? FileImage(_localAvatarFile!) as ImageProvider
                            : (_currentAvatarUrl.isNotEmpty
                                  ? NetworkImage(_currentAvatarUrl)
                                  : null),
                        child:
                            _currentAvatarUrl.isEmpty &&
                                _localAvatarFile == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
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
                      const SizedBox(height: 24),
                      // 性别
                      _buildLabel('性别'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _gender,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: ['男', '女', '保密'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _gender = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 出生日期
                      _buildLabel('出生日期'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _birthday ?? DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null && picked != _birthday) {
                            setState(() {
                              _birthday = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _birthday == null
                                    ? '选择出生日期'
                                    : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
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
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
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
