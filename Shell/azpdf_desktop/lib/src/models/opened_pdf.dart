// Tách từ workspace_controller.dart 2026-08-17: OpenedPdf là MODEL (trạng thái một tài liệu
// đang mở + lịch sử undo/redo), nằm nhờ trong file controller từ đầu. PdfHistoryEntry public
// vì controller (bên kia ranh giới file) thao tác trực tiếp undo/redo stack.
import 'dart:io';

import 'pdf_models.dart';

class PdfHistoryEntry {
  const PdfHistoryEntry({required this.path, required this.revision});

  final String path;
  final int revision;
}

/// Cách khớp trang vào khung nhìn.
///
/// `free` là người dùng tự đặt mức phóng; hai chế độ còn lại tính lại `zoom`
/// mỗi khi khung nhìn đổi kích thước, nên kéo cửa sổ vẫn giữ đúng tỉ lệ.
enum PdfFitMode { free, width, page }

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
  PdfFitMode fitMode = PdfFitMode.free;
  bool busy = false;
  String? renderedPath;

  /// Mức phóng THẬT đã gửi cho engine ở lần render gần nhất. Không bằng `zoom`:
  /// nó là `zoom * devicePixelRatio`, vì ảnh phải có đủ pixel VẬT LÝ cho màn
  /// hình. Giữ lại ở đây để quy ngược ra kích thước point.
  double renderScale = 1;

  /// Kích thước ảnh PNG, tính bằng PIXEL — không phải logical pixel. Trên màn
  /// 150% hai con số này lớn gấp 1,5 lần ô layout.
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
  // Public vì controller sở hữu logic undo/redo và thao tác trực tiếp hai stack này —
  // trước khi tách file, chúng là _private trong cùng library nên ranh giới không lộ ra.
  final List<PdfHistoryEntry> undoStack = [];
  final List<PdfHistoryEntry> redoStack = [];
  int revision = 0;
  int savedRevision = 0;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  /// Bề ngang trang tính bằng point (1/72 inch), quy ngược từ ảnh đã render.
  double? get pageWidthPoints {
    final width = renderedWidth;
    if (width == null || renderScale <= 0) return null;
    return width / renderScale;
  }

  double? get pageHeightPoints {
    final height = renderedHeight;
    if (height == null || renderScale <= 0) return null;
    return height / renderScale;
  }

  /// Kích thước vẽ ra màn hình, tính bằng logical pixel: point × zoom.
  ///
  /// Cố ý KHÔNG dùng thẳng `renderedWidth` như bản trước. Từ khi render theo
  /// devicePixelRatio, ảnh có nhiều pixel hơn ô layout, nên lấy nhầm số đó sẽ
  /// phóng trang to gấp dpr lần. Lớp phủ annotation cũng đặt theo `point × zoom`
  /// (`_AnnotationOverlay`), nên hai bên phải cùng một hệ quy chiếu.
  double? get layoutWidth {
    final points = pageWidthPoints;
    return points == null ? null : points * zoom;
  }

  double? get layoutHeight {
    final points = pageHeightPoints;
    return points == null ? null : points * zoom;
  }

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

