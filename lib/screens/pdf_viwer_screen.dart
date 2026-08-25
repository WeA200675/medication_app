import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Teilen-Button (nutzt share_plus)
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Teilen',
            onPressed: () async {
              if (await file.exists()) {
                await Share.shareXFiles(
                  [XFile(widget.filePath)],
                  text: widget.title,
                );
              }
            },
          ),
          // Drucken-Button (nutzt printing)
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Drucken',
            onPressed: () async {
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                await Printing.layoutPdf(
                  onLayout: (_) => bytes,
                  name: widget.title,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!file.existsSync())
            const Center(
              child: Text(
                'Datei konnte nicht gefunden werden.',
                style: TextStyle(color: Colors.red),
              ),
            )
          else
            PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) {
                setState(() {
                  _totalPages = pages ?? 0;
                  _isReady = true;
                });
              },
              onError: (error) {
                setState(() {
                  _errorMessage = error.toString();
                });
              },
              onPageChanged: (page, total) {
                setState(() {
                  _currentPage = page ?? 0;
                });
              },
            ),

          if (_errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage))
          else if (!_isReady && file.existsSync())
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: _isReady && _totalPages > 0
          ? Container(
              color: Colors.teal.shade50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Seite ${_currentPage + 1} von $_totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}