import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;

import '../widgets/grid_bubble_background.dart';
import '../../home/home_wrapper.dart';

/// 认证页面状态
enum AuthMode {
  login, // 登录
  register, // 注册
  verification, // 验证码校验
}

/// 登录/注册页面
///
/// 使用气泡动态背景，支持：
/// - 登录/注册/验证码三种模式切换
/// - 输入框聚焦时背景变慢/变暗
/// - 点击按钮时触发 burst 效果
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // 当前认证模式
  AuthMode _authMode = AuthMode.login;

  // Form keys for each mode
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _verificationFormKey = GlobalKey<FormState>();

  // 登录表单控制器
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // 注册表单控制器
  final _registerNicknameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerVerificationCodeController = TextEditingController();

  // 验证码控制器
  final List<TextEditingController> _verificationControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _verificationFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  bool _isFocused = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 验证码倒计时相关
  int _countdownSeconds = 0;
  Timer? _countdownTimer;
  bool _isSendingCode = false;

  // 邮箱错误信息（用于显示后端返回的"邮箱已被使用"等错误）
  String? _emailError;

  // Focus nodes
  final FocusNode _loginEmailFocus = FocusNode();
  final FocusNode _loginPasswordFocus = FocusNode();
  final FocusNode _registerNicknameFocus = FocusNode();
  final FocusNode _registerEmailFocus = FocusNode();
  final FocusNode _registerPasswordFocus = FocusNode();
  final FocusNode _registerConfirmPasswordFocus = FocusNode();
  final FocusNode _registerVerificationCodeFocus = FocusNode();

  // 保存注册的邮箱用于验证码页面显示
  String _registeredEmail = '';

  @override
  void initState() {
    super.initState();
    // 添加所有 focus 监听
    _loginEmailFocus.addListener(_onFocusChange);
    _loginPasswordFocus.addListener(_onFocusChange);
    _registerNicknameFocus.addListener(_onFocusChange);
    _registerEmailFocus.addListener(_onFocusChange);
    _registerPasswordFocus.addListener(_onFocusChange);
    _registerConfirmPasswordFocus.addListener(_onFocusChange);
    _registerVerificationCodeFocus.addListener(_onFocusChange);
    for (final node in _verificationFocusNodes) {
      node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    final hasFocus =
        _loginEmailFocus.hasFocus ||
        _loginPasswordFocus.hasFocus ||
        _registerNicknameFocus.hasFocus ||
        _registerEmailFocus.hasFocus ||
        _registerPasswordFocus.hasFocus ||
        _registerConfirmPasswordFocus.hasFocus ||
        _registerVerificationCodeFocus.hasFocus ||
        _verificationFocusNodes.any((n) => n.hasFocus);

    if (_isFocused != hasFocus) {
      setState(() => _isFocused = hasFocus);
    }
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNicknameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerVerificationCodeController.dispose();
    _countdownTimer?.cancel();
    for (final controller in _verificationControllers) {
      controller.dispose();
    }

    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _registerNicknameFocus.dispose();
    _registerEmailFocus.dispose();
    _registerPasswordFocus.dispose();
    _registerConfirmPasswordFocus.dispose();
    _registerVerificationCodeFocus.dispose();
    for (final node in _verificationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _switchToRegister() {
    setState(() {
      _authMode = AuthMode.register;
      _emailError = null;
    });
  }

  void _switchToLogin() {
    setState(() {
      _authMode = AuthMode.login;
      _emailError = null;
    });
  }

  void _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // TODO: 实际登录逻辑
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('登录成功！')));

    // 登录成功后导航到主页（并清空登录相关页面栈）
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeWrapper()),
        (route) => false,
      );
    }
  }

  /// 发送验证码到邮箱
  void _sendVerificationCode() async {
    // 先验证邮箱格式
    final email = _registerEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = '请先输入邮箱');
      _registerFormKey.currentState?.validate();
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = '请输入有效的邮箱地址');
      _registerFormKey.currentState?.validate();
      return;
    }

    setState(() {
      _isSendingCode = true;
      _emailError = null;
    });

    try {
      // TODO: 替换为实际的 RemoteDataSource 调用
      // await _remoteDataSource.sendCode(email);
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送，请查收邮箱')),
      );
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('EMAIL_TAKEN') || errorMsg.contains('already exists')) {
        setState(() => _emailError = '该邮箱已被注册');
        _registerFormKey.currentState?.validate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$errorMsg')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  /// 开始60秒倒计时
  void _startCountdown() {
    setState(() => _countdownSeconds = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    // 验证码不能为空
    final code = _registerVerificationCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入验证码')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: 替换为实际的 RemoteDataSource 调用
      // 1. 先注册
      // await _remoteDataSource.register(
      //   _registerNicknameController.text.trim(),
      //   _registerPasswordController.text,
      //   email: _registerEmailController.text.trim(),
      // );
      // 2. 再验证邮箱
      // await _remoteDataSource.verifyCode(
      //   _registerEmailController.text.trim(),
      //   code,
      // );
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注册成功！')),
      );

      // 注册成功后返回登录
      setState(() => _authMode = AuthMode.login);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final errorMsg = e.toString();
      if (errorMsg.contains('EMAIL_TAKEN') || errorMsg.contains('already exists')) {
        setState(() => _emailError = '该邮箱已被注册');
        _registerFormKey.currentState?.validate();
      } else if (errorMsg.contains('USERNAME_TAKEN')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该用户名已被使用')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册失败：$errorMsg')),
        );
      }
    }
  }

  void _handleVerification() async {
    final code = _verificationControllers.map((c) => c.text).join();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入完整的6位验证码')));
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);

    // TODO: 实际验证逻辑
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('注册成功！')));

    // 验证成功后返回登录
    setState(() => _authMode = AuthMode.login);
  }

  void _onVerificationCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      // 自动跳到下一个输入框
      _verificationFocusNodes[index + 1].requestFocus();
    }

    // 如果所有输入框都填满，自动提交
    final code = _verificationControllers.map((c) => c.text).join();
    if (code.length == 6) {
      _handleVerification();
    }
  }

  void _onVerificationKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _verificationControllers[index].text.isEmpty &&
        index > 0) {
      // 删除时跳回上一个输入框
      _verificationFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBubbleBackground(
        isFocused: _isFocused,
        columns: 7,
        baseRadius: 18.0,
        maxScale: 1.8,
        waveDuration: 2.5,
        driftAmplitude: 8.0,
        bubbleColor: const Color(0xFF5B9BD5),
        backgroundColor: const Color(0xFFF5F5F7),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildAuthCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width:
                double.infinity, // Ensure container takes full width constraint
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(160),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withAlpha(100),
                width: 1.5,
              ),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: _buildCurrentForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentForm() {
    switch (_authMode) {
      case AuthMode.login:
        return _buildLoginForm();
      case AuthMode.register:
        return _buildRegisterForm();
      case AuthMode.verification:
        return _buildVerificationForm();
    }
  }

  Widget _buildLoginForm() {
    const primaryColor = Color(0xFF5B9BD5);
    const textColor = Color(0xFF1a1a2e);
    final subtitleColor = Colors.grey.shade600;

    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bubble_chart_rounded, size: 64, color: primaryColor),
          const SizedBox(height: 16),
          const Text(
            'Jogy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录以继续',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: subtitleColor),
          ),
          const SizedBox(height: 32),

          _buildTextField(
            controller: _loginEmailController,
            focusNode: _loginEmailFocus,
            hintText: '邮箱或手机号',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (value) => value?.isEmpty ?? true ? '请输入邮箱或手机号' : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _loginPasswordController,
            focusNode: _loginPasswordFocus,
            hintText: '密码',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return '请输入密码';
              if (value!.length < 6) return '密码至少6位';
              return null;
            },
          ),
          const SizedBox(height: 24),

          _buildActionButton('登录', _isLoading, _handleLogin),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('还没有账号？', style: TextStyle(color: subtitleColor)),
              TextButton(
                onPressed: _switchToRegister,
                child: const Text(
                  '立即注册',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    const primaryColor = Color(0xFF5B9BD5);
    const textColor = Color(0xFF1a1a2e);
    final subtitleColor = Colors.grey.shade600;

    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 返回按钮
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _switchToLogin,
              icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade600),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(height: 8),

          const Icon(Icons.person_add_rounded, size: 64, color: primaryColor),
          const SizedBox(height: 16),
          const Text(
            '创建账号',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '填写信息完成注册',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: subtitleColor),
          ),

          // 昵称
          _buildTextField(
            controller: _registerNicknameController,
            focusNode: _registerNicknameFocus,
            hintText: '昵称',
            prefixIcon: Icons.badge_outlined,
            validator: (value) => value?.isEmpty ?? true ? '请输入昵称' : null,
          ),
          const SizedBox(height: 12),

          // 邮箱
          _buildTextField(
            controller: _registerEmailController,
            focusNode: _registerEmailFocus,
            hintText: '邮箱',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) return '请输入邮箱';
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value!)) {
                return '请输入有效的邮箱地址';
              }
              // 显示后端返回的邮箱错误
              if (_emailError != null) {
                final err = _emailError;
                // 清除错误，避免下次验证时重复显示
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _emailError = null;
                });
                return err;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 验证码输入框 + 获取验证码按钮
          _buildVerificationCodeField(),
          const SizedBox(height: 12),

          // 密码
          _buildTextField(
            controller: _registerPasswordController,
            focusNode: _registerPasswordFocus,
            hintText: '密码',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return '请输入密码';
              if (value!.length < 6) return '密码至少6位';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 确认密码
          _buildTextField(
            controller: _registerConfirmPasswordController,
            focusNode: _registerConfirmPasswordFocus,
            hintText: '确认密码',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.grey.shade500,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return '请确认密码';
              if (value != _registerPasswordController.text) return '两次密码不一致';
              return null;
            },
          ),
          const SizedBox(height: 24),

          _buildActionButton('注册', _isLoading, _handleRegister),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('已有账号？', style: TextStyle(color: subtitleColor)),
              TextButton(
                onPressed: _switchToLogin,
                child: const Text(
                  '立即登录',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationForm() {
    const primaryColor = Color(0xFF5B9BD5);
    const textColor = Color(0xFF1a1a2e);
    final subtitleColor = Colors.grey.shade600;

    return Form(
      key: _verificationFormKey,
      child: Column(
        key: const ValueKey('verification'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 返回按钮
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => setState(() => _authMode = AuthMode.register),
              icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade600),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(height: 8),

          const Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            '验证邮箱',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '验证码已发送至 $_registeredEmail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
          const SizedBox(height: 32),

          // 6位验证码输入
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => _buildVerificationBox(index)),
          ),
          const SizedBox(height: 24),

          _buildActionButton('确认', _isLoading, _handleVerification),
          const SizedBox(height: 16),

          // 重新发送
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('没有收到？', style: TextStyle(color: subtitleColor)),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('验证码已重新发送')));
                },
                child: const Text(
                  '重新发送',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 注册表单中的验证码输入框 + 获取验证码按钮
  Widget _buildVerificationCodeField() {
    const primaryColor = Color(0xFF5B9BD5);
    final bool canSend = _countdownSeconds == 0 && !_isSendingCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 验证码输入框
        Expanded(
          child: _buildTextField(
            controller: _registerVerificationCodeController,
            focusNode: _registerVerificationCodeFocus,
            hintText: '验证码',
            prefixIcon: Icons.verified_user_outlined,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty ?? true) return '请输入验证码';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        // 获取验证码按钮
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: canSend ? _sendVerificationCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSend ? primaryColor : Colors.grey.shade300,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _isSendingCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _countdownSeconds > 0
                        ? '${_countdownSeconds}s'
                        : '获取验证码',
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBox(int index) {
    const primaryColor = Color(0xFF5B9BD5);
    return SizedBox(
      width: 45,
      height: 55,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onVerificationKeyPressed(index, event),
        child: TextFormField(
          controller: _verificationControllers[index],
          focusNode: _verificationFocusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            color: Color(0xFF1a1a2e),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                EdgeInsets.zero, // Remove default padding to center vertically
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => _onVerificationCodeChanged(index, value),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    const primaryColor = Color(0xFF5B9BD5);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFF1a1a2e)),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    bool isLoading,
    VoidCallback onPressed,
  ) {
    const primaryColor = Color(0xFF5B9BD5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryColor.withAlpha(128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
