import 'package:equatable/equatable.dart';

class UpdateInfo extends Equatable {
  final String version;
  final String title;
  final String message;
  final String downloadUrl;
  final String? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.title,
    required this.message,
    required this.downloadUrl,
    this.publishedAt,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: (json['version'] ?? '').toString(),
      title: (json['title'] ?? 'Доступно обновление').toString(),
      message: (json['message'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      publishedAt: json['publishedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'title': title,
      'message': message,
      'downloadUrl': downloadUrl,
      if (publishedAt != null) 'publishedAt': publishedAt,
    };
  }

  bool get hasDownloadLink => downloadUrl.isNotEmpty;

  @override
  List<Object?> get props => [version, title, message, downloadUrl, publishedAt];
}
