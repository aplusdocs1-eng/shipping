import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Thin JS-interop bridge to Tesseract.js (loaded in web/index.html),
/// which runs OCR entirely client-side in the browser — no image ever
/// leaves the device, no account or API key needed. This is a pragmatic
/// choice for this project specifically: it has been a Flutter Web-only
/// deployment for its entire life (no Android/iOS build has ever existed
/// here), so an on-device native engine like Google ML Kit isn't usable,
/// and no third-party cloud OCR credentials were available to wire in
/// instead. [OcrEngine] is an interface specifically so a native or cloud
/// engine can be swapped in later without touching any calling code.
abstract class OcrEngine {
  Future<OcrResult> recognize(Uint8List imageBytes);
}

class OcrResult {
  final String text;
  // Tesseract.js reports 0-100; normalized to 0.0-1.0 to match every other
  // confidence value in this feature.
  final double confidence;
  const OcrResult({required this.text, required this.confidence});
}

class OcrException implements Exception {
  final String message;
  OcrException(this.message);
  @override
  String toString() => 'OcrException: $message';
}

class TesseractOcrEngine implements OcrEngine {
  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    if (!_isTesseractAvailable()) {
      throw OcrException(
        'OCR engine failed to load — check your internet connection and try again.',
      );
    }
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    try {
      final result = await _recognize(dataUrl.toJS, 'eng'.toJS).toDart;
      final data = (result as JSObject).getProperty('data'.toJS) as JSObject?;
      if (data == null) throw OcrException('OCR returned no data.');
      final text = (data.getProperty('text'.toJS) as JSString?)?.toDart ?? '';
      final confidenceRaw = data.getProperty('confidence'.toJS);
      final confidence = confidenceRaw.isUndefinedOrNull
          ? 0.0
          : ((confidenceRaw as JSNumber).toDartDouble) / 100.0;
      if (text.trim().isEmpty) {
        throw OcrException(
          'No text could be read from this label. Move closer, improve lighting, '
          'flatten the label, and try again.',
        );
      }
      return OcrResult(text: text, confidence: confidence.clamp(0.0, 1.0));
    } on OcrException {
      rethrow;
    } catch (e) {
      throw OcrException('OCR failed: $e');
    }
  }
}

@JS('Tesseract.recognize')
external JSPromise<JSAny?> _recognize(JSString imageDataUrl, JSString lang);

bool _isTesseractAvailable() => globalContext.has('Tesseract');
