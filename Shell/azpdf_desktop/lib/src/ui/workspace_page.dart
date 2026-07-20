import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/workspace_controller.dart';
import '../models/pdf_models.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.controller,
    this.ownsController = false,
    this.initialPaths = const [],
  });

  final WorkspaceController controller;
  final bool ownsController;
  final List<String> initialPaths;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> with WindowListener {
  final searchController = TextEditingController();
  final searchFocus = FocusNode(debugLabel: 'PDF search');
  bool _handlingWindowClose = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initialize();
  }

  @override
  Future<void> onWindowClose() async {
    if (_handlingWindowClose || !mounted) return;
    _handlingWindowClose = true;
    try {
      final dirtyCount = widget.controller.documents
          .where((document) => document.dirty)
          .length;
      if (dirtyCount == 0) {
        await windowManager.destroy();
        return;
      }
      final choice = await showDialog<_CloseChoice>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Lưu trước khi thoát?'),
          content: Text('Có $dirtyCount tài liệu chứa thay đổi chưa được lưu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _CloseChoice.cancel),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _CloseChoice.discard),
              child: const Text('Không lưu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _CloseChoice.save),
              child: const Text('Lưu tất cả'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == _CloseChoice.cancel) return;
      if (choice == _CloseChoice.save) {
        for (
          var index = 0;
          index < widget.controller.documents.length;
          index++
        ) {
          if (widget.controller.documents[index].dirty &&
              !await widget.controller.saveDocument(index)) {
            return;
          }
        }
      }
      await windowManager.destroy();
    } finally {
      _handlingWindowClose = false;
    }
  }

  Future<void> _initialize() async {
    await widget.controller.initialize();
    for (final path in widget.initialPaths) {
      await widget.controller.openPath(path);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    searchController.dispose();
    searchFocus.dispose();
    if (widget.ownsController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyO, control: true):
              _OpenIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _SaveIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
              _SaveAsIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              _UndoIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
              _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyY, control: true):
              _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _FindIntent(),
          SingleActivator(LogicalKeyboardKey.pageUp): _PreviousPageIntent(),
          SingleActivator(LogicalKeyboardKey.pageDown): _NextPageIntent(),
          SingleActivator(LogicalKeyboardKey.equal, control: true):
              _ZoomInIntent(),
          SingleActivator(LogicalKeyboardKey.minus, control: true):
              _ZoomOutIntent(),
        },
        child: Actions(
          actions: {
            _OpenIntent: CallbackAction<_OpenIntent>(
              onInvoke: (_) => widget.controller.pickAndOpen(),
            ),
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) => widget.controller.save(),
            ),
            _SaveAsIntent: CallbackAction<_SaveAsIntent>(
              onInvoke: (_) => widget.controller.saveAs(),
            ),
            _UndoIntent: CallbackAction<_UndoIntent>(
              onInvoke: (_) => widget.controller.undo(),
            ),
            _RedoIntent: CallbackAction<_RedoIntent>(
              onInvoke: (_) => widget.controller.redo(),
            ),
            _FindIntent: CallbackAction<_FindIntent>(
              onInvoke: (_) => searchFocus.requestFocus(),
            ),
            _PreviousPageIntent: CallbackAction<_PreviousPageIntent>(
              onInvoke: (_) => widget.controller.goToPage(
                (widget.controller.current?.pageIndex ?? 0) - 1,
              ),
            ),
            _NextPageIntent: CallbackAction<_NextPageIntent>(
              onInvoke: (_) => widget.controller.goToPage(
                (widget.controller.current?.pageIndex ?? -1) + 1,
              ),
            ),
            _ZoomInIntent: CallbackAction<_ZoomInIntent>(
              onInvoke: (_) => widget.controller.changeZoom(
                (widget.controller.current?.zoom ?? 1) + 0.25,
              ),
            ),
            _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
              onInvoke: (_) => widget.controller.changeZoom(
                (widget.controller.current?.zoom ?? 1) - 0.25,
              ),
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Toolbar(
                      controller: widget.controller,
                      searchController: searchController,
                      searchFocus: searchFocus,
                    ),
                    _DocumentTabs(controller: widget.controller),
                    Expanded(child: _workspace()),
                    _StatusBar(controller: widget.controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workspace() {
    final current = widget.controller.current;
    if (current == null) return _Welcome(controller: widget.controller);
    return Row(
      children: [
        if (widget.controller.sidebarVisible)
          _PageSidebar(controller: widget.controller, document: current),
        Expanded(
          child: _PageCanvas(controller: widget.controller, document: current),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
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
              _ToolButton(
                icon: Icons.folder_open_rounded,
                tooltip: 'Mở PDF (Ctrl+O)',
                onPressed: controller.pickAndOpen,
              ),
              _ToolButton(
                icon: Icons.save_rounded,
                tooltip: 'Lưu (Ctrl+S)',
                onPressed: document == null ? null : controller.save,
              ),
              _ToolButton(
                icon: Icons.save_as_rounded,
                tooltip: 'Lưu thành… (Ctrl+Shift+S)',
                onPressed: document == null ? null : controller.saveAs,
              ),
              _ToolButton(
                icon: Icons.undo_rounded,
                tooltip: 'Hoàn tác (Ctrl+Z)',
                onPressed: document?.canUndo == true ? controller.undo : null,
              ),
              _ToolButton(
                icon: Icons.redo_rounded,
                tooltip: 'Làm lại (Ctrl+Shift+Z)',
                onPressed: document?.canRedo == true ? controller.redo : null,
              ),
              const _ToolbarDivider(),
              _ToolButton(
                icon: Icons.text_fields_rounded,
                tooltip: 'Chèn chữ có thể di chuyển và định dạng',
                onPressed: document == null
                    ? null
                    : () => _showTextEditor(context, controller),
              ),
              _ToolButton(
                icon: Icons.sticky_note_2_outlined,
                tooltip: 'Chèn ghi chú có thể di chuyển',
                onPressed: document == null
                    ? null
                    : () => _showNoteEditor(context, controller),
              ),
              _ToolButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: 'Chèn ảnh có thể di chuyển và đổi kích thước',
                onPressed: document == null
                    ? null
                    : controller.pickAndInsertImage,
              ),
              _ToolButton(
                icon: Icons.document_scanner_outlined,
                tooltip: 'OCR cục bộ và tạo lớp chữ tìm kiếm',
                onPressed: document == null || document.busy
                    ? null
                    : () => _showOcrDialog(context, controller),
              ),
              _ToolButton(
                icon: Icons.account_tree_outlined,
                tooltip: 'Review bố cục và reading order',
                onPressed: document == null || document.busy
                    ? null
                    : () => _showLayoutReviewDialog(context, controller),
              ),
              _ToolButton(
                icon: Icons.draw_outlined,
                tooltip: 'Ký số PAdES bằng PKCS#12',
                onPressed: document == null || document.busy
                    ? null
                    : () => _showPadesSigningDialog(context, controller),
              ),
              _ToolButton(
                icon: Icons.verified_user_outlined,
                tooltip: 'Xác minh tính toàn vẹn chữ ký PAdES',
                onPressed: document == null || document.busy
                    ? null
                    : () =>
                          _showSignatureVerificationDialog(context, controller),
              ),
              _ToolButton(
                icon: Icons.tune_rounded,
                tooltip: 'Sửa nội dung hoặc định dạng mục đang chọn',
                onPressed: document?.selectedAnnotation == null
                    ? null
                    : () => _editSelectedAnnotation(context, controller),
              ),
              _ToolButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Xóa mục đang chọn',
                onPressed: document?.selectedAnnotation == null
                    ? null
                    : controller.removeSelectedAnnotation,
              ),
              const _ToolbarDivider(),
              _ToolButton(
                icon: Icons.view_sidebar_rounded,
                tooltip: 'Ẩn/hiện danh sách trang',
                selected: controller.sidebarVisible,
                onPressed: document == null ? null : controller.toggleSidebar,
              ),
              _ToolButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Trang trước (Page Up)',
                onPressed: document == null || document.pageIndex == 0
                    ? null
                    : () => controller.goToPage(document.pageIndex - 1),
              ),
              if (document != null)
                Semantics(
                  label:
                      'Trang hiện tại ${document.pageIndex + 1} trên ${document.info.pageCount}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${document.pageIndex + 1} / ${document.info.pageCount}',
                    ),
                  ),
                ),
              _ToolButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Trang sau (Page Down)',
                onPressed:
                    document == null ||
                        document.pageIndex >= document.info.pageCount - 1
                    ? null
                    : () => controller.goToPage(document.pageIndex + 1),
              ),
              const _ToolbarDivider(),
              _ToolButton(
                icon: Icons.remove_rounded,
                tooltip: 'Thu nhỏ (Ctrl+-)',
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
              _ToolButton(
                icon: Icons.add_rounded,
                tooltip: 'Phóng to (Ctrl++)',
                onPressed: document == null
                    ? null
                    : () => controller.changeZoom(document.zoom + 0.25),
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
                    hintText: 'Tìm trong tài liệu',
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
              _ToolButton(
                icon: Icons.local_cafe_rounded,
                tooltip: 'Ủng hộ AZpdf qua Ko-fi',
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

class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({required this.controller});

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
                  label: 'Tài liệu ${document.name}',
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
                            tooltip: 'Đóng ${document.name}',
                            onPressed: () => _requestCloseDocument(
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
            tooltip: 'Mở tài liệu mới',
            onPressed: controller.pickAndOpen,
          ),
        ],
      ),
    );
  }
}

enum _CloseChoice { save, discard, cancel }

class _OcrOptions {
  const _OcrOptions({
    required this.language,
    required this.deskew,
    required this.rotatePages,
  });

  final String language;
  final bool deskew;
  final bool rotatePages;
}

class _PadesOptions {
  const _PadesOptions({
    required this.pkcs12Path,
    required this.password,
    required this.profile,
    this.timestampUrl,
  });

  final String pkcs12Path;
  final String password;
  final PdfSignatureProfile profile;
  final String? timestampUrl;
}

Future<void> _showPadesSigningDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  late PdfSignatureHealth health;
  try {
    health = await controller.signatureHealth();
  } catch (error) {
    if (!context.mounted) return;
    await _showPadesRuntimeError(context, error);
    return;
  }
  if (!context.mounted) return;
  final options = await showDialog<_PadesOptions>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PadesSigningDialog(health: health),
  );
  if (!context.mounted || options == null) return;

  final result = await controller.applyPadesSignature(
    pkcs12Path: options.pkcs12Path,
    password: options.password,
    profile: options.profile,
    timestampUrl: options.timestampUrl,
  );
  if (!context.mounted) return;
  if (result == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Không thể ký PAdES'),
        content: Text(controller.current?.error ?? 'Không có chi tiết lỗi.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ký PAdES hoàn tất'),
      content: SizedBox(
        width: 520,
        child: Text(
          '${result.verification.summary}\n\n'
          'Chữ ký đang ở working copy. Nhấn Ctrl+S để ghi vào file gốc. '
          'Mọi chỉnh sửa sau thời điểm ký có thể làm chữ ký không còn hợp lệ.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

Future<void> _showSignatureVerificationDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  try {
    final health = await controller.signatureHealth();
    final verification = await controller.verifySignatures();
    if (!context.mounted) return;
    final color = switch (verification.integrity) {
      'valid' => const Color(0xFF167347),
      'invalid' => const Color(0xFFB3261E),
      _ => const Color(0xFF5F6F83),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              verification.isCryptographicallyValid
                  ? Icons.verified_user_rounded
                  : Icons.gpp_maybe_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            const Text('Xác minh chữ ký PAdES'),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  verification.summary,
                  style: TextStyle(color: color, height: 1.45),
                ),
                const SizedBox(height: 14),
                Text(
                  '${health.provider} ${health.version} · kiểm tra cục bộ',
                  style: const TextStyle(color: Color(0xFF5F6F83)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tính toàn vẹn và certificate trust là hai kết quả độc lập. '
                  'Certificate self-signed có thể untrusted dù chữ ký vẫn khớp dữ liệu.',
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Chi tiết validator'),
                  children: [
                    SelectableText(
                      verification.details,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    await _showPadesRuntimeError(context, error);
  }
}

Future<void> _showPadesRuntimeError(BuildContext context, Object error) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PAdES chưa sẵn sàng'),
        content: Text(
          '$error\n\nCài pyHanko hoặc đặt AZPDF_PYHANKO tới executable cục bộ.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );

class _PadesSigningDialog extends StatefulWidget {
  const _PadesSigningDialog({required this.health});

  final PdfSignatureHealth health;

  @override
  State<_PadesSigningDialog> createState() => _PadesSigningDialogState();
}

class _PadesSigningDialogState extends State<_PadesSigningDialog> {
  final passwordController = TextEditingController();
  final timestampController = TextEditingController();
  PdfSignatureProfile profile = PdfSignatureProfile.baselineB;
  String? pkcs12Path;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (!widget.health.profiles.contains(profile) &&
        widget.health.profiles.isNotEmpty) {
      profile = widget.health.profiles.first;
    }
    passwordController.addListener(_refresh);
    timestampController.addListener(_refresh);
  }

  @override
  void dispose() {
    passwordController.removeListener(_refresh);
    timestampController.removeListener(_refresh);
    passwordController.clear();
    passwordController.dispose();
    timestampController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _pickCertificate() async {
    const group = XTypeGroup(
      label: 'PKCS#12',
      extensions: ['p12', 'pfx'],
      mimeTypes: ['application/x-pkcs12'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file != null && mounted) setState(() => pkcs12Path = file.path);
  }

  bool get canSubmit =>
      pkcs12Path != null &&
      passwordController.text.isNotEmpty &&
      (!profile.requiresTimestamp ||
          timestampController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ký số PAdES'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.health.provider} ${widget.health.version} · certificate và mật khẩu chỉ xử lý trên máy',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PdfSignatureProfile>(
              initialValue: profile,
              decoration: const InputDecoration(
                labelText: 'Profile',
                border: OutlineInputBorder(),
              ),
              items: widget.health.profiles
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => profile = value);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                pkcs12Path == null
                    ? 'Chọn certificate PKCS#12…'
                    : File(pkcs12Path!).uri.pathSegments.last,
              ),
              onPressed: _pickCertificate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu PKCS#12',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
            if (profile.requiresTimestamp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: timestampController,
                decoration: const InputDecoration(
                  labelText: 'URL TSA RFC 3161',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              profile == PdfSignatureProfile.baselineB
                  ? 'Baseline B hoạt động offline. Certificate trust được báo riêng với tính toàn vẹn.'
                  : 'LT/LTA sẽ kết nối TSA bạn chỉ định để lấy timestamp/validation info.',
              style: const TextStyle(color: Color(0xFF5F6F83)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sau khi ký, hãy lưu bản cuối. Chỉnh sửa nội dung sau đó có thể làm chữ ký không còn hợp lệ.',
              style: TextStyle(color: Color(0xFF8A5A00)),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          passwordController.clear();
          Navigator.pop(context);
        },
        child: const Text('Hủy'),
      ),
      FilledButton.icon(
        icon: const Icon(Icons.draw_outlined),
        label: const Text('Ký working copy'),
        onPressed: canSubmit
            ? () => Navigator.pop(
                context,
                _PadesOptions(
                  pkcs12Path: pkcs12Path!,
                  password: passwordController.text,
                  profile: profile,
                  timestampUrl: timestampController.text.trim().isEmpty
                      ? null
                      : timestampController.text.trim(),
                ),
              )
            : null,
      ),
    ],
  );
}

Future<void> _showLayoutReviewDialog(
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
        title: const Text('Không thể review bố cục'),
        content: Text(
          document?.error ?? 'Engine không trả về DocumentIR hợp lệ.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
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
        title: const Text('DocumentIR thiếu trang hiện tại'),
        content: Text('Không tìm thấy trang ${document.pageIndex + 1}.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) =>
        _LayoutReviewDialog(document: document, ir: ir, page: page!),
  );
}

class _LayoutReviewDialog extends StatefulWidget {
  const _LayoutReviewDialog({
    required this.document,
    required this.ir,
    required this.page,
  });

  final OpenedPdf document;
  final DocumentIr ir;
  final DocumentIrPage page;

  @override
  State<_LayoutReviewDialog> createState() => _LayoutReviewDialogState();
}

class _LayoutReviewDialogState extends State<_LayoutReviewDialog> {
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review bố cục và reading order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tọa độ top-left chuẩn hóa theo DocumentIR v1',
                          style: TextStyle(color: Color(0xFF5F6F83)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng review bố cục',
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
                    label: const Text('Sao chép theo reading order'),
                    onPressed: widget.ir.plainText.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.ir.plainText),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã sao chép văn bản DocumentIR.',
                                ),
                              ),
                            );
                          },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
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
              ? const Center(child: Text('Không phát hiện block bố cục.'))
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
                          text.isEmpty ? '(không có văn bản)' : text,
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
                  ? 'MuPDF baseline: kiểm tra paragraph, hình và reading order cơ bản. '
                        'Bảng, công thức và cấu trúc học thuật cần provider nâng cao.'
                  : 'Structured OCR provider: kiểm tra confidence, bảng, công thức, hình và reading order trước khi export.',
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
                ? const Text('Chọn một block để xem chi tiết.')
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
        label: 'Vùng ${_documentIrKindLabel(block.kind)}',
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
  DocumentIrBlockKind.paragraph => 'Đoạn văn',
  DocumentIrBlockKind.heading => 'Tiêu đề',
  DocumentIrBlockKind.listItem => 'Mục danh sách',
  DocumentIrBlockKind.table => 'Bảng',
  DocumentIrBlockKind.formula => 'Công thức',
  DocumentIrBlockKind.figure => 'Hình',
  DocumentIrBlockKind.caption => 'Chú thích hình',
  DocumentIrBlockKind.header => 'Đầu trang',
  DocumentIrBlockKind.footer => 'Chân trang',
  DocumentIrBlockKind.footnote => 'Chú thích cuối trang',
  DocumentIrBlockKind.pageNumber => 'Số trang',
  DocumentIrBlockKind.unknown => 'Chưa phân loại',
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

Future<void> _showOcrDialog(
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
        title: const Text('OCR chưa sẵn sàng'),
        content: Text(
          '$error\n\nCài OCRmyPDF hoặc đặt AZPDF_OCRMYPDF tới executable cục bộ.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
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
  final options = await showDialog<_OcrOptions>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('OCR toàn bộ tài liệu'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${health.provider} ${health.version} · xử lý hoàn toàn cục bộ',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: const InputDecoration(
                    labelText: 'Ngôn ngữ nhận dạng',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'vie+eng',
                      child: Text('Tiếng Việt + English'),
                    ),
                    DropdownMenuItem(value: 'vie', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'eng', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => language = value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Làm thẳng trang scan'),
                  subtitle: const Text('Deskew các trang bị nghiêng nhẹ'),
                  value: deskew,
                  onChanged: (value) => setDialogState(() => deskew = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự phát hiện hướng trang'),
                  subtitle: const Text('Xoay trang khi độ tin cậy đủ cao'),
                  value: rotatePages,
                  onChanged: (value) =>
                      setDialogState(() => rotatePages = value),
                ),
                const SizedBox(height: 8),
                Text(
                  health.preservesVisualLayout
                      ? 'Ảnh và bố cục trực quan được giữ nguyên; OCR thêm lớp chữ vô hình để tìm kiếm.'
                      : 'Provider này không cam kết giữ nguyên bố cục trực quan.',
                  style: const TextStyle(color: Color(0xFF46576C)),
                ),
                if (!health.supportsStructuredLayout) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Baseline hiện chưa hiểu ngữ nghĩa bảng hoặc công thức. Các provider layout nâng cao sẽ được bổ sung riêng.',
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
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Bắt đầu OCR'),
            onPressed: () => Navigator.pop(
              context,
              _OcrOptions(
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
        'OCR hoàn tất bằng ${result.provider} ${result.version}. Nhấn Ctrl+S để lưu vào file gốc.',
      ),
    ),
  );
}

Future<void> _requestCloseDocument(
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

  final choice = await showDialog<_CloseChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Lưu thay đổi?'),
      content: Text('“${document.name}” có thay đổi chưa được lưu.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _CloseChoice.cancel),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _CloseChoice.discard),
          child: const Text('Không lưu'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _CloseChoice.save),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  if (!context.mounted || choice == null || choice == _CloseChoice.cancel) {
    return;
  }
  if (choice == _CloseChoice.save && !await controller.saveDocument(index)) {
    return;
  }
  controller.closeDocument(index);
}

class _PageSidebar extends StatelessWidget {
  const _PageSidebar({required this.controller, required this.document});

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
              itemBuilder: (context, page) => _ThumbnailTile(
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

class _ThumbnailTile extends StatefulWidget {
  const _ThumbnailTile({
    required this.controller,
    required this.document,
    required this.page,
  });

  final WorkspaceController controller;
  final OpenedPdf document;
  final int page;

  @override
  State<_ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<_ThumbnailTile> {
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

class _PageCanvas extends StatelessWidget {
  const _PageCanvas({required this.controller, required this.document});

  final WorkspaceController controller;
  final OpenedPdf document;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFDDE2E9),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.5,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(240),
              child: Center(
                child: document.renderedPath == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.all(32),
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
                        child: _EditablePage(
                          controller: controller,
                          document: document,
                        ),
                      ),
              ),
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

class _EditablePage extends StatelessWidget {
  const _EditablePage({required this.controller, required this.document});

  final WorkspaceController controller;
  final OpenedPdf document;

  @override
  Widget build(BuildContext context) {
    final width = document.renderedWidth;
    final height = document.renderedHeight;
    if (width == null || height == null || document.renderedPath == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      image: true,
      label: 'Nội dung trang PDF ${document.pageIndex + 1}',
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
                  errorBuilder: (_, error, _) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('$error'),
                  ),
                ),
              ),
              for (final annotation in document.currentAnnotations)
                _AnnotationOverlay(
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

class _AnnotationOverlay extends StatefulWidget {
  const _AnnotationOverlay({
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
  State<_AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<_AnnotationOverlay> {
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
            onDoubleTap: () => _editSelectedAnnotation(
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
  PdfAnnotationKind.freeText => 'Chữ: ${annotation.contents ?? ''}',
  PdfAnnotationKind.note => 'Ghi chú: ${annotation.contents ?? ''}',
  PdfAnnotationKind.image => 'Ảnh đã chèn',
  PdfAnnotationKind.unknown => 'Annotation PDF',
};

Future<void> _editSelectedAnnotation(
  BuildContext context,
  WorkspaceController controller, {
  PdfAnnotation? annotation,
}) async {
  final selected = annotation ?? controller.current?.selectedAnnotation;
  if (selected == null) return;
  return switch (selected.kind) {
    PdfAnnotationKind.freeText => _showTextEditor(
      context,
      controller,
      annotation: selected,
    ),
    PdfAnnotationKind.note => _showNoteEditor(
      context,
      controller,
      annotation: selected,
    ),
    PdfAnnotationKind.image => controller.pickAndReplaceSelectedImage(),
    PdfAnnotationKind.unknown => Future<void>.value(),
  };
}

Future<void> _showTextEditor(
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
        title: Text(annotation == null ? 'Chèn chữ' : 'Sửa chữ và định dạng'),
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
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
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
                      decoration: const InputDecoration(
                        labelText: 'Cỡ chữ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  DropdownButton<PdfTextAlignment>(
                    value: alignment,
                    items: const [
                      DropdownMenuItem(
                        value: PdfTextAlignment.left,
                        child: Text('Căn trái'),
                      ),
                      DropdownMenuItem(
                        value: PdfTextAlignment.center,
                        child: Text('Căn giữa'),
                      ),
                      DropdownMenuItem(
                        value: PdfTextAlignment.right,
                        child: Text('Căn phải'),
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
              const Text(
                'Sau khi chèn, kéo khung để di chuyển; kéo chấm xanh để đổi kích thước.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5D6B7D)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Áp dụng'),
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

Future<void> _showNoteEditor(
  BuildContext context,
  WorkspaceController controller, {
  PdfAnnotation? annotation,
}) async {
  final textController = TextEditingController(text: annotation?.contents);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(annotation == null ? 'Chèn ghi chú' : 'Sửa ghi chú'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: textController,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Nội dung ghi chú',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Áp dụng'),
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

const _colorNames = ['Đen', 'Xanh dương', 'Đỏ', 'Xanh lá'];

Color _flutterColor(PdfColor color) => Color.fromRGBO(
  (color.red * 255).round(),
  (color.green * 255).round(),
  (color.blue * 255).round(),
  color.alpha,
);

class _Welcome extends StatelessWidget {
  const _Welcome({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD9E0EA)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 64,
                  color: Color(0xFF0B5ED7),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mở một tài liệu PDF',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tài liệu được xử lý hoàn toàn trên máy của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5D6B7D)),
                ),
                if (controller.startupError case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF9A3412)),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: controller.pickAndOpen,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Mở PDF'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ctrl+O',
                  style: TextStyle(fontSize: 12, color: Color(0xFF778396)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final document = controller.current;
    final health = controller.health;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD9E0EA))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: Color(0xFF287A4B),
          ),
          const SizedBox(width: 5),
          const Text(
            'Xử lý cục bộ',
            style: TextStyle(fontSize: 11, color: Color(0xFF287A4B)),
          ),
          const Spacer(),
          if (document != null)
            Text(
              '${document.info.pageCount} trang',
              style: const TextStyle(fontSize: 11, color: Color(0xFF66758A)),
            ),
          if (health != null) ...[
            const SizedBox(width: 14),
            Text(
              health.engineVersion,
              style: const TextStyle(fontSize: 11, color: Color(0xFF66758A)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 28, child: VerticalDivider(width: 14));
}

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SaveAsIntent extends Intent {
  const _SaveAsIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _FindIntent extends Intent {
  const _FindIntent();
}

class _PreviousPageIntent extends Intent {
  const _PreviousPageIntent();
}

class _NextPageIntent extends Intent {
  const _NextPageIntent();
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}
