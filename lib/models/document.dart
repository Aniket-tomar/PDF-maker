import 'dart:io';

/// Represents a scanned PDF document stored on device.
class Document {
  final String id;
  final String name;
  final String pdfPath;
  final DateTime createdAt;
  final int fileSizeBytes;
  final int pageCount;
  final List<String> imagePaths;

  const Document({
    required this.id,
    required this.name,
    required this.pdfPath,
    required this.createdAt,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.imagePaths,
  });

  /// File size in kilobytes.
  double get fileSizeKb => fileSizeBytes / 1024;

  /// File size in megabytes.
  double get fileSizeMb => fileSizeBytes / (1024 * 1024);

  /// Returns true when the PDF is strictly under the 1 MB target.
  bool get isUnderSizeLimit => fileSizeMb < 1.0;

  /// Human-readable file size string.
  String get fileSizeLabel {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes} B';
    } else if (fileSizeKb < 1024) {
      return '${fileSizeKb.toStringAsFixed(1)} KB';
    } else {
      return '${fileSizeMb.toStringAsFixed(2)} MB';
    }
  }

  /// Returns true if the underlying PDF file still exists on disk.
  bool get exists => File(pdfPath).existsSync();

  Document copyWith({
    String? id,
    String? name,
    String? pdfPath,
    DateTime? createdAt,
    int? fileSizeBytes,
    int? pageCount,
    List<String>? imagePaths,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pdfPath': pdfPath,
        'createdAt': createdAt.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
        'pageCount': pageCount,
        'imagePaths': imagePaths,
      };

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        name: json['name'] as String,
        pdfPath: json['pdfPath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        fileSizeBytes: json['fileSizeBytes'] as int,
        pageCount: json['pageCount'] as int,
        imagePaths: List<String>.from(json['imagePaths'] as List),
      );

  @override
  String toString() =>
      'Document(id: $id, name: $name, size: $fileSizeLabel, pages: $pageCount)';
}
