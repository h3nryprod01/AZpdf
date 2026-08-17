// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/workspace_controller.dart';
import '../l10n/strings.dart';
import 'annotation_overlay.dart';
import 'ocr_dialogs.dart';
import 'signing_dialogs.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({super.key, 
    required this.controller,
    required this.searchController,
    required this.searchFocus,
  });

  final WorkspaceController controller;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context) {
    final document = controller.current;
    return Material(
      color: Colors.white,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD9E0EA))),
),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text(
                  'AZpdf',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2554),
),
),
),
              ToolButton(
                icon: Icons.folder_open_rounded,
                tooltip: L('open_pdf_shortcut'),
                onPressed: controller.pickAndOpen,
),
              ToolButton(
                icon: Icons.save_rounded,
                tooltip: L('save_shortcut'),
                onPressed: document == null ? null : controller.save,
),
              ToolButton(
                icon: Icons.save_as_rounded,
                tooltip: L('save_as_shortcut'),
                onPressed: document == null ? null : controller.saveAs,
),
              ToolButton(
                icon: Icons.undo_rounded,
                tooltip: L('undo_shortcut'),
                onPressed: document?.canUndo == true ? controller.undo : null,
),
              ToolButton(
                icon: Icons.redo_rounded,
                tooltip: L('redo_shortcut'),
                onPressed: document?.canRedo == true ? controller.redo : null,
),
              const ToolbarDivider(),
              ToolButton(
                icon: Icons.text_fields_rounded,
                tooltip: L('insert_text_hint'),
                onPressed: document == null
                    ? null
                    : () => showTextEditor(context, controller),
),
              ToolButton(
                icon: Icons.sticky_note_2_outlined,
                tooltip: L('insert_note_hint'),
                onPressed: document == null
                    ? null
                    : () => showNoteEditor(context, controller),
),
              ToolButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: L('insert_image_hint'),
                onPressed: document == null
                    ? null
                    : controller.pickAndInsertImage,
),
              ToolButton(
                icon: Icons.document_scanner_outlined,
                tooltip: L('ocr_local_hint'),
                onPressed: document == null || document.busy
                    ? null
                    : () => showOcrDialog(context, controller),
),
              ToolButton(
                icon: Icons.account_tree_outlined,
                tooltip: L('review_layout'),
                onPressed: document == null || document.busy
                    ? null
                    : () => showLayoutReviewDialog(context, controller),
),
              ToolButton(
                icon: Icons.draw_outlined,
                tooltip: L('pades_sign_with_pkcs12'),
                onPressed: document == null || document.busy
                    ? null
                    : () => showPadesSigningDialog(context, controller),
),
              ToolButton(
                icon: Icons.verified_user_outlined,
                tooltip: L('verify_pades_integrity'),
                onPressed: document == null || document.busy
                    ? null
                    : () =>
                          showSignatureVerificationDialog(context, controller),
),
              ToolButton(
                icon: Icons.tune_rounded,
                tooltip: L('edit_selected_hint'),
                onPressed: document?.selectedAnnotation == null
                    ? null
                    : () => editSelectedAnnotation(context, controller),
),
              ToolButton(
                icon: Icons.delete_outline_rounded,
                tooltip: L('delete_selected'),
                onPressed: document?.selectedAnnotation == null
                    ? null
                    : controller.removeSelectedAnnotation,
),
              const ToolbarDivider(),
              ToolButton(
                icon: Icons.view_sidebar_rounded,
                tooltip: L('toggle_page_list'),
                selected: controller.sidebarVisible,
                onPressed: document == null ? null : controller.toggleSidebar,
),
              ToolButton(
                icon: Icons.chevron_left_rounded,
                tooltip: L('previous_page_shortcut'),
                onPressed: document == null || document.pageIndex == 0
                    ? null
                    : () => controller.goToPage(document.pageIndex - 1),
),
              if (document != null)
                Semantics(
                  label:
                      L('page_x_of_y', {'page': document.pageIndex + 1, 'total': document.info.pageCount}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${document.pageIndex + 1} / ${document.info.pageCount}',
),
),
),
              ToolButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Trang sau (Page Down)',
                onPressed:
                    document == null ||
                        document.pageIndex >= document.info.pageCount - 1
                    ? null
                    : () => controller.goToPage(document.pageIndex + 1),
),
              const ToolbarDivider(),
              ToolButton(
                icon: Icons.remove_rounded,
                tooltip: L('zoom_out_shortcut'),
                onPressed: document == null
                    ? null
                    : () => controller.changeZoom(document.zoom - 0.25),
),
              SizedBox(
                width: 54,
                child: Center(
                  child: Text(
                    document == null
                        ? '—'
                        : '${(document.zoom * 100).round()}%',
),
),
),
              ToolButton(
                icon: Icons.add_rounded,
                tooltip: L('zoom_in_shortcut'),
                onPressed: document == null
                    ? null
                    : () => controller.changeZoom(document.zoom + 0.25),
),
              ToolButton(
                icon: Icons.compare_arrows_rounded,
                tooltip: L('fit_width'),
                selected: document?.fitMode == PdfFitMode.width,
                onPressed: document == null
                    ? null
                    : () => controller.setFitMode(PdfFitMode.width),
),
              ToolButton(
                icon: Icons.crop_free_rounded,
                tooltip: L('fit_page'),
                selected: document?.fitMode == PdfFitMode.page,
                onPressed: document == null
                    ? null
                    : () => controller.setFitMode(PdfFitMode.page),
),
              const SizedBox(width: 18),
              SizedBox(
                width: 230,
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocus,
                  enabled: document != null,
                  onSubmitted: controller.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: L('find_in_document'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixText: document == null || document.searchQuery.isEmpty
                        ? null
                        : '${document.searchMatches.length}',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
),
),
),
),
              const SizedBox(width: 8),
              const LanguageButton(),
              ToolButton(
                icon: Icons.local_cafe_rounded,
                tooltip: L('support_kofi'),
                onPressed: () => launchUrl(
                  Uri.parse('https://ko-fi.com/h3nryng'),
                  mode: LaunchMode.externalApplication,
),
),
],
),
),
),
);
  }
}

class ToolButton extends StatelessWidget {
  const ToolButton({super.key, 
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    tooltip: tooltip,
    isSelected: selected,
    style: selected
        ? IconButton.styleFrom(
            backgroundColor: const Color(0xFFE2EEFB),
            foregroundColor: const Color(0xFF075EA8),
)
        : null,
    onPressed: onPressed,
);
}

class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 28, child: VerticalDivider(width: 14));
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      tooltip: L('language'),
      icon: const Icon(Icons.translate_rounded, size: 20),
      initialValue: AppStrings.language.value,
      onSelected: AppStrings.save,
      itemBuilder: (context) => const [
        PopupMenuItem(value: AppLanguage.system, child: Text('System')),
        PopupMenuItem(value: AppLanguage.english, child: Text('English')),
        PopupMenuItem(
          value: AppLanguage.vietnamese,
          child: Text('Tiếng Việt'), // i18n-exempt: tên ngôn ngữ, không dịch
        ),
],
);
  }
}
