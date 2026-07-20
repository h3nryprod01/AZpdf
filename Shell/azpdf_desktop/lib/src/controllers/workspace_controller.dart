import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../engine/azpdf_engine_client.dart';
import '../models/pdf_models.dart';

class _PdfHistoryEntry {
  const _PdfHistoryEntry({required this.path, required this.revision});

  final String path;
  final int revision;
}

class OpenedPdf {
  OpenedPdf({required this.path, required this.workingPath, required this.info})
    : id = DateTime.now().microsecondsSinceEpoch.toString(),
      name = File(path).uri.pathSegments.last;

  final String id;
  String path;
  final String workingPath;
  String name;
  final PdfDocumentInfo info;
  int pageIndex = 0;
  double zoom = 1;
  bool busy = false;
  String? renderedPath;
  double? renderedWidth;
  double? renderedHeight;
  PdfPageGeometry? pageGeometry;
  String? error;
  bool dirty = false;
  String? selectedAnnotationId;
  String searchQuery = '';
  List<PdfSearchMatch> searchMatches = const [];
  final Map<int, String> thumbnails = {};
  final Map<int, List<PdfAnnotation>> annotations = {};
  DocumentIr? layoutReview;
  final List<_PdfHistoryEntry> _undoStack = [];
  final List<_PdfHistoryEntry> _redoStack = [];
  int revision = 0;
  int savedRevision = 0;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  List<PdfAnnotation> get currentAnnotations =>
      annotations[pageIndex] ?? const [];

  PdfAnnotation? get selectedAnnotation {
    final id = selectedAnnotationId;
    if (id == null) return null;
    for (final annotation in currentAnnotations) {
      if (annotation.id == id) return annotation;
    }
    return null;
  }
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.engine);

  static const int _historyLimit = 20;

  final PdfEngineClient engine;
  final List<OpenedPdf> documents = [];
  final Directory cacheDirectory = Directory.systemTemp.createTempSync(
    'azpdf-shell-',
  );

  EngineHealth? health;
  String? startupError;
  bool sidebarVisible = true;
  int selectedIndex = -1;
  int _nextRevision = 1;
  int _historySequence = 0;

  OpenedPdf? get current =>
      selectedIndex >= 0 && selectedIndex < documents.length
      ? documents[selectedIndex]
      : null;

  Future<void> initialize() async {
    try {
      health = await engine.health();
      startupError = null;
    } catch (error) {
      startupError = '$error';
    }
    notifyListeners();
  }

  Future<void> pickAndOpen() async {
    const pdfGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );
    final selected = await openFile(acceptedTypeGroups: const [pdfGroup]);
    if (selected != null) await openPath(selected.path);
  }

  Future<void> openPath(String path) async {
    final existing = documents.indexWhere((document) => document.path == path);
    if (existing >= 0) {
      selectedIndex = existing;
      notifyListeners();
      return;
    }
    try {
      final workingPath =
          '${cacheDirectory.path}${Platform.pathSeparator}'
          'working-${DateTime.now().microsecondsSinceEpoch}.pdf';
      await File(path).copy(workingPath);
      final info = await engine.documentInfo(workingPath);
      documents.add(
        OpenedPdf(path: path, workingPath: workingPath, info: info),
      );
      selectedIndex = documents.length - 1;
      startupError = null;
      notifyListeners();
      await renderCurrent();
    } catch (error) {
      startupError = '$error';
      notifyListeners();
    }
  }

  Future<void> renderCurrent() async {
    final document = current;
    if (document == null) return;
    document.busy = true;
    document.error = null;
    notifyListeners();
    try {
      final output =
          '${cacheDirectory.path}${Platform.pathSeparator}'
          '${document.id}-p${document.pageIndex}-z${(document.zoom * 100).round()}-'
          '${DateTime.now().microsecondsSinceEpoch}.png';
      final rendered = await engine.renderPage(
        document.workingPath,
        document.pageIndex,
        document.zoom,
        output,
      );
      document.renderedPath = rendered.output;
      document.renderedWidth = rendered.width;
      document.renderedHeight = rendered.height;
      document.pageGeometry = PdfPageGeometry(
        pageBox: rendered.pageBox,
        rotation: rendered.rotation,
      );
      if (document.info.capabilities.contains('annotations')) {
        document.annotations[document.pageIndex] = await engine.annotations(
          document.workingPath,
          document.pageIndex,
        );
        if (document.selectedAnnotationId != null &&
            document.selectedAnnotation == null) {
          document.selectedAnnotationId = null;
        }
      }
    } catch (error) {
      document.error = '$error';
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<String?> thumbnailFor(OpenedPdf document, int page) async {
    if (document.thumbnails[page] case final cached?) return cached;
    try {
      final output =
          '${cacheDirectory.path}${Platform.pathSeparator}'
          '${document.id}-thumb-$page.png';
      final rendered = await engine.renderPage(
        document.workingPath,
        page,
        0.18,
        output,
      );
      document.thumbnails[page] = rendered.output;
      notifyListeners();
      return rendered.output;
    } catch (_) {
      return null;
    }
  }

  Future<void> goToPage(int page) async {
    final document = current;
    if (document == null ||
        page < 0 ||
        page >= document.info.pageCount ||
        page == document.pageIndex) {
      return;
    }
    document.pageIndex = page;
    document.selectedAnnotationId = null;
    document.layoutReview = null;
    notifyListeners();
    await renderCurrent();
  }

  Future<void> changeZoom(double zoom) async {
    final document = current;
    if (document == null) return;
    document.zoom = zoom.clamp(0.25, 4);
    notifyListeners();
    await renderCurrent();
  }

  void selectDocument(int index) {
    if (index < 0 || index >= documents.length) return;
    selectedIndex = index;
    notifyListeners();
  }

  void closeDocument(int index) {
    if (index < 0 || index >= documents.length) return;
    final wasSelected = selectedIndex == index;
    final document = documents.removeAt(index);
    _deleteHistory(document._undoStack);
    _deleteHistory(document._redoStack);
    if (documents.isEmpty) {
      selectedIndex = -1;
    } else if (selectedIndex > index) {
      selectedIndex -= 1;
    } else if (wasSelected) {
      selectedIndex = index.clamp(0, documents.length - 1);
    }
    notifyListeners();
  }

  void toggleSidebar() {
    sidebarVisible = !sidebarVisible;
    notifyListeners();
  }

  Future<void> search(String query) async {
    final document = current;
    if (document == null) return;
    document.searchQuery = query.trim();
    if (document.searchQuery.isEmpty) {
      document.searchMatches = const [];
      notifyListeners();
      return;
    }
    document.busy = true;
    notifyListeners();
    try {
      document.searchMatches = await engine.search(
        document.workingPath,
        document.searchQuery,
      );
      if (document.searchMatches.isNotEmpty) {
        document.pageIndex = document.searchMatches.first.pageIndex;
        await renderCurrent();
      }
    } catch (error) {
      document.error = '$error';
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<bool> save() async {
    if (selectedIndex < 0) return false;
    return saveDocument(selectedIndex);
  }

  Future<bool> saveDocument(int index) async {
    if (index < 0 || index >= documents.length) return false;
    final document = documents[index];
    try {
      await engine.saveAs(document.workingPath, document.path);
      document.savedRevision = document.revision;
      document.dirty = false;
      document.error = null;
      notifyListeners();
      return true;
    } catch (error) {
      document.error = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<PdfOcrHealth> ocrHealth() => engine.ocrHealth();

  Future<DocumentIr?> analyzeCurrentLayout() async {
    final document = current;
    if (document == null || document.busy) return null;
    document.busy = true;
    document.error = null;
    notifyListeners();
    final output =
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'document-ir-${document.id}-p${document.pageIndex}.json';
    try {
      final result = await engine.documentIrBaseline(
        document.workingPath,
        output,
        page: document.pageIndex,
      );
      document.layoutReview = result;
      return result;
    } catch (error) {
      document.error = '$error';
      return null;
    } finally {
      _deleteFile(output);
      document.busy = false;
      notifyListeners();
    }
  }

  Future<PdfSignatureHealth> signatureHealth() => engine.signatureHealth();

  Future<PdfSignatureVerification> verifySignatures() async {
    final document = current;
    if (document == null || document.busy) {
      throw const EngineClientException(
        'document_busy',
        'Tài liệu đang bận hoặc chưa được mở.',
      );
    }
    document.busy = true;
    document.error = null;
    notifyListeners();
    try {
      return await engine.verifySignatures(document.workingPath);
    } catch (error) {
      document.error = '$error';
      rethrow;
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<PdfSignatureResult?> applyPadesSignature({
    required String pkcs12Path,
    required String password,
    required PdfSignatureProfile profile,
    String? timestampUrl,
  }) async {
    final document = current;
    if (document == null || document.busy) return null;
    document.busy = true;
    document.error = null;
    notifyListeners();
    _PdfHistoryEntry? before;
    String? output;
    final passwordPath =
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'pades-password-${DateTime.now().microsecondsSinceEpoch}.txt';
    try {
      final passwordFile = File(passwordPath);
      await passwordFile.writeAsString(password, flush: true);
      if (!Platform.isWindows) {
        final chmod = await Process.run('/bin/chmod', [
          '600',
          passwordPath,
        ], runInShell: false);
        if (chmod.exitCode != 0) {
          throw const EngineClientException(
            'credential_permissions',
            'Không thể bảo vệ file mật khẩu PKCS#12.',
          );
        }
      }
      before = await _snapshot(document);
      output =
          '${cacheDirectory.path}${Platform.pathSeparator}'
          'signed-${document.id}-${DateTime.now().microsecondsSinceEpoch}.pdf';
      final result = await engine.signPades(
        document.workingPath,
        output,
        pkcs12Path: pkcs12Path,
        passwordFilePath: passwordPath,
        profile: profile,
        timestampUrl: timestampUrl,
      );
      if (!result.verification.isCryptographicallyValid) {
        throw const EngineClientException(
          'invalid_signature_output',
          'PDF đã ký không vượt qua xác minh toàn vẹn.',
        );
      }
      await File(result.output).copy(document.workingPath);
      _deleteFile(result.output);
      _commitMutation(document, before);
      document.selectedAnnotationId = null;
      document.layoutReview = null;
      document.annotations.clear();
      document.thumbnails.clear();
      document.searchQuery = '';
      document.searchMatches = const [];
      await renderCurrent();
      return result;
    } catch (error) {
      if (before != null) await _restoreFailedMutation(document, before);
      if (output != null) _deleteFile(output);
      document.error = '$error';
      return null;
    } finally {
      final passwordFile = File(passwordPath);
      if (passwordFile.existsSync()) {
        try {
          passwordFile.writeAsBytesSync(const [], flush: true);
        } catch (_) {}
        _deleteFile(passwordPath);
      }
      document.busy = false;
      notifyListeners();
    }
  }

  Future<PdfOcrResult?> applyOcr({
    required String language,
    required bool deskew,
    required bool rotatePages,
  }) async {
    final document = current;
    if (document == null || document.busy) return null;
    document.busy = true;
    document.error = null;
    notifyListeners();
    _PdfHistoryEntry? before;
    String? output;
    try {
      before = await _snapshot(document);
      output =
          '${cacheDirectory.path}${Platform.pathSeparator}'
          'ocr-${document.id}-${DateTime.now().microsecondsSinceEpoch}.pdf';
      final result = await engine.ocr(
        document.workingPath,
        output,
        language: language,
        deskew: deskew,
        rotatePages: rotatePages,
      );
      await File(result.output).copy(document.workingPath);
      _deleteFile(result.output);
      _commitMutation(document, before);
      document.selectedAnnotationId = null;
      document.annotations.clear();
      document.thumbnails.clear();
      document.searchQuery = '';
      document.searchMatches = const [];
      await renderCurrent();
      return result;
    } catch (error) {
      if (before != null) await _restoreFailedMutation(document, before);
      if (output != null) _deleteFile(output);
      document.error = '$error';
      return null;
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<void> saveAs() async {
    final document = current;
    if (document == null) return;
    final location = await getSaveLocation(
      suggestedName: document.name,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (location == null) return;
    await engine.saveAs(document.workingPath, location.path);
    document.path = location.path;
    document.name = File(location.path).uri.pathSegments.last;
    document.savedRevision = document.revision;
    document.dirty = false;
    notifyListeners();
  }

  void selectAnnotation(String? id) {
    final document = current;
    if (document == null) return;
    document.selectedAnnotationId = id;
    notifyListeners();
  }

  void updateAnnotationDraft(PdfAnnotation annotation) {
    final document = current;
    if (document == null) return;
    final values = [...document.currentAnnotations];
    final index = values.indexWhere((value) => value.id == annotation.id);
    if (index < 0) return;
    values[index] = annotation;
    document.annotations[document.pageIndex] = values;
    notifyListeners();
  }

  Future<void> commitAnnotation(
    PdfAnnotation annotation, {
    String? imagePath,
  }) async {
    final document = current;
    if (document == null) return;
    document.busy = true;
    document.error = null;
    notifyListeners();
    _PdfHistoryEntry? before;
    try {
      before = await _snapshot(document);
      if (annotation.kind == PdfAnnotationKind.image) {
        await engine.upsertImageAnnotation(
          document.workingPath,
          document.workingPath,
          annotation,
          imagePath: imagePath,
        );
      } else {
        await engine.upsertAnnotation(
          document.workingPath,
          document.workingPath,
          annotation,
        );
      }
      _commitMutation(document, before);
      document.selectedAnnotationId = annotation.id;
      document.thumbnails.remove(document.pageIndex);
      await renderCurrent();
    } catch (error) {
      if (before != null) await _restoreFailedMutation(document, before);
      document.error = '$error';
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<void> addText(String contents, PdfTextStyle style) async {
    final document = current;
    if (document == null || contents.trim().isEmpty) return;
    await commitAnnotation(
      PdfAnnotation(
        id: 'azpdf-text-${DateTime.now().microsecondsSinceEpoch}',
        kind: PdfAnnotationKind.freeText,
        pageIndex: document.pageIndex,
        bounds: _centeredBounds(document, width: 260, height: 64),
        contents: contents.trim(),
        textStyle: style,
      ),
    );
  }

  Future<void> addNote(String contents) async {
    final document = current;
    if (document == null || contents.trim().isEmpty) return;
    await commitAnnotation(
      PdfAnnotation(
        id: 'azpdf-note-${DateTime.now().microsecondsSinceEpoch}',
        kind: PdfAnnotationKind.note,
        pageIndex: document.pageIndex,
        bounds: _centeredBounds(document, width: 20, height: 20),
        contents: contents.trim(),
        color: const PdfColor(red: 1, green: 0.82, blue: 0),
      ),
    );
  }

  Future<void> pickAndInsertImage() async {
    final document = current;
    if (document == null) return;
    const imageGroup = XTypeGroup(
      label: 'Ảnh',
      extensions: ['png', 'jpg', 'jpeg'],
      mimeTypes: ['image/png', 'image/jpeg'],
    );
    final selected = await openFile(acceptedTypeGroups: const [imageGroup]);
    if (selected == null) return;
    const width = 180.0;
    const height = 120.0;
    await commitAnnotation(
      PdfAnnotation(
        id: 'azpdf-image-${DateTime.now().microsecondsSinceEpoch}',
        kind: PdfAnnotationKind.image,
        pageIndex: document.pageIndex,
        bounds: _centeredBounds(document, width: width, height: height),
      ),
      imagePath: selected.path,
    );
  }

  Future<void> pickAndReplaceSelectedImage() async {
    final annotation = current?.selectedAnnotation;
    if (annotation == null || annotation.kind != PdfAnnotationKind.image) {
      return;
    }
    const imageGroup = XTypeGroup(
      label: 'Ảnh',
      extensions: ['png', 'jpg', 'jpeg'],
      mimeTypes: ['image/png', 'image/jpeg'],
    );
    final selected = await openFile(acceptedTypeGroups: const [imageGroup]);
    if (selected != null) {
      await commitAnnotation(annotation, imagePath: selected.path);
    }
  }

  Future<void> removeSelectedAnnotation() async {
    final document = current;
    final annotation = document?.selectedAnnotation;
    if (document == null || annotation == null) return;
    document.busy = true;
    notifyListeners();
    _PdfHistoryEntry? before;
    try {
      before = await _snapshot(document);
      await engine.removeAnnotation(
        document.workingPath,
        document.workingPath,
        annotation.pageIndex,
        annotation.id,
      );
      _commitMutation(document, before);
      document.selectedAnnotationId = null;
      document.thumbnails.remove(document.pageIndex);
      await renderCurrent();
    } catch (error) {
      if (before != null) await _restoreFailedMutation(document, before);
      document.error = '$error';
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<void> undo() async {
    final document = current;
    if (document == null || document.busy || !document.canUndo) return;
    await _restoreHistory(document, undo: true);
  }

  Future<void> redo() async {
    final document = current;
    if (document == null || document.busy || !document.canRedo) return;
    await _restoreHistory(document, undo: false);
  }

  Future<void> _restoreHistory(OpenedPdf document, {required bool undo}) async {
    final source = undo ? document._undoStack : document._redoStack;
    final destination = undo ? document._redoStack : document._undoStack;
    final target = source.last;
    final currentSnapshot = await _snapshot(document);
    source.removeLast();
    final previousRevision = document.revision;
    document.busy = true;
    document.error = null;
    notifyListeners();
    try {
      await File(target.path).copy(document.workingPath);
      destination.add(currentSnapshot);
      _trimHistory(destination);
      document.revision = target.revision;
      document.dirty = document.revision != document.savedRevision;
      document.selectedAnnotationId = null;
      document.layoutReview = null;
      document.annotations.clear();
      document.thumbnails.clear();
      _deleteFile(target.path);
      await renderCurrent();
      document.searchMatches = document.searchQuery.isEmpty
          ? const []
          : await engine.search(document.workingPath, document.searchQuery);
    } catch (error) {
      source.add(target);
      document.revision = previousRevision;
      await File(currentSnapshot.path).copy(document.workingPath);
      _deleteFile(currentSnapshot.path);
      document.error = '$error';
    } finally {
      document.busy = false;
      notifyListeners();
    }
  }

  Future<_PdfHistoryEntry> _snapshot(OpenedPdf document) async {
    final path =
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'history-${document.id}-${_historySequence++}.pdf';
    await File(document.workingPath).copy(path);
    return _PdfHistoryEntry(path: path, revision: document.revision);
  }

  void _commitMutation(OpenedPdf document, _PdfHistoryEntry before) {
    document._undoStack.add(before);
    _trimHistory(document._undoStack);
    _deleteHistory(document._redoStack);
    document._redoStack.clear();
    document.revision = _nextRevision++;
    document.dirty = document.revision != document.savedRevision;
    document.layoutReview = null;
  }

  Future<void> _restoreFailedMutation(
    OpenedPdf document,
    _PdfHistoryEntry before,
  ) async {
    try {
      await File(before.path).copy(document.workingPath);
    } finally {
      _deleteFile(before.path);
    }
  }

  void _trimHistory(List<_PdfHistoryEntry> history) {
    while (history.length > _historyLimit) {
      _deleteFile(history.removeAt(0).path);
    }
  }

  void _deleteHistory(List<_PdfHistoryEntry> history) {
    for (final entry in history) {
      _deleteFile(entry.path);
    }
  }

  void _deleteFile(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  PdfBounds _centeredBounds(
    OpenedPdf document, {
    required double width,
    required double height,
  }) {
    final zoom = document.zoom <= 0 ? 1 : document.zoom;
    final geometry =
        document.pageGeometry ??
        PdfPageGeometry(
          pageBox: PdfBounds(
            x: 0,
            y: 0,
            width: (document.renderedWidth ?? 595 * zoom) / zoom,
            height: (document.renderedHeight ?? 842 * zoom) / zoom,
          ),
          rotation: 0,
        );
    return geometry.fromViewport(
      PdfBounds(
        x: (geometry.viewportWidth - width) / 2,
        y: (geometry.viewportHeight - height) / 2,
        width: width,
        height: height,
      ),
    );
  }

  @override
  void dispose() {
    if (cacheDirectory.existsSync()) {
      cacheDirectory.deleteSync(recursive: true);
    }
    super.dispose();
  }
}
