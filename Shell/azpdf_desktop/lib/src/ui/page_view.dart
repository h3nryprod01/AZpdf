// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/workspace_controller.dart';
import '../l10n/strings.dart';
import 'annotation_overlay.dart';

class PageSidebar extends StatelessWidget {
  const PageSidebar({super.key, required this.controller, required this.document});

  final WorkspaceController controller;
  final OpenedPdf document;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFD),
        border: Border(right: BorderSide(color: Color(0xFFD9E0EA))),
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 13, 12, 9),
            child: Text(
              'TRANG',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0xFF65758B),
),
),
),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              itemCount: document.info.pageCount,
              itemBuilder: (context, page) => ThumbnailTile(
                controller: controller,
                document: document,
                page: page,
),
),
),
],
),
);
  }
}

class ThumbnailTile extends StatefulWidget {
  const ThumbnailTile({super.key, 
    required this.controller,
    required this.document,
    required this.page,
  });

  final WorkspaceController controller;
  final OpenedPdf document;
  final int page;

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile> {
  late final Future<String?> thumbnail = widget.controller.thumbnailFor(
    widget.document,
    widget.page,
);

  @override
  Widget build(BuildContext context) {
    final selected = widget.page == widget.document.pageIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Trang ${widget.page + 1}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.controller.goToPage(widget.page),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4F0FC) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF5A9BDD) : Colors.transparent,
),
),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 86,
                color: Colors.white,
                child: FutureBuilder<String?>(
                  future: thumbnail,
                  builder: (context, snapshot) => snapshot.hasData
                      ? Image.file(
                          File(snapshot.data!),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
)
                      : const Center(
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
),
),
),
),
              const SizedBox(width: 10),
              Text(
                '${widget.page + 1}',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
),
),
],
),
),
),
);
  }
}

class PageCanvas extends StatefulWidget {
  const PageCanvas({super.key, required this.controller, required this.document});

  final WorkspaceController controller;
  final OpenedPdf document;

  @override
  State<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends State<PageCanvas> {
  /// Lề quanh trang. Chế độ khớp khung phải trừ đúng con số này, nếu không
  /// "fit width" sẽ tràn ra ngoài đúng bằng hai lần lề.
  static const double _pageMargin = 32;

  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  bool _zoomModifierHeld = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_trackZoomModifier);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_trackZoomModifier);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// Cuộn và phóng dùng CHUNG một sự kiện con lăn, nên phải chọn ai được nhận.
  ///
  /// Không thể để `Listener` bên ngoài giành: Flutter phân xử bằng
  /// `PointerSignalResolver`, và bên trong đăng ký trước — `Scrollable` nằm
  /// trong `Listener` nên luôn thắng. Cách còn lại là tắt hẳn cuộn khi giữ
  /// Ctrl, và muốn vậy thì phải biết Ctrl đang giữ hay không.
  bool _trackZoomModifier(KeyEvent event) {
    final held = HardwareKeyboard.instance.isControlPressed;
    if (held != _zoomModifierHeld && mounted) {
      setState(() => _zoomModifierHeld = held);
    }
    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_zoomModifierHeld) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    // Mỗi nấc con lăn là một lần gọi engine render lại; bỏ qua khi đang bận
    // để một cú xoay dài không xếp hàng chục tiến trình mutool chồng lên nhau.
    if (widget.document.busy) return;
    widget.controller.changeZoom(
      widget.document.zoom + (delta < 0 ? 0.25 : -0.25),
);
  }

  /// Mức phóng để trang vừa khung, hoặc null nếu người dùng đang tự lái.
  double? _fitZoom(BoxConstraints constraints) {
    final document = widget.document;
    if (document.fitMode == PdfFitMode.free) return null;
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return null;
    }
    final widthPoints = document.pageWidthPoints;
    final heightPoints = document.pageHeightPoints;
    if (widthPoints == null ||
        heightPoints == null ||
        widthPoints <= 0 ||
        heightPoints <= 0) {
      return null;
    }
    final availableWidth = constraints.maxWidth - _pageMargin * 2;
    final availableHeight = constraints.maxHeight - _pageMargin * 2;
    if (availableWidth <= 0 || availableHeight <= 0) return null;
    return switch (document.fitMode) {
      PdfFitMode.free => null,
      PdfFitMode.width => availableWidth / widthPoints,
      PdfFitMode.page => math.min(
        availableWidth / widthPoints,
        availableHeight / heightPoints,
),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final document = widget.document;
    return ColoredBox(
      color: const Color(0xFFDDE2E9),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_fitZoom(constraints) case final target?) {
                  final clamped = target.clamp(0.25, 4).toDouble();
                  if ((clamped - document.zoom).abs() > 0.005) {
                    final mode = document.fitMode;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) controller.changeZoom(clamped, fitMode: mode);
                    });
                  }
                }
                // Ctrl đang giữ thì khoá cuộn, để sự kiện con lăn rơi xuống
                // `_handlePointerSignal` thay vì bị Scrollable nuốt.
                final physics = _zoomModifierHeld
                    ? const NeverScrollableScrollPhysics()
                    : null;
                // Không tự bọc Scrollbar: trên desktop ScrollBehavior của
                // Material đã gắn sẵn cho mỗi Scrollable, bọc thêm là ra hai
                // thanh cuộn chồng nhau.
                return Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: SingleChildScrollView(
                    controller: _vertical,
                    physics: physics,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      physics: physics,
                      child: ConstrainedBox(
                        // Ép nội dung rộng/cao tối thiểu bằng khung nhìn thì
                        // `Center` mới có chỗ để căn giữa lúc trang nhỏ hơn.
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
),
                        child: Center(
                          child: document.renderedPath == null
                              ? const SizedBox.shrink()
                              : Container(
                                  margin: const EdgeInsets.all(_pageMargin),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x42000000),
                                        blurRadius: 18,
                                        offset: Offset(0, 6),
),
],
),
                                  child: EditablePage(
                                    controller: controller,
                                    document: document,
),
),
),
),
),
),
);
              },
),
),
          if (document.busy)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
),
          if (document.error case final error?)
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Material(
                color: const Color(0xFFFFE6E6),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error,
                    style: const TextStyle(color: Color(0xFF8B1A1A)),
),
),
),
),
],
),
);
  }
}

class EditablePage extends StatelessWidget {
  const EditablePage({super.key, required this.controller, required this.document});

  final WorkspaceController controller;
  final OpenedPdf document;

  @override
  Widget build(BuildContext context) {
    // logical pixel = point × zoom, KHÔNG phải số pixel của ảnh: ảnh được
    // render dày hơn theo devicePixelRatio nên hai con số đó không còn bằng
    // nhau. Lấy nhầm `renderedWidth` là trang to gấp dpr lần.
    final width = document.layoutWidth;
    final height = document.layoutHeight;
    if (width == null || height == null || document.renderedPath == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      image: true,
      label: L('page_content', {'page': document.pageIndex + 1}),
      child: GestureDetector(
        onTap: () => controller.selectAnnotation(null),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.file(
                  File(document.renderedPath!),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  // Ảnh giờ có nhiều pixel hơn ô layout, tức luôn là phép thu
                  // nhỏ. `low` (bilinear) lấy mẫu một lần nên làm răng cưa chữ;
                  // `medium` dùng mipmap, đây đúng là ca nó sinh ra để giải.
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, error, _) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('$error'),
),
),
),
              for (final annotation in document.currentAnnotations)
                AnnotationOverlay(
                  controller: controller,
                  document: document,
                  annotation: annotation,
                  pageWidth: width,
                  pageHeight: height,
),
],
),
),
),
);
  }
}

