import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/pdf_models.dart';

abstract interface class PdfEngineClient {
  Future<EngineHealth> health();
  Future<PdfOcrHealth> ocrHealth();
  Future<DocumentIr> documentIrBaseline(
    String source,
    String destination, {
    int? page,
  });
  Future<PdfOcrResult> ocr(
    String source,
    String destination, {
    required String language,
    required bool deskew,
    required bool rotatePages,
  });
  Future<PdfDocumentInfo> documentInfo(String path);
  Future<RenderedPdfPage> renderPage(
    String path,
    int page,
    double scale,
    String output,
  );
  Future<PdfSignatureHealth> signatureHealth();
  Future<PdfSignatureVerification> verifySignatures(String source);
  Future<PdfSignatureResult> signPades(
    String source,
    String destination, {
    required String pkcs12Path,
    required String passwordFilePath,
    required PdfSignatureProfile profile,
    String? timestampUrl,
  });
  Future<List<PdfSearchMatch>> search(String path, String query);
  Future<String> text(String path, int page);
  Future<List<PdfAnnotation>> annotations(String path, int page);
  Future<void> upsertAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation,
  );
  Future<void> upsertImageAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation, {
    String? imagePath,
  });
  Future<void> removeAnnotation(
    String source,
    String destination,
    int page,
    String id,
  );
  Future<void> saveAs(String source, String destination);
}

class EngineClientException implements Exception {
  const EngineClientException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class AzpdfEngineClient implements PdfEngineClient {
  AzpdfEngineClient({
    this.enginePath,
    this.timeout = const Duration(seconds: 60),
  });

  final String? enginePath;
  final Duration timeout;
  String? _resolvedEnginePath;

  @override
  Future<EngineHealth> health() async =>
      EngineHealth.fromJson(await _invoke('health'));

  @override
  Future<PdfOcrHealth> ocrHealth() async =>
      PdfOcrHealth.fromJson(await _invoke('ocr-health'));

  @override
  Future<DocumentIr> documentIrBaseline(
    String source,
    String destination, {
    int? page,
  }) async {
    final arguments = <String>[
      '--document',
      source,
      '--output',
      destination,
      if (page != null) ...['--page', '$page'],
    ];
    await _invoke('ir-baseline', arguments, const Duration(minutes: 2));
    final decoded = jsonDecode(await File(destination).readAsString());
    return DocumentIr.fromJson(decoded as Map<String, dynamic>);
  }

  @override
  Future<PdfOcrResult> ocr(
    String source,
    String destination, {
    required String language,
    required bool deskew,
    required bool rotatePages,
  }) async {
    final arguments = <String>[
      '--document',
      source,
      '--output',
      destination,
      '--language',
      language,
    ];
    if (deskew) arguments.add('--deskew');
    if (rotatePages) arguments.add('--rotate-pages');
    return PdfOcrResult.fromJson(
      await _invoke('ocr', arguments, const Duration(minutes: 20)),
    );
  }

  @override
  Future<PdfSignatureHealth> signatureHealth() async =>
      PdfSignatureHealth.fromJson(await _invoke('signature-health'));

  @override
  Future<PdfSignatureVerification> verifySignatures(String source) async =>
      PdfSignatureVerification.fromJson(
        await _invoke('verify-signatures', ['--document', source]),
      );

  @override
  Future<PdfSignatureResult> signPades(
    String source,
    String destination, {
    required String pkcs12Path,
    required String passwordFilePath,
    required PdfSignatureProfile profile,
    String? timestampUrl,
  }) async {
    final arguments = <String>[
      '--document',
      source,
      '--output',
      destination,
      '--pkcs12',
      pkcs12Path,
      '--passfile',
      passwordFilePath,
      '--profile',
      profile.name,
    ];
    if (timestampUrl != null && timestampUrl.trim().isNotEmpty) {
      arguments.addAll(['--timestamp-url', timestampUrl.trim()]);
    }
    return PdfSignatureResult.fromJson(
      await _invoke('sign-pades', arguments, const Duration(minutes: 5)),
    );
  }

  @override
  Future<PdfDocumentInfo> documentInfo(String path) async =>
      PdfDocumentInfo.fromJson(await _invoke('info', ['--document', path]));

  @override
  Future<RenderedPdfPage> renderPage(
    String path,
    int page,
    double scale,
    String output,
  ) async => RenderedPdfPage.fromJson(
    await _invoke('render', [
      '--document',
      path,
      '--page',
      '$page',
      '--scale',
      '$scale',
      '--output',
      output,
    ]),
  );

  @override
  Future<List<PdfSearchMatch>> search(String path, String query) async {
    final result = await _invoke('search', [
      '--document',
      path,
      '--query',
      query,
    ]);
    return (result['matches'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PdfSearchMatch.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> text(String path, int page) async {
    final result = await _invoke('text', [
      '--document',
      path,
      '--page',
      '$page',
    ]);
    return result['text'] as String;
  }

  @override
  Future<List<PdfAnnotation>> annotations(String path, int page) async {
    final result = await _invoke('annotations', [
      '--document',
      path,
      '--page',
      '$page',
    ]);
    return (result['annotations'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PdfAnnotation.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> upsertAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation,
  ) async {
    await _invoke('upsert-annotation', [
      '--document',
      source,
      '--output',
      destination,
      '--payload',
      jsonEncode(annotation.toJson()),
    ]);
  }

  @override
  Future<void> upsertImageAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation, {
    String? imagePath,
  }) async {
    final arguments = <String>[
      '--document',
      source,
      '--output',
      destination,
      '--payload',
      jsonEncode(annotation.toJson()),
    ];
    if (imagePath != null) {
      arguments.addAll([
        '--image',
        imagePath,
        '--format',
        imagePath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg',
      ]);
    }
    await _invoke('upsert-image-annotation', arguments);
  }

  @override
  Future<void> removeAnnotation(
    String source,
    String destination,
    int page,
    String id,
  ) async {
    await _invoke('remove-annotation', [
      '--document',
      source,
      '--output',
      destination,
      '--page',
      '$page',
      '--id',
      id,
    ]);
  }

  @override
  Future<void> saveAs(String source, String destination) async {
    await _invoke('save-as', ['--document', source, '--output', destination]);
  }

  Future<Map<String, dynamic>> _invoke(
    String command, [
    List<String> arguments = const [],
    Duration? commandTimeout,
  ]) async {
    final executable = await _resolveEngine();
    final process = await Process.start(executable, [
      command,
      ...arguments,
    ], runInShell: false);
    final outputFuture = process.stdout.transform(utf8.decoder).join();
    final errorFuture = process.stderr.transform(utf8.decoder).join();
    late int exitCode;
    final effectiveTimeout = commandTimeout ?? timeout;
    try {
      exitCode = await process.exitCode.timeout(effectiveTimeout);
    } on TimeoutException {
      process.kill();
      throw EngineClientException(
        'timeout',
        'Engine PDF vượt quá ${effectiveTimeout.inSeconds} giây.',
      );
    }
    final output = await outputFuture;
    final standardError = await errorFuture;
    if (output.trim().isEmpty) {
      throw EngineClientException(
        'empty_response',
        standardError.trim().isEmpty
            ? 'Engine PDF không trả dữ liệu.'
            : standardError.trim(),
      );
    }

    final decoded = jsonDecode(output) as Map<String, dynamic>;
    if (decoded['ok'] != true) {
      final error = (decoded['error'] as Map<String, dynamic>?) ?? const {};
      throw EngineClientException(
        error['code'] as String? ?? 'engine_error',
        error['message'] as String? ?? 'Engine PDF gặp lỗi không xác định.',
      );
    }
    if (exitCode != 0) {
      throw EngineClientException(
        'engine_exit',
        'Engine PDF kết thúc với mã $exitCode.',
      );
    }
    return decoded['result'] as Map<String, dynamic>;
  }

  Future<String> _resolveEngine() async {
    if (_resolvedEnginePath case final path?) return path;
    final fileName = Platform.isWindows ? 'azpdf-engine.exe' : 'azpdf-engine';
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidates = <String?>[
      enginePath,
      Platform.environment['AZPDF_ENGINE'],
      '${executableDirectory.path}${Platform.pathSeparator}$fileName',
      '${executableDirectory.path}${Platform.pathSeparator}data${Platform.pathSeparator}$fileName',
      '${Directory.current.path}${Platform.pathSeparator}$fileName',
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}.build${Platform.pathSeparator}release${Platform.pathSeparator}$fileName',
    ];
    for (final candidate in candidates.whereType<String>()) {
      if (await File(candidate).exists()) {
        return _resolvedEnginePath = candidate;
      }
    }
    for (final directory in (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      final candidate = '$directory${Platform.pathSeparator}$fileName';
      if (await File(candidate).exists()) {
        return _resolvedEnginePath = candidate;
      }
    }
    throw const EngineClientException(
      'engine_unavailable',
      'Không tìm thấy azpdf-engine. Đặt AZPDF_ENGINE tới executable đã build.',
    );
  }
}
