enum ProcessingStatus {
  pending,
  uploading,
  transcribing,
  summarizing,
  completed,
  failed,
}

enum SermonContentType { uploadedAudio, recordedAudio, externalLink, article }

class SermonEntity {
  final String id;
  final String title;
  final String preacherName;
  final String? preacherId;
  final String theme;
  final String bibleText;
  final String description;
  final String congregationId;
  final String audioUrl;
  final String? audioPath;
  final SermonContentType contentType;
  final String? externalUrl;
  final String? externalPlatform;
  final String? articleContent;
  final int durationInSeconds;
  final String? transcription;
  final String? summary;
  final List<String> keyPoints;
  final String? keyVerse;
  final ProcessingStatus processingStatus;
  final String? processingError;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime sermonDate;
  final bool isPublished;

  SermonEntity({
    required this.id,
    required this.title,
    required this.preacherName,
    this.preacherId,
    required this.theme,
    required this.bibleText,
    required this.description,
    required this.congregationId,
    required this.audioUrl,
    this.audioPath,
    this.contentType = SermonContentType.uploadedAudio,
    this.externalUrl,
    this.externalPlatform,
    this.articleContent,
    required this.durationInSeconds,
    this.transcription,
    this.summary,
    this.keyPoints = const [],
    this.keyVerse,
    required this.processingStatus,
    this.processingError,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.sermonDate,
    required this.isPublished,
  });

  bool get isProcessing =>
      processingStatus != ProcessingStatus.completed &&
      processingStatus != ProcessingStatus.failed;

  bool get isExternalContent => contentType == SermonContentType.externalLink;
}
