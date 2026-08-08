// ไฟล์: lib/screens/common/full_screen_image.dart

import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImage extends StatefulWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  // ✅ Default to White background to fix "Black Screen" issue
  bool _isDarkBackground = false;

  void _toggleBackground() {
    setState(() {
      _isDarkBackground = !_isDarkBackground;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on background
    final Color bgColor = _isDarkBackground ? Colors.black : Colors.white;
    final Color textColor = _isDarkBackground ? Colors.white : Colors.black;
    final Color iconColor = _isDarkBackground ? Colors.white : Colors.black;
    final Color iconBgColor =
        _isDarkBackground ? Colors.black45 : Colors.grey.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.close, color: iconColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isDarkBackground ? Icons.light_mode : Icons.dark_mode,
                color: iconColor,
              ),
              tooltip: 'สลับสีพื้นหลัง',
              onPressed: _toggleBackground,
            ),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          panEnabled: true,
          clipBehavior: Clip.none,
          minScale: 0.1,
          maxScale: 5.0,
          child: Center(
            child: widget.imageUrl.startsWith('http://') || widget.imageUrl.startsWith('https://')
                ? Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: textColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'กำลังโหลดรูปภาพ... ${(loadingProgress.expectedTotalBytes != null ? "${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toStringAsFixed(0)}%" : "")}',
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(textColor, error),
                  )
                : Image.file(
                    File(widget.imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildErrorWidget(textColor, error),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color textColor, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.redAccent, size: 64),
          const SizedBox(height: 16),
          Text(
            'ไม่สามารถโหลดรูปภาพได้',
            style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
