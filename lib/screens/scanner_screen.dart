import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/document.dart';
import '../services/pdf_generator.dart';
import '../services/image_processor.dart';

/// Screen that lets the user capture or import document images and converts
/// them into an optimized <1 MB PDF.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final PdfGenerator _pdfGenerator = PdfGenerator();
  final _nameController = TextEditingController();

  List<File> _images = [];
  bool _grayscale = true;
  bool _generating = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image capture
  // ---------------------------------------------------------------------------

  Future<void> _captureFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked != null) {
      final saved = await _saveImageTemp(picked.path);
      setState(() => _images.add(saved));
    }
  }

  Future<void> _importFromGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 95);
    if (picked.isNotEmpty) {
      final files = await Future.wait(
        picked.map((xf) => _saveImageTemp(xf.path)),
      );
      setState(() => _images.addAll(files));
    }
  }

  Future<File> _saveImageTemp(String sourcePath) async {
    final tempDir = await getTemporaryDirectory();
    final dest = File(p.join(tempDir.path, '${const Uuid().v4()}.jpg'));
    return File(sourcePath).copy(dest.path);
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final img = _images.removeAt(oldIndex);
      _images.insert(newIndex, img);
    });
  }

  // ---------------------------------------------------------------------------
  // PDF generation
  // ---------------------------------------------------------------------------

  Future<void> _generatePdf() async {
    if (_images.isEmpty) {
      _showSnack('Please add at least one page.');
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? _defaultDocName()
        : _nameController.text.trim();

    setState(() {
      _generating = true;
      _statusMessage = 'Optimising images…';
    });

    try {
      final result = await _pdfGenerator.generatePdf(
        imagePaths: _images.map((f) => f.path).toList(),
        fileName: name,
        grayscale: _grayscale,
      );

      setState(() => _statusMessage = 'Building PDF…');

      // Save the original image paths for the document record.
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(appDir.path, 'tinyscan', 'images'));
      if (!imgDir.existsSync()) imgDir.createSync(recursive: true);

      final savedImagePaths = <String>[];
      for (int i = 0; i < _images.length; i++) {
        final dest = File(p.join(imgDir.path, '${const Uuid().v4()}.jpg'));
        await _images[i].copy(dest.path);
        savedImagePaths.add(dest.path);
      }

      final document = Document(
        id: const Uuid().v4(),
        name: name,
        pdfPath: result.outputPath,
        createdAt: DateTime.now(),
        fileSizeBytes: result.fileSizeBytes,
        pageCount: result.pageCount,
        imagePaths: savedImagePaths,
      );

      if (mounted) {
        if (!result.withinSizeLimit) {
          _showSnack(
            '⚠️ PDF is ${document.fileSizeLabel} – slightly over the 1 MB target.',
            isWarning: true,
          );
        }
        Navigator.pop(context, document);
      }
    } catch (e) {
      setState(() {
        _generating = false;
        _statusMessage = '';
      });
      _showSnack('Error generating PDF: $e', isWarning: true);
    }
  }

  String _defaultDocName() {
    final now = DateTime.now();
    return 'Scan_${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  void _showSnack(String msg, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isWarning ? Colors.orange : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Scan'),
        actions: [
          if (!_generating)
            TextButton.icon(
              onPressed: _images.isEmpty ? null : _generatePdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text(
                'Create PDF',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _generating ? _buildGeneratingView(theme) : _buildScannerBody(theme),
    );
  }

  Widget _buildGeneratingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Keeping your PDF under 1 MB…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerBody(ThemeData theme) {
    return Column(
      children: [
        _buildNameField(theme),
        _buildOptions(theme),
        Expanded(child: _buildPageGrid(theme)),
        _buildAddButtons(theme),
      ],
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Document name',
          hintText: _defaultDocName(),
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.drive_file_rename_outline),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildOptions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 18),
          const SizedBox(width: 6),
          const Text('Grayscale'),
          Switch(
            value: _grayscale,
            onChanged: (v) => setState(() => _grayscale = v),
          ),
          const Spacer(),
          Text(
            '${_images.length} page${_images.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildPageGrid(ThemeData theme) {
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'Add pages to begin',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _images.length,
      onReorder: _reorderImages,
      itemBuilder: (_, index) {
        return _buildPageTile(index);
      },
    );
  }

  Widget _buildPageTile(int index) {
    return Card(
      key: ValueKey(_images[index].path),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            _images[index],
            width: 52,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
        title: Text('Page ${index + 1}'),
        subtitle: FutureBuilder<int>(
          future: _images[index].length(),
          builder: (_, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final kb = snap.data! / 1024;
            return Text('${kb.toStringAsFixed(0)} KB (original)');
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _removeImage(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButtons(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _captureFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
