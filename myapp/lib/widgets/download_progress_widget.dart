import 'package:flutter/material.dart';

class DownloadProgressWidget extends StatefulWidget {
  final Stream<double> progressStream;
  
  const DownloadProgressWidget({
    super.key,
    required this.progressStream,
  });

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() => _progress = progress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Загрузка...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
