import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/workspace_controller.dart';
import '../l10n/strings.dart';
import 'workspace_toolbar.dart';
import 'document_tabs.dart';
import 'page_view.dart';

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

  /// Chỗ duy nhất biết mật độ điểm ảnh thật của cửa sổ. Chạy cả lúc khởi động
  /// lẫn khi người dùng kéo cửa sổ sang màn hình có tỉ lệ khác, nên đổi màn là
  /// trang được render lại đúng độ nét chứ không giữ ảnh cũ bị kéo giãn.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final needsRerender = widget.controller.updateRenderPixelRatio(
      MediaQuery.devicePixelRatioOf(context),
);
    if (!needsRerender) return;
    // Hoãn sang sau frame: hàm này chạy trong pha build, mà renderCurrent()
    // notify ngay dòng đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.renderCurrent();
    });
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
      final choice = await showDialog<CloseChoice>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title:  Text(L('save_before_quit_q')),
          content: Text(L('n_documents_unsaved', {'count': dirtyCount})),
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
              child:  Text(L('save_all')),
),
],
),
);
      if (!mounted || choice == null || choice == CloseChoice.cancel) return;
      if (choice == CloseChoice.save) {
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
                    WorkspaceToolbar(
                      controller: widget.controller,
                      searchController: searchController,
                      searchFocus: searchFocus,
),
                    DocumentTabs(controller: widget.controller),
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
          PageSidebar(controller: widget.controller, document: current),
        Expanded(
          child: PageCanvas(controller: widget.controller, document: current),
),
],
);
  }
}

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
                 Text(
                  L('open_a_pdf'),
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
),
                const SizedBox(height: 8),
                 Text(
                  L('processed_locally'),
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
                  label:  Text(L('open_pdf')),
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
           Text(
            L('local_processing'),
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

/// Bộ chọn ngôn ngữ trên toolbar.
///
/// Nhãn của mỗi ngôn ngữ viết bằng CHÍNH ngôn ngữ đó và không bao giờ được
/// dịch: người đang mắc kẹt trong một UI họ không đọc được tìm ra ngôn ngữ của
/// mình bằng cách nhận ra tên của nó. Đây cũng là ngoại lệ mà gate i18n bên
/// macOS đánh dấu `i18n-exempt`.
