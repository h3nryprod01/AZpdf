import 'dart:io';

import 'package:azpdf_desktop/main.dart';
import 'package:azpdf_desktop/src/controllers/workspace_controller.dart';
import 'package:azpdf_desktop/src/engine/azpdf_engine_client.dart';
import 'package:azpdf_desktop/src/models/pdf_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azpdf_desktop/src/l10n/strings.dart';

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
    expect(find.text(L('open_a_pdf')), findsOneWidget);
    expect(
      find.text(L('processed_locally')),
      findsOneWidget,
    );
    expect(find.text(L('local_processing')), findsOneWidget);

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
      find.byTooltip(L('insert_text_hint')),
      findsOneWidget,
    );
    expect(find.byTooltip(L('insert_note_hint')), findsOneWidget);
    expect(
      find.byTooltip(L('insert_image_hint')),
      findsOneWidget,
    );
    expect(
      find.byTooltip(L('ocr_local_hint')),
      findsOneWidget,
    );
    expect(find.byTooltip(L('review_layout')), findsOneWidget);
    expect(find.byTooltip(L('pades_sign_with_pkcs12')), findsOneWidget);
    expect(
      find.byTooltip(L('verify_pades_integrity')),
      findsOneWidget,
    );
    expect(find.byTooltip(L('undo_shortcut')), findsOneWidget);
    expect(find.byTooltip(L('redo_shortcut')), findsOneWidget);

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

    await tester.tap(find.byTooltip(L('review_layout')));
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

    expect(find.text(L('review_layout')), findsOneWidget);
    expect(find.textContaining('MuPDF baseline'), findsOneWidget);
    expect(find.text('AZpdf layout review'), findsOneWidget);
    expect(find.text('Test document layout'), findsOneWidget);
    expect(find.text(L('heading')), findsWidgets);
    expect(find.text(L('paragraph')), findsWidgets);
    expect(
      find.byKey(const ValueKey('document-ir-block-block-1')),
      findsOneWidget,
    );
    expect(controller.current?.layoutReview?.plainText, contains('AZpdf'));

    await tester.tap(find.byTooltip(L('close_layout_review')));
    await tester.pumpAndSettle();
    expect(find.text(L('review_layout')), findsNothing);

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

    await tester.tap(find.byTooltip(L('close_named', {'name': 'close-warning.pdf'})));
    await tester.pumpAndSettle();
    expect(find.text(L('save_changes_q')), findsOneWidget);
    expect(
      find.text(L('named_has_unsaved', {'name': 'close-warning.pdf'})),
      findsOneWidget,
    );

    await tester.tap(find.text(L('cancel')));
    await tester.pumpAndSettle();
    expect(controller.documents, hasLength(1));

    await tester.tap(find.byTooltip(L('close_named', {'name': 'close-warning.pdf'})));
    await tester.pumpAndSettle();
    await tester.tap(find.text(L('dont_save')));
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

    await tester.tap(find.byTooltip(L('ocr_local_hint')));
    await tester.pumpAndSettle();
    expect(find.text(L('ocr_whole_document')), findsOneWidget);
    expect(find.textContaining('OCRmyPDF 17.8.1'), findsOneWidget);
    expect(find.textContaining(L('baseline_no_table_semantics').split('.').first), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, L('start_ocr'));
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

    expect(find.text(L('ocr_whole_document')), findsNothing);
    expect(controller.current?.busy, isFalse);
    expect(controller.current?.error, isNull);
    expect(engine.lastOcrLanguage, 'vie+eng');
    expect(controller.current?.dirty, isTrue);
    expect(controller.current?.canUndo, isTrue);
    expect(find.textContaining(L('ocr_complete', {'provider': 'OCRmyPDF', 'version': ''}).split('.').first), findsOneWidget);

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

  testWidgets('renders at devicePixelRatio, not at zoom alone', (tester) async {
    // Lỗi đã phát hành: engine nhận thẳng `zoom`, đổi thành `72 * zoom` DPI. Ở
    // 100% trên màn 150% thì trang A4 chỉ có 595 px phủ 892 px vật lý, và
    // Flutter kéo giãn phần thiếu — đó là chỗ chữ nhòe so với Chrome.
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = File('/tmp/dpr-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final engine = _FakeEngine();
    final controller = WorkspaceController(engine);
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pump(const Duration(milliseconds: 250));

    expect(engine.renderScales.last, closeTo(1.5, 0.001));
    expect(engine.thumbnailScales, everyElement(closeTo(0.27, 0.001)));

    // Ảnh dày hơn nhưng Ô LAYOUT phải giữ nguyên point × zoom, nếu không trang
    // sẽ to gấp 1,5 lần và lớp phủ annotation lệch khỏi chữ.
    expect(controller.current?.pageWidthPoints, closeTo(595, 0.001));
    expect(controller.current?.layoutWidth, closeTo(595, 0.001));

    await tester.runAsync(() => controller.changeZoom(2));
    await tester.pump(const Duration(milliseconds: 250));
    expect(engine.renderScales.last, closeTo(3, 0.001));
    expect(controller.current?.layoutWidth, closeTo(1190, 0.001));

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('mouse wheel scrolls the page; Ctrl+wheel zooms', (tester) async {
    // Bản trước dùng InteractiveViewer, và nó đọc con lăn chuột là cử chỉ
    // PHÓNG TO — nên cuộn xem tài liệu lại đổi mức phóng.
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = File('/tmp/wheel-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pump(const Duration(milliseconds: 250));

    // Điểm nằm trong vùng xem trang: bên phải cột trang, dưới thanh công cụ.
    const overCanvas = Offset(800, 500);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(overCanvas));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 160)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.current?.zoom, 1, reason: 'con lăn trần không được phóng');

    // Giữ Ctrl thì cùng sự kiện đó phải phóng — cũng là bằng chứng sự kiện
    // con lăn CÓ tới được vùng xem, nên khẳng định ở trên không rỗng.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -160)));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.current?.zoom, closeTo(1.25, 0.001));

    controller.dispose();
    source.deleteSync();
  });

  testWidgets('fit to width fills the viewport and stops recomputing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = File('/tmp/fit-sample.pdf')
      ..writeAsBytesSync('%PDF-test'.codeUnits);
    final controller = WorkspaceController(_FakeEngine());
    await tester.pumpWidget(AZpdfApp(controller: controller));
    await tester.pump();
    await tester.runAsync(() => controller.openPath(source.path));
    await tester.pump(const Duration(milliseconds: 250));

    // Thanh công cụ cuộn ngang được, nên nút có thể nằm ngoài khung nhìn ở bề
    // ngang này; kéo nó vào trước rồi mới bấm.
    await tester.ensureVisible(find.byTooltip(L('fit_width')));
    await tester.pump();
    await tester.tap(find.byTooltip(L('fit_width')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final fitted = controller.current!.zoom;
    expect(fitted, isNot(closeTo(1, 0.001)));
    expect(controller.current?.fitMode, PdfFitMode.width);

    // Hội tụ: vòng layout → tính zoom → render → layout phải tự dừng. Nếu
    // không, `zoom` còn dao động ở các frame sau và app quay tít.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.current!.zoom, closeTo(fitted, 0.0001));

    // Tự đặt mức phóng thì bỏ chế độ khớp, nếu không lần layout sau sẽ giật
    // ngược về mức fit và nút +/− trông như hỏng.
    await tester.ensureVisible(find.byTooltip(L('zoom_in_shortcut')));
    await tester.pump();
    await tester.tap(find.byTooltip(L('zoom_in_shortcut')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.current?.fitMode, PdfFitMode.free);

    controller.dispose();
    source.deleteSync();
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
  final List<double> renderScales = [];
  final List<double> thumbnailScales = [];

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
    if (output.contains('-thumb-')) {
      thumbnailScales.add(scale);
    } else {
      renderScales.add(scale);
    }
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
    // Engine thật trả về kích thước PIXEL, tức đã nhân scale
    // (MuPDFDocumentEngine.render: `baseSize.width * request.scale`). Fake phải
    // giống ở điểm này, nếu không nó che mất chính lỗi đang được canh: quy
    // ngược ra point là chia cho scale.
    return RenderedPdfPage(
      page: page,
      width: 595 * scale,
      height: 842 * scale,
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
