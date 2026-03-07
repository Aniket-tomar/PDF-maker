import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

const String _kPrefsKey = 'tinyscan_documents';

/// Persists and retrieves [Document] metadata using [SharedPreferences].
///
/// The PDF files themselves live on the file system under the app documents
/// directory; this service only manages the metadata list.
class DocumentStorage {
  DocumentStorage._();

  static final DocumentStorage instance = DocumentStorage._();

  /// Loads all documents from persistent storage.
  ///
  /// Documents whose underlying PDF file no longer exists on disk are silently
  /// filtered out to keep the list clean.
  Future<List<Document>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_kPrefsKey) ?? [];

    final documents = <Document>[];
    for (final json in jsonList) {
      try {
        final doc = Document.fromJson(jsonDecode(json) as Map<String, dynamic>);
        if (doc.exists) {
          documents.add(doc);
        }
      } catch (_) {
        // Skip malformed entries silently.
      }
    }

    // Return newest first.
    documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return documents;
  }

  /// Persists [document] to storage.
  ///
  /// If a document with the same [Document.id] already exists it is replaced.
  Future<void> saveDocument(Document document) async {
    final existing = await loadDocuments();
    final updated = [
      document,
      ...existing.where((d) => d.id != document.id),
    ];
    await _persist(updated);
  }

  /// Removes [document] from storage and deletes its PDF file from disk.
  Future<void> deleteDocument(Document document) async {
    final existing = await loadDocuments();
    final updated = existing.where((d) => d.id != document.id).toList();
    await _persist(updated);

    // Delete the PDF file.
    final pdfFile = File(document.pdfPath);
    if (pdfFile.existsSync()) {
      await pdfFile.delete();
    }

    // Delete cached page images if any.
    for (final imgPath in document.imagePaths) {
      final imgFile = File(imgPath);
      if (imgFile.existsSync()) {
        await imgFile.delete();
      }
    }
  }

  /// Returns the directory where TinyScan stores its PDFs.
  Future<Directory> getPdfDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'tinyscan'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persist(List<Document> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = documents.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_kPrefsKey, jsonList);
  }
}
