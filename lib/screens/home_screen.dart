import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document.dart';
import '../services/document_storage.dart';
import '../widgets/document_card.dart';
import 'scanner_screen.dart';
import 'pdf_viewer_screen.dart';

/// The main home screen displaying the list of scanned documents.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DocumentStorage _storage = DocumentStorage.instance;
  List<Document> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    final docs = await _storage.loadDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _loading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<Document>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null) {
      await _storage.saveDocument(result);
      await _loadDocuments();
    }
  }

  Future<void> _openDocument(Document doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(document: doc)),
    );
  }

  Future<void> _shareDocument(Document doc) async {
    await Share.shareXFiles(
      [XFile(doc.pdfPath)],
      subject: doc.name,
      text: 'Scanned with TinyScan – ${doc.fileSizeLabel}',
    );
  }

  Future<void> _deleteDocument(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteDocument(doc);
      await _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TinyScan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: _showAbout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : _buildDocumentList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 96,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No documents yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap Scan to capture your first document.\nEvery PDF will be under 1 MB.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentList() {
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _documents.length,
        itemBuilder: (_, index) {
          final doc = _documents[index];
          return DocumentCard(
            document: doc,
            onTap: () => _openDocument(doc),
            onShare: () => _shareDocument(doc),
            onDelete: () => _deleteDocument(doc),
          );
        },
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'TinyScan',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.document_scanner, size: 48),
      children: [
        const Text(
          'TinyScan is a high-performance PDF document scanner that '
          'guarantees every generated PDF is strictly under 1 MB – '
          'perfect for email, web uploads and low-bandwidth sharing.',
        ),
      ],
    );
  }
}
