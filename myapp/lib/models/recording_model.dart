import 'dart:convert';

class Recording {
  final String id;
  String title;
  final String duration;
  final String? path;

  // AI-generated content
  String? summary;
  String? keyPoints;
  String? testQuestions;
  String? transcription;

  Recording({
    required this.id,
    required this.title,
    required this.duration,
    this.path,
    this.summary,
    this.keyPoints,
    this.testQuestions,
    this.transcription,
  });

  // To save the object as a JSON string
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'duration': duration,
        'path': path,
        'summary': summary,
        'keyPoints': keyPoints,
        'testQuestions': testQuestions,
        'transcription': transcription,
      };

  // To create an object from a JSON string
  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'],
        title: json['title'],
        duration: json['duration'],
        path: json['path'],
        summary: json['summary'],
        keyPoints: json['keyPoints'],
        testQuestions: json['testQuestions'],
        transcription: json['transcription'],
      );
}
