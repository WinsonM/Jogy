import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../profile/profile_navigation.dart';
import '../../detail/pages/detail_page.dart';
import '../services/jogy_qr_codec.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _handleScanResult(String rawValue) async {
    final code = rawValue.trim();
    final localTarget = JogyQrCodec.parse(code);
    if (localTarget != null) {
      await _openTarget(localTarget);
      return;
    }

    // 非 jogy:// 协议的码，直接提示
    if (!code.startsWith('jogy://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法识别的二维码: $code'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final result = await _remoteDataSource.resolveQR(code);
      if (!mounted) return;

      final target = JogyQrCodec.fromResolveResponse(result);
      if (target == null) {
        _showError('二维码解析失败');
        return;
      }

      await _openTarget(target);
    } catch (e) {
      if (mounted) {
        _showError('扫描失败: $e');
      }
    }
  }

  Future<void> _pickImageAndScan() async {
    if (_isProcessing) return;

    if (kIsWeb) {
      _showError('当前平台不支持从照片识别二维码');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final imageBytes = await image.readAsBytes();
      if (!mounted) return;

      final confirmed = await _showImageConfirmDialog(imageBytes);
      if (!mounted) return;

      if (confirmed != true) {
        setState(() => _isProcessing = false);
        return;
      }

      final capture = await _controller.analyzeImage(image.path);
      if (!mounted) return;

      final rawValue = _firstRawValue(capture);
      if (rawValue == null) {
        _showError('未识别到二维码');
        return;
      }

      await _handleScanResult(rawValue);
    } on UnsupportedError {
      _showError('当前设备不支持从照片识别二维码');
    } catch (e) {
      _showError('照片识别失败: $e');
    }
  }

  String? _firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return null;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) return rawValue;
    }

    return null;
  }

  Future<bool?> _showImageConfirmDialog(Uint8List imageBytes) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '确认扫描这张图片？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 360,
                      maxWidth: 320,
                    ),
                    child: Image.memory(imageBytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('确定'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3FAAF0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTarget(JogyQrTarget target) async {
    if (!mounted) return;

    switch (target.targetType) {
      case JogyQrCodec.userProfileType:
        await openUserProfile(context, userId: target.targetId, replace: true);
        break;
      case JogyQrCodec.postType:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(postId: target.targetId),
          ),
        );
        break;
      default:
        _showError('不支持的二维码类型: ${target.targetType}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '从相册选择',
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            onPressed: _isProcessing ? null : _pickImageAndScan,
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.white);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isProcessing = true);
                  _handleScanResult(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // 扫描框 overlay
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),
          // Loading 指示器
          if (_isProcessing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // 底部提示文字
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              _isProcessing ? '正在识别...' : '将二维码/条码放入框内，或从相册选择图片',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4.0,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            top: alignment.y == -1.0
                ? const BorderSide(color: Colors.blue, width: 4)
                : BorderSide.none,
            bottom: alignment.y == 1.0
                ? const BorderSide(color: Colors.blue, width: 4)
                : BorderSide.none,
            left: alignment.x == -1.0
                ? const BorderSide(color: Colors.blue, width: 4)
                : BorderSide.none,
            right: alignment.x == 1.0
                ? const BorderSide(color: Colors.blue, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
