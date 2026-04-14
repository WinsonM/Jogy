import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../profile/pages/profile_page.dart';
import '../../detail/pages/detail_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  bool _isProcessing = false;

  Future<void> _handleScanResult(String rawValue) async {
    // 非 jogy:// 协议的码，直接提示
    if (!rawValue.startsWith('jogy://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法识别的二维码: $rawValue'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final result = await _remoteDataSource.resolveQR(rawValue);
      if (!mounted) return;

      final targetType = result['target_type'] as String?;
      final targetId = result['target_id'] as String?;

      if (targetType == null || targetId == null) {
        _showError('二维码解析失败');
        return;
      }

      switch (targetType) {
        case 'user_profile':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(userId: targetId),
            ),
          );
          break;
        case 'post':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPage(postId: targetId),
            ),
          );
          break;
        default:
          _showError('不支持的二维码类型: $targetType');
      }
    } catch (e) {
      if (mounted) {
        _showError('扫描失败: $e');
      }
    }
  }

  void _showError(String message) {
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
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
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
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // 底部提示文字
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              _isProcessing ? '正在识别...' : '将二维码/条码放入框内，即可自动扫描',
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
