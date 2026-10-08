import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'image_processor.dart';

/// Hard limit enforced on every generated PDF (1 MB).
const int kPdfSizeLimitBytes = 1024 * 1024;

/// PDF page format used for scanned documents (A4 portrait).
const PdfPageFormat _kPageFormat = PdfPageFormat.a4;

/// Result returned by [PdfGenerator.generatePdf].
class PdfGenerationResult {
  final String outputPath;
  final int fileSizeBytes;
  final int pageCount;
  final bool withinSizeLimit;

  const PdfGenerationResult({
    required this.outputPath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.withinSizeLimit,
  });

  double get fileSizeMb => fileSizeBytes / (1024 * 1024);
}

/// Generates an optimized PDF from a list of image paths.
///
/// The generated PDF is guaranteed to be strictly under [kPdfSizeLimitBytes]
/// (1 MB) by progressively compressing the embedded images until the budget
/// is met. If even the lowest quality setting produces a file that is ≥ 1 MB
/// the file is still written but [PdfGenerationResult.withinSizeLimit] will be
/// `false` so the caller can warn the user.
class PdfGenerator {
  final ImageProcessor _imageProcessor;

  /// Optional override for the output directory (useful in tests).
  final Directory? _outputDirectory;

  PdfGenerator({ImageProcessor? imageProcessor, Directory? outputDirectory})
      : _imageProcessor = imageProcessor ?? const ImageProcessor(),
        _outputDirectory = outputDirectory;

  /// Creates a PDF from [imagePaths] and saves it to the app documents
  /// directory with the given [fileName] (without extension).
  ///
  /// [grayscale] – converts images to grayscale before embedding, which
  /// dramatically reduces file size for text-heavy documents.
  Future<PdfGenerationResult> generatePdf({
    required List<String> imagePaths,
    required String fileName,
    bool grayscale = true,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('imagePaths must not be empty');
    }

    // Compress images to fit within the 1 MB budget.
    final processedImages = await _imageProcessor.compressImagesToFitBudget(
      imagePaths,
      budgetBytes: kPdfSizeLimitBytes,
      grayscale: grayscale,
    );

    // Build the PDF document.
    Uint8List pdfBytes = await _buildPdf(processedImages);

    // If the PDF still exceeds the limit (rare edge case with very many pages),
    // try a second pass at the minimum quality.
    if (pdfBytes.length > kPdfSizeLimitBytes) {
      final recompressed = await _imageProcessor.compressImagesToFitBudget(
        imagePaths,
        budgetBytes: kPdfSizeLimitBytes ~/ 2,
        grayscale: true,
      );
      pdfBytes = await _buildPdf(recompressed);
    }

    // Write to disk.
    final outputPath = await _writePdf(pdfBytes, fileName);
    final fileSize = File(outputPath).lengthSync();

    return PdfGenerationResult(
      outputPath: outputPath,
      fileSizeBytes: fileSize,
      pageCount: imagePaths.length,
      withinSizeLimit: fileSize < kPdfSizeLimitBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Uint8List> _buildPdf(List<ProcessedImage> images) async {
    final doc = pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
    );

    for (final processedImg in images) {
      final pdfImage = pw.MemoryImage(processedImg.bytes);

      doc.addPage(
        pw.Page(
          pageFormat: _kPageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(pdfImage),
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  Future<String> _writePdf(Uint8List bytes, String fileName) async {
    final Directory baseDir;
    if (_outputDirectory != null) {
      baseDir = _outputDirectory!;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(p.join(appDir.path, 'tinyscan'));
    }

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    final sanitized = _sanitizeFileName(fileName);
    final outputPath = p.join(baseDir.path, '$sanitized.pdf');
    await File(outputPath).writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  String _sanitizeFileName(String name) {
    // Replace characters that are invalid in file names.
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  }
}

/// Thrown when PDF generation encounters an unrecoverable error.
class PdfGenerationException implements Exception {
  final String message;
  const PdfGenerationException(this.message);

  @override
  String toString() => 'PdfGenerationException: $message';
}
