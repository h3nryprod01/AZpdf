// Tách từ workspace_page.dart (2.600 dòng) ngày 2026-08-17 — xem commit để biết lý do.
// Không đổi hành vi: chỉ chuyển class/hàm sang file theo vùng chức năng và bỏ dấu `_`
// ở những tên bị tham chiếu chéo file.
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../controllers/workspace_controller.dart';
import '../models/pdf_models.dart';
import '../l10n/strings.dart';

class PadesOptions {
  const PadesOptions({
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

Future<void> showPadesSigningDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  late PdfSignatureHealth health;
  try {
    health = await controller.signatureHealth();
  } catch (error) {
    if (!context.mounted) return;
    await showPadesRuntimeError(context, error);
    return;
  }
  if (!context.mounted) return;
  final options = await showDialog<PadesOptions>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PadesSigningDialog(health: health),
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
        title:  Text(L('cannot_sign_pades')),
        content: Text(controller.current?.error ?? L('no_error_detail')),
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
    builder: (context) => AlertDialog(
      title:  Text(L('pades_done')),
      content: SizedBox(
        width: 520,
        child: Text(
          '${result.verification.summary}\n\n'
          '${L('signature_in_working_copy')}${L('edits_after_signing')}',
),
),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child:  Text(L('close')),
),
],
),
);
}

Future<void> showSignatureVerificationDialog(
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
             Text(L('verify_pades')),
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
                  L('checked_locally', {'provider': health.provider, 'version': health.version}),
                  style: const TextStyle(color: Color(0xFF5F6F83)),
),
                const SizedBox(height: 8),
                 Text(
                  L('integrity_and_trust_independent') +
                  L('cert_self_signed'),
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
            child:  Text(L('close')),
),
],
),
);
  } catch (error) {
    if (!context.mounted) return;
    await showPadesRuntimeError(context, error);
  }
}

Future<void> showPadesRuntimeError(BuildContext context, Object error) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text(L('pades_not_ready')),
        content: Text(
          L('pyhanko_install_hint', {'error': error}),
),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(L('close')),
),
],
),
);

class PadesSigningDialog extends StatefulWidget {
  const PadesSigningDialog({super.key, required this.health});

  final PdfSignatureHealth health;

  @override
  State<PadesSigningDialog> createState() => _PadesSigningDialogState();
}

class _PadesSigningDialogState extends State<PadesSigningDialog> {
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
    title:  Text(L('pades_sign')),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L('cert_stays_local', {'provider': widget.health.provider, 'version': widget.health.version}),
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
                    ? L('choose_pkcs12')
                    : File(pkcs12Path!).uri.pathSegments.last,
),
              onPressed: _pickCertificate,
),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: L('pkcs12_password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? L('show_password') : L('hide_password'),
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
                  ? L('pades_b_offline')
                  : L('lt_lta_contacts_tsa'),
              style: const TextStyle(color: Color(0xFF5F6F83)),
),
            const SizedBox(height: 8),
             Text(
              L('after_signing_hint'),
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
        child:  Text(L('cancel')),
),
      FilledButton.icon(
        icon: const Icon(Icons.draw_outlined),
        label:  Text(L('sign_working_copy')),
        onPressed: canSubmit
            ? () => Navigator.pop(
                context,
                PadesOptions(
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

