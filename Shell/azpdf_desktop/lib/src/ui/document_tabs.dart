// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'package:flutter/material.dart';
import '../controllers/workspace_controller.dart';
import '../l10n/strings.dart';

class DocumentTabs extends StatelessWidget {
  const DocumentTabs({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFF8FAFD),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.documents.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final document = controller.documents[index];
                final selected = index == controller.selectedIndex;
                return Semantics(
                  selected: selected,
                  button: true,
                  label: L('document_named', {'name': document.name}),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => controller.selectDocument(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      constraints: const BoxConstraints(
                        minWidth: 150,
                        maxWidth: 270,
),
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFEFF3F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF6EA8E5)
                              : const Color(0xFFD4DCE7),
                          width: selected ? 1.5 : 1,
),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x140B2554),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
),
]
                            : null,
),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 17,
                            color: Color(0xFFD64045),
),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              document.dirty
                                  ? '${document.name} •'
                                  : document.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
),
),
),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: L('close_named', {'name': document.name}),
                            onPressed: () => requestCloseDocument(
                              context,
                              controller,
                              index,
),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 32,
),
),
],
),
),
),
);
              },
),
),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: L('open_new_document'),
            onPressed: controller.pickAndOpen,
),
],
),
);
  }
}

enum CloseChoice { save, discard, cancel }

Future<void> requestCloseDocument(
  BuildContext context,
  WorkspaceController controller,
  int index,
) async {
  if (index < 0 || index >= controller.documents.length) return;
  final document = controller.documents[index];
  if (!document.dirty) {
    controller.closeDocument(index);
    return;
  }

  final choice = await showDialog<CloseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title:  Text(L('save_changes_q')),
      content: Text(L('named_has_unsaved', {'name': document.name})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, CloseChoice.cancel),
          child:  Text(L('cancel')),
),
        TextButton(
          onPressed: () => Navigator.pop(context, CloseChoice.discard),
          child:  Text(L('dont_save')),
),
        FilledButton(
          onPressed: () => Navigator.pop(context, CloseChoice.save),
          child:  Text(L('save')),
),
],
),
);
  if (!context.mounted || choice == null || choice == CloseChoice.cancel) {
    return;
  }
  if (choice == CloseChoice.save && !await controller.saveDocument(index)) {
    return;
  }
  controller.closeDocument(index);
}

