import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const ImageViewer({
    Key? key,
    required this.imageUrl,
    this.title,
  }) : super(key: key);

  static void show(BuildContext context, String imageUrl, {String? title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewer(imageUrl: imageUrl, title: title),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // Если уже увеличено, сбросить
      _transformationController.value = Matrix4.identity();
    } else {
      // Увеличить в 2 раза в месте нажатия
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, color: Colors.white),
            onPressed: () {
              _transformationController.value = Matrix4.identity();
            },
            tooltip: 'Сбросить масштаб',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: _buildImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Проверяем формат изображения (base64 или URL)
    if (widget.imageUrl.startsWith('data:image')) {
      // Base64 изображение
      final base64String = widget.imageUrl.split(',').last;
      try {
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        );
      } catch (e) {
        return _buildErrorWidget();
      }
    } else {
      // URL изображение
      return Image.network(
        widget.imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.imageOff,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Не удалось загрузить изображение',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
