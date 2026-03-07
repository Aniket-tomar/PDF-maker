import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document.dart';

/// Full-screen PDF viewer for a scanned [Document].
class PdfViewerScreen extends StatefulWidget {
  final Document document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _controller;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.document.pdfPath),
      initialPage: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await Share.shareXFiles(
      [XFile(widget.document.pdfPath)],
      subject: widget.document.name,
      text: 'Scanned with TinyScan – ${widget.document.fileSizeLabel}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.name,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${doc.fileSizeLabel} · ${doc.pageCount} '
              '${doc.pageCount == 1 ? 'page' : 'pages'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _share,
          ),
        ],
      ),
      body: Stack(
        children: [
          PdfViewPinch(
            controller: _controller,
            onPageChanged: (page) => setState(() => _currentPage = page),
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Failed to load PDF:\n$error',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: PdfPageNumber(
                  controller: _controller,
                  builder: (_, loadingState, page, pagesCount) => Text(
                    '$page / ${pagesCount ?? '-'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          if (!doc.isUnderSizeLimit)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${doc.fileSizeLabel} – over 1 MB',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
