import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// This function runs in an isolate to decode the PNG bytes
Future<Uint8List> _encodePngInIsolate(ByteData byteData) async {
  return byteData.buffer.asUint8List();
}

// This function runs in an isolate to create a PDF from image bytes
Future<pw.Document> _createPdfInIsolate(Map<String, dynamic> data) async {
  final imageBytes = data['imageBytes'] as Uint8List;
  final width = data['width'] as double;
  final height = data['height'] as double;

  final image = pw.MemoryImage(imageBytes);
  final pdf = pw.Document();

  // Determine orientation based on dimensions
  final isLandscape = width > height;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a3,
      orientation: isLandscape
          ? pw.PageOrientation.landscape
          : pw.PageOrientation.portrait,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Image(image),
        );
      },
    ),
  );
  return pdf;
}

Future<Uint8List?> exportChartAsImage(GlobalKey key,
    {double pixelRatio = 3.0}) async {
  try {
    // 1. Grab the RenderRepaintBoundary (must be done on the main thread)
    RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;

    // 2. Convert to ui.Image (must be done on the main thread)
    ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

    // 3. Convert the image to PNG bytes (must be done on the main thread)
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception("Failed to get image byte data");
    }

    // 4. Process the bytes in an isolate to avoid blocking the UI
    return await compute(_encodePngInIsolate, byteData);
  } catch (e) {
    debugPrint("Error exporting chart as image: $e");
    return null;
  }
}

Future<pw.Document?> exportChartAsPdf(GlobalKey key,
    {double pixelRatio = 3.0}) async {
  try {
    // 1. First get the image bytes
    RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final size = boundary.size;

    final bytes = await exportChartAsImage(key, pixelRatio: pixelRatio);
    if (bytes == null) {
      throw Exception("Failed to export chart image");
    }

    // 2. Create the PDF in an isolate to avoid blocking the UI
    return await compute(_createPdfInIsolate, {
      'imageBytes': bytes,
      'width': size.width,
      'height': size.height,
    });
  } catch (e) {
    debugPrint("Error exporting chart as PDF: $e");
    return null;
  }
}
