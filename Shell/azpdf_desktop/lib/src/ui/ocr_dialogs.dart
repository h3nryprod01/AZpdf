// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/workspace_controller.dart';
import '../models/pdf_models.dart';
import '../l10n/strings.dart';

class OcrOptions {
  const OcrOptions({
    required this.language,
    required this.deskew,
    required this.rotatePages,
  });

  final String language;
  final bool deskew;
  final bool rotatePages;
}

Future<void> showLayoutReviewDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  final ir = await controller.analyzeCurrentLayout();
  if (!context.mounted) return;
  final document = controller.current;
  if (ir == null || document == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text(L('cannot_review_layout')),
        content: Text(
          document?.error ?? L('engine_bad_ir'),
),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L('close')),
),
],
),
);
    return;
  }

  DocumentIrPage? page;
  for (final candidate in ir.pages) {
    if (candidate.index == document.pageIndex) {
      page = candidate;
      break;
    }
  }
  if (page == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text(L('ir_missing_page')),
        content: Text(L('page_not_found', {'page': document.pageIndex + 1})),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L('close')),
),
],
),
);
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) =>
        LayoutReviewDialog(document: document, ir: ir, page: page!),
);
}

class LayoutReviewDialog extends StatefulWidget {
  const LayoutReviewDialog({super.key, 
    required this.document,
    required this.ir,
    required this.page,
  });

  final OpenedPdf document;
  final DocumentIr ir;
  final DocumentIrPage page;

  @override
  State<LayoutReviewDialog> createState() => _LayoutReviewDialogState();
}

class _LayoutReviewDialogState extends State<LayoutReviewDialog> {
  String? selectedBlockId;

  @override
  void initState() {
    super.initState();
    if (widget.page.orderedBlocks.isNotEmpty) {
      selectedBlockId = widget.page.orderedBlocks.first.id;
    }
  }

  DocumentIrBlock? get selectedBlock {
    for (final block in widget.page.blocks) {
      if (block.id == selectedBlockId) return block;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = (viewport.width - 48).clamp(680.0, 1120.0);
    final height = (viewport.height - 48).clamp(500.0, 760.0);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              color: const Color(0xFFF4F7FB),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFF0B2554),
),
                  const SizedBox(width: 10),
                   Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L('review_layout'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
),
),
                        Text(
                          L('ir_coords'),
                          style: TextStyle(color: Color(0xFF5F6F83)),
),
],
),
),
                  IconButton(
                    tooltip: L('close_layout_review'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
),
],
),
),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: width < 840 ? 270 : 330,
                    child: _readingOrderList(),
),
                  const VerticalDivider(width: 1),
                  Expanded(child: _preview()),
],
),
),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.ir.providerId}'
                      '${widget.ir.modelId == null ? '' : ' · ${widget.ir.modelId}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF5F6F83)),
),
),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label:  Text(L('copy_in_reading_order')),
                    onPressed: widget.ir.plainText.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.ir.plainText),
);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                content: Text(
                                  L('ir_text_copied'),
),
),
);
                          },
),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child:  Text(L('close')),
),
],
),
),
],
),
),
);
  }

  Widget _readingOrderList() {
    final blocks = widget.page.orderedBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Text(
            'READING ORDER · ${blocks.length} BLOCK',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF65758B),
),
),
),
        Expanded(
          child: blocks.isEmpty
              ?  Center(child: Text(L('no_layout_blocks')))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final selected = block.id == selectedBlockId;
                    final text = block.plainText.trim();
                    return Semantics(
                      button: true,
                      selected: selected,
                      label:
                          'Block ${index + 1}, ${_documentIrKindLabel(block.kind)}',
                      child: ListTile(
                        key: ValueKey('document-ir-block-${block.id}'),
                        selected: selected,
                        selectedTileColor: const Color(0xFFE6F1FD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF0078D4)
                                : Colors.transparent,
),
),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: _documentIrKindColor(block.kind),
                          foregroundColor: Colors.white,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 11),
),
),
                        title: Text(_documentIrKindLabel(block.kind)),
                        subtitle: Text(
                          text.isEmpty ? L('no_text') : text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
),
                        trailing: block.confidence == null
                            ? null
                            : Text('${(block.confidence! * 100).round()}%'),
                        onTap: () => setState(() => selectedBlockId = block.id),
),
);
                  },
),
),
],
);
  }

  Widget _preview() {
    final block = selectedBlock;
    final isBaseline = widget.ir.providerId == 'org.azpdf.mupdf-stext';
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isBaseline
                  ? const Color(0xFFFFF7E6)
                  : const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(8),
),
            child: Text(
              isBaseline
                  ? L('mupdf_baseline_desc') +
                        L('tables_need_advanced')
                  : L('structured_ocr_desc'),
              style: TextStyle(
                color: isBaseline
                    ? const Color(0xFF795400)
                    : const Color(0xFF16633E),
),
),
),
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3EC),
                borderRadius: BorderRadius.circular(8),
),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: widget.page.width,
                      height: widget.page.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.document.renderedPath case final path?)
                            Image.file(
                              File(path),
                              fit: BoxFit.fill,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Colors.white),
)
                          else
                            const ColoredBox(color: Colors.white),
                          ...widget.page.blocks.map(_blockOverlay),
],
),
),
),
),
),
),
),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E0EA)),
),
            child: block == null
                ?  Text(L('select_block'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_documentIrKindLabel(block.kind)} · ${block.id}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
),
                      Text(
                        'x ${block.bounds.x.toStringAsFixed(1)} · '
                        'y ${block.bounds.y.toStringAsFixed(1)} · '
                        'w ${block.bounds.width.toStringAsFixed(1)} · '
                        'h ${block.bounds.height.toStringAsFixed(1)}'
                        '${block.confidence == null ? '' : ' · ${(block.confidence! * 100).round()}%'}',
                        style: const TextStyle(color: Color(0xFF5F6F83)),
),
],
),
),
],
),
);
  }

  Widget _blockOverlay(DocumentIrBlock block) {
    final left = block.bounds.x.clamp(0, widget.page.width).toDouble();
    final top = block.bounds.y.clamp(0, widget.page.height).toDouble();
    final maximumWidth = (widget.page.width - left)
        .clamp(1, widget.page.width)
        .toDouble();
    final maximumHeight = (widget.page.height - top)
        .clamp(1, widget.page.height)
        .toDouble();
    final width = block.bounds.width.clamp(1, maximumWidth).toDouble();
    final height = block.bounds.height.clamp(1, maximumHeight).toDouble();
    final selected = block.id == selectedBlockId;
    final color = _documentIrKindColor(block.kind);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: selected,
        label: L('region_of_kind', {'kind': _documentIrKindLabel(block.kind)}),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => selectedBlockId = block.id),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.22 : 0.09),
              border: Border.all(color: color, width: selected ? 3 : 1.5),
),
),
),
),
);
  }
}

String _documentIrKindLabel(DocumentIrBlockKind kind) => switch (kind) {
  DocumentIrBlockKind.paragraph => L('paragraph'),
  DocumentIrBlockKind.heading => L('heading'),
  DocumentIrBlockKind.listItem => L('list_item'),
  DocumentIrBlockKind.table => L('table'),
  DocumentIrBlockKind.formula => L('formula'),
  DocumentIrBlockKind.figure => L('figure'),
  DocumentIrBlockKind.caption => L('caption'),
  DocumentIrBlockKind.header => L('header'),
  DocumentIrBlockKind.footer => L('footer'),
  DocumentIrBlockKind.footnote => L('footnote'),
  DocumentIrBlockKind.pageNumber => L('page_number'),
  DocumentIrBlockKind.unknown => L('unclassified'),
};

Color _documentIrKindColor(DocumentIrBlockKind kind) => switch (kind) {
  DocumentIrBlockKind.heading => const Color(0xFF6F42C1),
  DocumentIrBlockKind.table => const Color(0xFF0F7B6C),
  DocumentIrBlockKind.formula => const Color(0xFFC35300),
  DocumentIrBlockKind.figure => const Color(0xFFB3261E),
  DocumentIrBlockKind.caption => const Color(0xFF8A5A00),
  DocumentIrBlockKind.header ||
  DocumentIrBlockKind.footer ||
  DocumentIrBlockKind.pageNumber => const Color(0xFF5F6F83),
  _ => const Color(0xFF0078D4),
};

Future<void> showOcrDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  late PdfOcrHealth health;
  try {
    health = await controller.ocrHealth();
  } catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text(L('ocr_not_ready')),
        content: Text(
          L('ocr_install_hint', {'error': error}),
),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L('close')),
),
],
),
);
    return;
  }
  if (!context.mounted) return;

  var language = 'vie+eng';
  var deskew = false;
  var rotatePages = false;
  final options = await showDialog<OcrOptions>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title:  Text(L('ocr_whole_document')),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  L('processed_fully_locally', {'provider': health.provider, 'version': health.version}),
),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration:  InputDecoration(
                    labelText: L('recognition_language'),
                    border: OutlineInputBorder(),
),
                  items:  [
                    DropdownMenuItem(
                      value: 'vie+eng',
                      child: Text(L('lang_vi_en_name')),
),
                    DropdownMenuItem(value: 'vie', child: Text(L('lang_vi_name'))),
                    DropdownMenuItem(value: 'eng', child: Text('English')),
],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => language = value);
                  },
),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title:  Text(L('deskew')),
                  subtitle:  Text(L('deskew_hint')),
                  value: deskew,
                  onChanged: (value) => setDialogState(() => deskew = value),
),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title:  Text(L('auto_detect_orientation')),
                  subtitle:  Text(L('rotate_when_confident')),
                  value: rotatePages,
                  onChanged: (value) =>
                      setDialogState(() => rotatePages = value),
),
                const SizedBox(height: 8),
                Text(
                  health.preservesVisualLayout
                      ? L('ocr_keeps_layout')
                      : L('provider_no_layout_promise'),
                  style: const TextStyle(color: Color(0xFF46576C)),
),
                if (!health.supportsStructuredLayout) ...[
                  const SizedBox(height: 8),
                   Text(
                    L('baseline_no_table_semantics'),
                    style: TextStyle(color: Color(0xFF8A5A00)),
),
],
],
),
),
),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L('cancel')),
),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label:  Text(L('start_ocr')),
            onPressed: () => Navigator.pop(
              context,
              OcrOptions(
                language: language,
                deskew: deskew,
                rotatePages: rotatePages,
),
),
),
],
),
),
);
  if (!context.mounted || options == null) return;
  final result = await controller.applyOcr(
    language: options.language,
    deskew: options.deskew,
    rotatePages: options.rotatePages,
);
  if (!context.mounted || result == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        L('ocr_complete', {'provider': result.provider, 'version': result.version}),
),
),
);
}

