import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Maximum output file size in bytes (1 MB).
const int kMaxPdfSizeBytes = 1024 * 1024; // 1 MB

/// Target JPEG quality levels tried in descending order during compression.
const List<int> _kQualitySteps = [85, 70, 55, 40, 28, 18, 10];

/// Maximum long edge of an image (pixels) when preparing pages.
const int _kMaxImageDimension = 1600;

/// Result of a single image-compression pass.
class ProcessedImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;

  const ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
  });
}

/// Service responsible for preparing images before they are embedded in a PDF.
///
/// Responsibilities:
/// - Resize images so the long edge does not exceed [_kMaxImageDimension].
/// - Convert to grayscale when the caller requests document-style output.
/// - JPEG-compress at progressively lower quality until the total compressed
///   size of all pages is within the per-PDF budget.
class ImageProcessor {
  const ImageProcessor();

  /// Reads [imagePath] from disk, applies optional grayscale conversion and
  /// resizing, then returns a [ProcessedImage] with the compressed JPEG bytes.
  ///
  /// [targetQuality] – initial JPEG quality (0–100).
  /// [grayscale]     – when true the image is converted to grayscale first,
  ///                   which significantly reduces file size.
  Future<ProcessedImage> processImage(
    String imagePath, {
    int targetQuality = 85,
    bool grayscale = true,
  }) async {
    final file = File(imagePath);
    final rawBytes = await file.readAsBytes();

    img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw ImageProcessingException(
          'Unable to decode image at path: $imagePath');
    }

    // Correct EXIF orientation before any other processing.
    decoded = img.bakeOrientation(decoded);

    // Resize so that the longest edge is at most _kMaxImageDimension pixels.
    decoded = _resize(decoded);

    // Optional grayscale conversion – good for text documents.
    if (grayscale) {
      decoded = img.grayscale(decoded);
    }

    final quality = targetQuality.clamp(1, 100);
    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );

    return ProcessedImage(
      bytes: jpegBytes,
      width: decoded.width,
      height: decoded.height,
      quality: quality,
    );
  }

  /// Compresses a list of images so that their combined JPEG size is within
  /// [budgetBytes].
  ///
  /// The method tries each quality level in [_kQualitySteps] until the total
  /// compressed size fits the budget, falling back to the lowest quality if
  /// necessary.
  ///
  /// Returns a list of [ProcessedImage] objects, one per input path, in the
  /// same order.
  Future<List<ProcessedImage>> compressImagesToFitBudget(
    List<String> imagePaths, {
    int budgetBytes = kMaxPdfSizeBytes,
    bool grayscale = true,
  }) async {
    // Account for PDF overhead (~40 KB for structure/fonts).
    const int kPdfOverheadBytes = 40 * 1024;
    final imageBudget = budgetBytes - kPdfOverheadBytes;

    for (final quality in _kQualitySteps) {
      final results = <ProcessedImage>[];
      int totalSize = 0;

      for (final path in imagePaths) {
        final processed = await processImage(
          path,
          targetQuality: quality,
          grayscale: grayscale,
        );
        results.add(processed);
        totalSize += processed.bytes.length;
      }

      if (totalSize <= imageBudget) {
        return results;
      }
    }

    // Last resort: use the lowest quality step.
    return Future.wait(
      imagePaths.map(
        (path) => processImage(
          path,
          targetQuality: _kQualitySteps.last,
          grayscale: grayscale,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  img.Image _resize(img.Image source) {
    final w = source.width;
    final h = source.height;

    if (w <= _kMaxImageDimension && h <= _kMaxImageDimension) {
      return source;
    }

    if (w >= h) {
      return img.copyResize(source, width: _kMaxImageDimension);
    } else {
      return img.copyResize(source, height: _kMaxImageDimension);
    }
  }
}

/// Thrown when an image cannot be decoded or processed.
class ImageProcessingException implements Exception {
  final String message;
  const ImageProcessingException(this.message);

  @override
  String toString() => 'ImageProcessingException: $message';
}
