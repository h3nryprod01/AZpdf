import 'dart:io';

import 'package:azpdf_desktop/main.dart';
import 'package:azpdf_desktop/src/controllers/workspace_controller.dart';
import 'package:azpdf_desktop/src/engine/azpdf_engine_client.dart';
import 'package:azpdf_desktop/src/models/pdf_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps PDF annotation bounds through all page rotations', () {
    const pageBox = PdfBounds(x: 10, y: 20, width: 842, height: 595);
    const source = PdfBounds(x: 70, y: 120, width: 220, height: 60);
    final expected = <int, PdfBounds>{
      0: const PdfBounds(x: 60, y: 435, width: 220, height: 60),
      90: const PdfBounds(x: 100, y: 60, width: 60, height: 220),
      180: const PdfBounds(x: 562, y: 100, width: 220, height: 60),
      270: const PdfBounds(x: 435, y: 562, width: 60, height: 220),
    };

    for (final entry in expected.entries) {
      final geometry = PdfPageGeometry(pageBox: pageBox, rotation: entry.key);
      final viewport = geometry.toViewport(source);
      _expectBounds(viewport, entry.value);
      _expectBounds(geometry.fromViewport(viewport), source);
    }
  });

  testWidgets('shows accessible local-first welcome state', (tester) async {
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('AZpdf'), findsOneWidget);
    expect(find.text('Mở một tài liệu PDF'), findsOneWidget);
    expect(
      find.text('Tài liệu được xử lý hoàn toàn trên máy của bạn.'),
      findsOneWidget,
    );
    expect(find.text('Xử lý cục bộ'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('opens a PDF into a bordered document tab', (tester) async {
    final source = File('/tmp/sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('sample.pdf'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('2 trang'), findsOneWidget);
    expect(
      find.byTooltip('Chèn chữ có thể di chuyển và định dạng'),
      findsOneWidget,
    );
    expect(find.byTooltip('Chèn ghi chú có thể di chuyển'), findsOneWidget);
    expect(
      find.byTooltip('Chèn ảnh có thể di chuyển và đổi kích thước'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('OCR cục bộ và tạo lớp chữ tìm kiếm'),
      findsOneWidget,
    );
    expect(find.byTooltip('Review bố cục và reading order'), findsOneWidget);
    expect(find.byTooltip('Ký số PAdES bằng PKCS#12'), findsOneWidget);
    expect(
      find.byTooltip('Xác minh tính toàn vẹn chữ ký PAdES'),
      findsOneWidget,
    );
    expect(find.byTooltip('Hoàn tác (Ctrl+Z)'), findsOneWidget);
    expect(find.byTooltip('Làm lại (Ctrl+Shift+Z)'), findsOneWidget);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('inserts editable text into the working PDF', (tester) async {
    final source = File('/tmp/editable-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final engine = _FakeEngine();
    final controller = WorkspaceController(engine);
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() async {
      await controller.openPath(source.path);
      await controller.addText(
        'Editable text',
        const PdfTextStyle(fontSize: 18, isBold: true),
      );
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.selectedAnnotation?.contents, 'Editable text');
    expect(engine.values.single.textStyle?.isBold, isTrue);
    await tester.runAsync(controller.save);
    expect(engine.savedSource, controller.current?.workingPath);
    expect(engine.savedDestination, source.path);
    expect(controller.current?.dirty, isFalse);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('reviews DocumentIR blocks in reading order over the page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = File('/tmp/layout-review.pdf')
      ..writeAsBytesSync('%PDF-layout'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Review bố cục và reading order'));
    await tester.pump();
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
      if (controller.current?.busy == false &&
          controller.current?.layoutReview != null) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Review bố cục và reading order'), findsOneWidget);
    expect(find.textContaining('MuPDF baseline'), findsOneWidget);
    expect(find.text('AZpdf layout review'), findsOneWidget);
    expect(find.text('Test document layout'), findsOneWidget);
    expect(find.text('Tiêu đề'), findsWidgets);
    expect(find.text('Đoạn văn'), findsWidgets);
    expect(
      find.byKey(const ValueKey('document-ir-block-block-1')),
      findsOneWidget,
    );
    expect(controller.current?.layoutReview?.plainText, contains('AZpdf'));

    await tester.tap(find.byTooltip('Đóng review bố cục'));
    await tester.pumpAndSettle();
    expect(find.text('Review bố cục và reading order'), findsNothing);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('undo and redo restore revision and dirty state', (tester) async {
    final source = File('/tmp/undo-redo-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() async {
      await controller.openPath(source.path);
      await controller.addText('Undo me', const PdfTextStyle(fontSize: 16));
    });

    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.canUndo, isTrue);
    expect(controller.current?.canRedo, isFalse);

    await tester.runAsync(controller.undo);
    expect(controller.current?.dirty, isFalse);
    expect(controller.current?.canUndo, isFalse);
    expect(controller.current?.canRedo, isTrue);

    await tester.runAsync(controller.redo);
    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.canUndo, isTrue);
    expect(controller.current?.canRedo, isFalse);

    await tester.runAsync(controller.save);
    await tester.runAsync(controller.undo);
    expect(controller.current?.dirty, isTrue);
    await tester.runAsync(controller.redo);
    expect(controller.current?.dirty, isFalse);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('warns before closing an unsaved document tab', (tester) async {
    final source = File('/tmp/close-warning.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() async {
      await controller.openPath(source.path);
      await controller.addNote('Unsaved note');
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Đóng close-warning.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu thay đổi?'), findsOneWidget);
    expect(
      find.text('“close-warning.pdf” có thay đổi chưa được lưu.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(controller.documents, hasLength(1));

    await tester.tap(find.byTooltip('Đóng close-warning.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không lưu'));
    await tester.pumpAndSettle();
    expect(controller.documents, isEmpty);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('runs local OCR from the toolbar and keeps it undoable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = File('/tmp/ocr-sample.pdf')
      ..writeAsBytesSync('%PDF-scan'.codeUnits);
    final engine = _FakeEngine();
    final controller = WorkspaceController(engine);
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('OCR cục bộ và tạo lớp chữ tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('OCR toàn bộ tài liệu'), findsOneWidget);
    expect(find.textContaining('OCRmyPDF 17.8.1'), findsOneWidget);
    expect(find.textContaining('chưa hiểu ngữ nghĩa bảng'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, 'Bắt đầu OCR');
    expect(startButton, findsOneWidget);
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (controller.current?.busy == false) break;
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('OCR toàn bộ tài liệu'), findsNothing);
    expect(controller.current?.busy, isFalse);
    expect(controller.current?.error, isNull);
    expect(engine.lastOcrLanguage, 'vie+eng');
    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.canUndo, isTrue);
    expect(find.textContaining('OCR hoàn tất bằng OCRmyPDF'), findsOneWidget);

    engine.searchResults = const [
      PdfSearchMatch(pageIndex: 0, text: 'Portable'),
    ];
    await tester.runAsync(() => controller.search('Portable'));
    expect(controller.current?.searchMatches, hasLength(1));
    engine.searchResults = const [];
    await tester.runAsync(controller.undo);
    expect(controller.current?.dirty, isFalse);
    expect(controller.current?.canRedo, isTrue);
    expect(controller.current?.searchMatches, isEmpty);

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('signs a working copy with PAdES and keeps it undoable', (
    tester,
  ) async {
    final source = File('/tmp/pades-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final certificate = File('/tmp/azpdf-test.p12')
      ..writeAsBytesSync('certificate'.codeUnits);
    final engine = _FakeEngine();
    final controller = WorkspaceController(engine);
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));

    final result = await tester.runAsync(
      () => controller.applyPadesSignature(
        pkcs12Path: certificate.path,
        password: 'secret',
        profile: PdfSignatureProfile.baselineB,
      ),
    );

    expect(result?.verification.isCryptographicallyValid, isTrue);
    expect(engine.lastSignatureProfile, PdfSignatureProfile.baselineB);
    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.canUndo, isTrue);
    await tester.runAsync(controller.undo);
    expect(controller.current?.dirty, isFalse);

    controller.dispose();
    source.deleteSync();
    certificate.deleteSync();
  });
}

void _expectBounds(PdfBounds actual, PdfBounds expected) {
  expect(actual.x, closeTo(expected.x, 0.001));
  expect(actual.y, closeTo(expected.y, 0.001));
  expect(actual.width, closeTo(expected.width, 0.001));
  expect(actual.height, closeTo(expected.height, 0.001));
}

class _FakeEngine implements PdfEngineClient {
  final List<PdfAnnotation> values = [];
  List<PdfSearchMatch> searchResults = const [];
  String? savedSource;
  String? savedDestination;
  String? lastOcrLanguage;
  PdfSignatureProfile? lastSignatureProfile;

  @override
  Future<EngineHealth> health() async => const EngineHealth(
    protocolVersion: 1,
    engine: 'MuPDF',
    engineVersion: 'mutool version test',
    executable: '/tmp/mutool',
  );

  @override
  Future<PdfOcrHealth> ocrHealth() async => const PdfOcrHealth(
    provider: 'OCRmyPDF',
    version: '17.8.1',
    executable: '/tmp/ocrmypdf',
    features: {'searchablePDF', 'visualLayoutPreservation'},
  );

  @override
  Future<DocumentIr> documentIrBaseline(
    String source,
    String destination, {
    int? page,
  }) async => DocumentIr(
    schemaVersion: 1,
    providerId: 'org.azpdf.mupdf-stext',
    providerVersion: 'test',
    pages: [
      DocumentIrPage(
        index: page ?? 0,
        width: 595,
        height: 842,
        sourceRotation: 0,
        blocks: const [
          DocumentIrBlock(
            id: 'heading-1',
            kind: DocumentIrBlockKind.heading,
            bounds: PdfBounds(x: 72, y: 40, width: 451, height: 24),
            isArtifact: false,
            text: 'AZpdf layout review',
          ),
          DocumentIrBlock(
            id: 'block-1',
            kind: DocumentIrBlockKind.paragraph,
            bounds: PdfBounds(x: 72, y: 72, width: 451, height: 24),
            isArtifact: false,
            text: 'Test document layout',
          ),
        ],
        readingOrder: const ['heading-1', 'block-1'],
      ),
    ],
  );

  @override
  Future<PdfOcrResult> ocr(
    String source,
    String destination, {
    required String language,
    required bool deskew,
    required bool rotatePages,
  }) async {
    lastOcrLanguage = language;
    File(destination).writeAsBytesSync(File(source).readAsBytesSync());
    return PdfOcrResult(
      provider: 'OCRmyPDF',
      version: '17.8.1',
      language: language,
      output: destination,
      bytes: File(destination).lengthSync(),
      features: const {'searchablePDF', 'visualLayoutPreservation'},
    );
  }

  @override
  Future<PdfSignatureHealth> signatureHealth() async =>
      const PdfSignatureHealth(
        provider: 'pyHanko',
        version: '0.32.1',
        executable: '/tmp/pyhanko',
        profiles: {
          PdfSignatureProfile.baselineB,
          PdfSignatureProfile.baselineLT,
          PdfSignatureProfile.baselineLTA,
        },
      );

  @override
  Future<PdfSignatureVerification> verifySignatures(String source) async =>
      const PdfSignatureVerification(
        integrity: 'valid',
        certificateTrust: 'untrusted',
        signerName: 'CN=AZpdf Test',
        details: 'The signature is cryptographically sound.',
        hasTimestamp: false,
        hasValidationInfo: false,
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
    lastSignatureProfile = profile;
    File(destination).writeAsBytesSync(File(source).readAsBytesSync());
    return PdfSignatureResult(
      provider: 'pyHanko',
      version: '0.32.1',
      profile: profile,
      output: destination,
      bytes: File(destination).lengthSync(),
      verification: await verifySignatures(destination),
    );
  }

  @override
  Future<PdfDocumentInfo> documentInfo(String path) async =>
      const PdfDocumentInfo(
        protocolVersion: 1,
        pageCount: 2,
        metadata: PdfMetadata(title: 'Test'),
        capabilities: {'open', 'save', 'render', 'search', 'annotations'},
      );

  @override
  Future<RenderedPdfPage> renderPage(
    String path,
    int page,
    double scale,
    String output,
  ) async {
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xD7,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0xF0,
      0x1F,
      0x00,
      0x05,
      0x00,
      0x01,
      0xFF,
      0x89,
      0x99,
      0x3D,
      0x1D,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    return RenderedPdfPage(
      page: page,
      width: 595,
      height: 842,
      format: 'png',
      output: output,
    );
  }

  @override
  Future<void> saveAs(String source, String destination) async {
    savedSource = source;
    savedDestination = destination;
  }

  @override
  Future<List<PdfAnnotation>> annotations(String path, int page) async =>
      values.where((value) => value.pageIndex == page).toList();

  @override
  Future<void> upsertAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation,
  ) async {
    final index = values.indexWhere((value) => value.id == annotation.id);
    if (index < 0) {
      values.add(annotation);
    } else {
      values[index] = annotation;
    }
  }

  @override
  Future<void> upsertImageAnnotation(
    String source,
    String destination,
    PdfAnnotation annotation, {
    String? imagePath,
  }) => upsertAnnotation(source, destination, annotation);

  @override
  Future<void> removeAnnotation(
    String source,
    String destination,
    int page,
    String id,
  ) async {
    values.removeWhere((value) => value.pageIndex == page && value.id == id);
  }

  @override
  Future<List<PdfSearchMatch>> search(String path, String query) async =>
      searchResults;

  @override
  Future<String> text(String path, int page) async => 'Test';
}
