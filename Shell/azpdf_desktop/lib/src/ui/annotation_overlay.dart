// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'package:flutter/material.dart';
import '../controllers/workspace_controller.dart';
import '../models/pdf_models.dart';
import '../l10n/strings.dart';

class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({super.key, 
    required this.controller,
    required this.document,
    required this.annotation,
    required this.pageWidth,
    required this.pageHeight,
  });

  final WorkspaceController controller;
  final OpenedPdf document;
  final PdfAnnotation annotation;
  final double pageWidth;
  final double pageHeight;

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  bool hovered = false;

  PdfAnnotation? get latest {
    for (final value in widget.document.currentAnnotations) {
      if (value.id == widget.annotation.id) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final annotation = widget.annotation;
    final zoom = widget.document.zoom;
    final bounds = annotation.bounds;
    final geometry = _geometry;
    final viewportBounds = geometry.toViewport(bounds);
    final selected = widget.document.selectedAnnotationId == annotation.id;
    final left = viewportBounds.x * zoom;
    final top = viewportBounds.y * zoom;
    final width = viewportBounds.width * zoom;
    final height = viewportBounds.height * zoom;
    final canResize = annotation.kind != PdfAnnotationKind.note;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: selected,
        label: _annotationLabel(annotation),
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.controller.selectAnnotation(annotation.id),
            onDoubleTap: () => editSelectedAnnotation(
              context,
              widget.controller,
              annotation: latest ?? annotation,
),
            onPanStart: (_) =>
                widget.controller.selectAnnotation(annotation.id),
            onPanUpdate: _move,
            onPanEnd: (_) => _commitLatest(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0x160B6BCB)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0B6BCB)
                            : hovered
                            ? const Color(0x996EA8E5)
                            : Colors.transparent,
                        width: selected ? 2 : 1,
),
),
),
),
                if (selected && canResize)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: _resize,
                        onPanEnd: (_) => _commitLatest(),
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B6BCB),
                            border: Border.all(color: Colors.white, width: 2),
                            shape: BoxShape.circle,
),
),
),
),
),
],
),
),
),
),
);
  }

  void _move(DragUpdateDetails details) {
    final current = latest;
    if (current == null) return;
    final zoom = widget.document.zoom;
    final geometry = _geometry;
    final bounds = geometry.toViewport(current.bounds);
    final availableX = geometry.viewportWidth - bounds.width;
    final availableY = geometry.viewportHeight - bounds.height;
    final maximumX = availableX < 0 ? 0.0 : availableX;
    final maximumY = availableY < 0 ? 0.0 : availableY;
    final x = (bounds.x + details.delta.dx / zoom)
        .clamp(0.0, maximumX)
        .toDouble();
    final y = (bounds.y + details.delta.dy / zoom)
        .clamp(0.0, maximumY)
        .toDouble();
    widget.controller.updateAnnotationDraft(
      current.copyWith(
        bounds: geometry.fromViewport(
          PdfBounds(x: x, y: y, width: bounds.width, height: bounds.height),
),
),
);
  }

  void _resize(DragUpdateDetails details) {
    final current = latest;
    if (current == null) return;
    final zoom = widget.document.zoom;
    final geometry = _geometry;
    final bounds = geometry.toViewport(current.bounds);
    final deltaX = details.delta.dx / zoom;
    final deltaY = details.delta.dy / zoom;
    final availableWidth = geometry.viewportWidth - bounds.x;
    final maximumWidth = availableWidth < 1 ? 1.0 : availableWidth;
    final minimumWidth = maximumWidth < 24 ? maximumWidth : 24.0;
    final width = (bounds.width + deltaX)
        .clamp(minimumWidth, maximumWidth)
        .toDouble();
    final availableHeight = geometry.viewportHeight - bounds.y;
    final maximumHeight = availableHeight < 1 ? 1.0 : availableHeight;
    final minimumHeight = maximumHeight < 24 ? maximumHeight : 24.0;
    final height = (bounds.height + deltaY)
        .clamp(minimumHeight, maximumHeight)
        .toDouble();
    widget.controller.updateAnnotationDraft(
      current.copyWith(
        bounds: geometry.fromViewport(
          PdfBounds(x: bounds.x, y: bounds.y, width: width, height: height),
),
),
);
  }

  PdfPageGeometry get _geometry =>
      widget.document.pageGeometry ??
      PdfPageGeometry(
        pageBox: PdfBounds(
          x: 0,
          y: 0,
          width: widget.pageWidth / widget.document.zoom,
          height: widget.pageHeight / widget.document.zoom,
),
        rotation: 0,
);

  void _commitLatest() {
    final annotation = latest;
    if (annotation != null) widget.controller.commitAnnotation(annotation);
  }
}

String _annotationLabel(PdfAnnotation annotation) => switch (annotation.kind) {
  PdfAnnotationKind.freeText => L('text_label', {'text': annotation.contents ?? ''}),
  PdfAnnotationKind.note => L('note_label', {'text': annotation.contents ?? ''}),
  PdfAnnotationKind.image => L('inserted_image'),
  PdfAnnotationKind.unknown => 'Annotation PDF',
};

Future<void> editSelectedAnnotation(
  BuildContext context,
  WorkspaceController controller, {
  PdfAnnotation? annotation,
}) async {
  final selected = annotation ?? controller.current?.selectedAnnotation;
  if (selected == null) return;
  return switch (selected.kind) {
    PdfAnnotationKind.freeText => showTextEditor(
      context,
      controller,
      annotation: selected,
),
    PdfAnnotationKind.note => showNoteEditor(
      context,
      controller,
      annotation: selected,
),
    PdfAnnotationKind.image => controller.pickAndReplaceSelectedImage(),
    PdfAnnotationKind.unknown => Future<void>.value(),
  };
}

Future<void> showTextEditor(
  BuildContext context,
  WorkspaceController controller, {
  PdfAnnotation? annotation,
}) async {
  final textController = TextEditingController(text: annotation?.contents);
  final initialStyle = annotation?.textStyle ?? const PdfTextStyle();
  final fontSizeController = TextEditingController(
    text: initialStyle.fontSize.toStringAsFixed(0),
);
  var alignment = initialStyle.alignment;
  var isBold = initialStyle.isBold;
  var isItalic = initialStyle.isItalic;
  var isUnderline = initialStyle.isUnderline;
  var colorIndex = _colorChoices.indexWhere(
    (color) =>
        (color.red - initialStyle.color.red).abs() < 0.02 &&
        (color.green - initialStyle.color.green).abs() < 0.02 &&
        (color.blue - initialStyle.color.blue).abs() < 0.02,
);
  if (colorIndex < 0) colorIndex = 0;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(annotation == null ? L('insert_text') : L('edit_text_and_format')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration:  InputDecoration(
                  labelText: L('content'),
                  border: OutlineInputBorder(),
),
),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: fontSizeController,
                      keyboardType: TextInputType.number,
                      decoration:  InputDecoration(
                        labelText: L('font_size'),
                        border: OutlineInputBorder(),
),
),
),
                  DropdownButton<PdfTextAlignment>(
                    value: alignment,
                    items:  [
                      DropdownMenuItem(
                        value: PdfTextAlignment.left,
                        child: Text(L('align_left')),
),
                      DropdownMenuItem(
                        value: PdfTextAlignment.center,
                        child: Text(L('align_center')),
),
                      DropdownMenuItem(
                        value: PdfTextAlignment.right,
                        child: Text(L('align_right')),
),
],
                    onChanged: (value) => setDialogState(
                      () => alignment = value ?? PdfTextAlignment.left,
),
),
                  DropdownButton<int>(
                    value: colorIndex,
                    items: List.generate(
                      _colorChoices.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              color: _flutterColor(_colorChoices[index]),
),
                            const SizedBox(width: 7),
                            Text(_colorNames[index]),
],
),
),
),
                    onChanged: (value) =>
                        setDialogState(() => colorIndex = value ?? 0),
),
                  FilterChip(
                    label: const Text('B'),
                    selected: isBold,
                    onSelected: (value) => setDialogState(() => isBold = value),
),
                  FilterChip(
                    label: const Text('I'),
                    selected: isItalic,
                    onSelected: (value) =>
                        setDialogState(() => isItalic = value),
),
                  FilterChip(
                    label: const Text('U'),
                    selected: isUnderline,
                    onSelected: (value) =>
                        setDialogState(() => isUnderline = value),
),
],
),
              const SizedBox(height: 10),
               Text(
                L('after_insert_hint'),
                style: TextStyle(fontSize: 12, color: Color(0xFF5D6B7D)),
),
],
),
),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:  Text(L('cancel')),
),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child:  Text(L('apply')),
),
],
),
),
);
  if (accepted == true && textController.text.trim().isNotEmpty) {
    final fontSize = double.tryParse(fontSizeController.text) ?? 14;
    final style = PdfTextStyle(
      fontSize: fontSize.clamp(6, 144).toDouble(),
      color: _colorChoices[colorIndex],
      alignment: alignment,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
);
    if (annotation == null) {
      await controller.addText(textController.text, style);
    } else {
      await controller.commitAnnotation(
        annotation.copyWith(
          contents: textController.text.trim(),
          textStyle: style,
),
);
    }
  }
  textController.dispose();
  fontSizeController.dispose();
}

Future<void> showNoteEditor(
  BuildContext context,
  WorkspaceController controller, {
  PdfAnnotation? annotation,
}) async {
  final textController = TextEditingController(text: annotation?.contents);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(annotation == null ? L('insert_note') : L('edit_note')),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: textController,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration:  InputDecoration(
            labelText: L('note_content'),
            border: OutlineInputBorder(),
),
),
),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:  Text(L('cancel')),
),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child:  Text(L('apply')),
),
],
),
);
  if (accepted == true && textController.text.trim().isNotEmpty) {
    if (annotation == null) {
      await controller.addNote(textController.text);
    } else {
      await controller.commitAnnotation(
        annotation.copyWith(contents: textController.text.trim()),
);
    }
  }
  textController.dispose();
}

const _colorChoices = [
  PdfColor(red: 0, green: 0, blue: 0),
  PdfColor(red: 0.05, green: 0.37, blue: 0.72),
  PdfColor(red: 0.78, green: 0.12, blue: 0.14),
  PdfColor(red: 0.08, green: 0.5, blue: 0.22),
];

final _colorNames = [L('black'), L('blue'), L('red'), L('green')];

Color _flutterColor(PdfColor color) => Color.fromRGBO(
  (color.red * 255).round(),
  (color.green * 255).round(),
  (color.blue * 255).round(),
  color.alpha,
);

