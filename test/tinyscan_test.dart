import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:tinyscan/models/document.dart';
import 'package:tinyscan/services/image_processor.dart';
import 'package:tinyscan/services/pdf_generator.dart';

// ---------------------------------------------------------------------------
// Helper: create a small synthetic JPEG on disk for tests.
// ---------------------------------------------------------------------------

File _createTestJpeg(String path, {int width = 200, int height = 280}) {
  final image = img.Image(width: width, height: height);
  // Fill with a simple gradient so compression is non-trivial.
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 255 ~/ width), (y * 255 ~/ height), 128);
    }
  }
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
  final file = File(path)..writeAsBytesSync(bytes);
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tinyscan_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Document model tests
  // -------------------------------------------------------------------------
  group('Document model', () {
    test('fileSizeMb is computed correctly', () {
      final doc = _makeDocument(fileSizeBytes: 512 * 1024); // 0.5 MB
      expect(doc.fileSizeMb, closeTo(0.5, 0.001));
    });

    test('isUnderSizeLimit is true for <1 MB', () {
      final doc = _makeDocument(fileSizeBytes: 1024 * 1024 - 1);
      expect(doc.isUnderSizeLimit, isTrue);
    });

    test('isUnderSizeLimit is false for exactly 1 MB', () {
      final doc = _makeDocument(fileSizeBytes: 1024 * 1024);
      expect(doc.isUnderSizeLimit, isFalse);
    });

    test('isUnderSizeLimit is false for >1 MB', () {
      final doc = _makeDocument(fileSizeBytes: 1024 * 1024 + 1);
      expect(doc.isUnderSizeLimit, isFalse);
    });

    test('fileSizeLabel uses KB for values < 1 MB', () {
      final doc = _makeDocument(fileSizeBytes: 512 * 1024);
      expect(doc.fileSizeLabel, contains('KB'));
    });

    test('fileSizeLabel uses MB for values >= 1 MB', () {
      final doc = _makeDocument(fileSizeBytes: 1024 * 1024 + 1);
      expect(doc.fileSizeLabel, contains('MB'));
    });

    test('toJson / fromJson round-trips correctly', () {
      final original = _makeDocument(fileSizeBytes: 800 * 1024);
      final roundTripped = Document.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.fileSizeBytes, original.fileSizeBytes);
      expect(roundTripped.pageCount, original.pageCount);
    });

    test('copyWith overrides only specified fields', () {
      final original = _makeDocument(fileSizeBytes: 100);
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.id, original.id);
      expect(copy.fileSizeBytes, original.fileSizeBytes);
    });
  });

  // -------------------------------------------------------------------------
  // ImageProcessor tests
  // -------------------------------------------------------------------------
  group('ImageProcessor', () {
    test('processImage returns non-empty JPEG bytes', () async {
      final jpeg = _createTestJpeg(p.join(tempDir.path, 'test.jpg'));
      final processor = const ImageProcessor();

      final result = await processor.processImage(jpeg.path, targetQuality: 70);

      expect(result.bytes, isNotEmpty);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
    });

    test('processImage resizes large images', () async {
      // Create a 2000x2000 image – should be resized to ≤1600 on long edge.
      final jpeg =
          _createTestJpeg(p.join(tempDir.path, 'large.jpg'), width: 2000, height: 2000);
      final processor = const ImageProcessor();

      final result = await processor.processImage(jpeg.path, targetQuality: 60);

      expect(result.width, lessThanOrEqualTo(1600));
      expect(result.height, lessThanOrEqualTo(1600));
    });

    test('compressImagesToFitBudget returns one result per image', () async {
      final paths = List.generate(3, (i) {
        final jpeg =
            _createTestJpeg(p.join(tempDir.path, 'img_$i.jpg'), width: 400, height: 560);
        return jpeg.path;
      });

      final processor = const ImageProcessor();
      final results = await processor.compressImagesToFitBudget(
        paths,
        budgetBytes: kMaxPdfSizeBytes,
      );

      expect(results.length, 3);
      for (final r in results) {
        expect(r.bytes, isNotEmpty);
      }
    });

    test('compressed images fit within budget for small synthetic pages', () async {
      final paths = List.generate(5, (i) {
        return _createTestJpeg(
          p.join(tempDir.path, 'page_$i.jpg'),
          width: 400,
          height: 560,
        ).path;
      });

      const budget = kMaxPdfSizeBytes;
      final processor = const ImageProcessor();
      final results = await processor.compressImagesToFitBudget(
        paths,
        budgetBytes: budget,
      );

      final totalSize = results.fold<int>(0, (sum, r) => sum + r.bytes.length);
      // The total compressed image bytes should be within the budget minus the
      // PDF overhead allowance (40 KB) that the processor accounts for.
      expect(totalSize, lessThanOrEqualTo(budget));
    });

    test('throws ImageProcessingException for invalid file', () async {
      final badPath = p.join(tempDir.path, 'not_an_image.jpg');
      File(badPath).writeAsStringSync('not image data');

      final processor = const ImageProcessor();
      expect(
        () => processor.processImage(badPath),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // PdfGenerator size-constraint tests
  // -------------------------------------------------------------------------
  group('PdfGenerator – 1 MB size constraint', () {
    test('generatePdf produces a file strictly under 1 MB for a single page',
        () async {
      final jpeg = _createTestJpeg(
        p.join(tempDir.path, 'single_page.jpg'),
        width: 800,
        height: 1100,
      );

      final generator = PdfGenerator(outputDirectory: tempDir);
      final result = await generator.generatePdf(
        imagePaths: [jpeg.path],
        fileName: 'test_single',
      );

      expect(result.fileSizeBytes, lessThan(kPdfSizeLimitBytes),
          reason:
              'Single-page PDF must be strictly under 1 MB (${kPdfSizeLimitBytes} bytes)');
      expect(result.withinSizeLimit, isTrue);
      expect(File(result.outputPath).existsSync(), isTrue);
    });

    test('generatePdf produces a file strictly under 1 MB for multiple pages',
        () async {
      final paths = List.generate(4, (i) {
        return _createTestJpeg(
          p.join(tempDir.path, 'mp_page_$i.jpg'),
          width: 800,
          height: 1100,
        ).path;
      });

      final generator = PdfGenerator(outputDirectory: tempDir);
      final result = await generator.generatePdf(
        imagePaths: paths,
        fileName: 'test_multi',
      );

      expect(result.fileSizeBytes, lessThan(kPdfSizeLimitBytes),
          reason:
              'Multi-page PDF must be strictly under 1 MB (${kPdfSizeLimitBytes} bytes)');
      expect(result.withinSizeLimit, isTrue);
      expect(result.pageCount, 4);
    });

    test('withinSizeLimit matches actual file size', () async {
      final jpeg = _createTestJpeg(
        p.join(tempDir.path, 'check.jpg'),
        width: 400,
        height: 560,
      );

      final generator = PdfGenerator(outputDirectory: tempDir);
      final result = await generator.generatePdf(
        imagePaths: [jpeg.path],
        fileName: 'check_limit',
      );

      final actualSize = File(result.outputPath).lengthSync();
      expect(result.fileSizeBytes, actualSize);
      expect(result.withinSizeLimit, actualSize < kPdfSizeLimitBytes);
    });

    test('generated PDF file exists on disk', () async {
      final jpeg = _createTestJpeg(
        p.join(tempDir.path, 'exists.jpg'),
        width: 300,
        height: 400,
      );

      final generator = PdfGenerator(outputDirectory: tempDir);
      final result = await generator.generatePdf(
        imagePaths: [jpeg.path],
        fileName: 'exists_check',
      );

      expect(File(result.outputPath).existsSync(), isTrue);
    });

    test('generatePdf throws ArgumentError for empty image list', () {
      final generator = PdfGenerator(outputDirectory: tempDir);
      expect(
        () => generator.generatePdf(imagePaths: [], fileName: 'empty'),
        throwsArgumentError,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Document _makeDocument({required int fileSizeBytes}) {
  return Document(
    id: 'test-id',
    name: 'Test Document',
    pdfPath: '/tmp/test.pdf',
    createdAt: DateTime(2024, 1, 15, 10, 30),
    fileSizeBytes: fileSizeBytes,
    pageCount: 1,
    imagePaths: [],
  );
}
