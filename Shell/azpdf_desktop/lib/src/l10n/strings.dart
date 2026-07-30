import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Ngôn ngữ giao diện. `system` bám theo locale của máy.
enum AppLanguage { system, english, vietnamese }

/// Tra chuỗi cho vỏ desktop.
///
/// Cố ý KHÔNG dùng `flutter_localizations` + `AppLocalizations.of(context)`:
/// 22 trong 142 chuỗi nằm ngoài widget — trong `pdf_models.dart`,
/// `workspace_controller.dart` và `azpdf_engine_client.dart` — nơi không có
/// `BuildContext` nào để truyền vào. Chọn gen-l10n đồng nghĩa với việc luồn
/// context qua tầng model và engine client chỉ để lấy một chuỗi lỗi.
///
/// Đây cũng đúng idiom mà app macOS đang dùng (`L(_:)` trong
/// `Support/Localization.swift`), nên hai nền tảng gọi giống nhau.
class AppStrings {
  AppStrings._();

  /// Widget nghe cái này để vẽ lại khi người dùng đổi ngôn ngữ.
  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.system);

  /// Mã ngôn ngữ đang dùng thật sự, sau khi đã giải `system`.
  static String get resolvedCode {
    switch (language.value) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.vietnamese:
        return 'vi';
      case AppLanguage.system:
        // Platform.localeName dạng "vi_VN.UTF-8"; chỉ tiếng Việt mới lấy vi,
        // còn lại về en. Không đoán theo quốc gia.
        return Platform.localeName.toLowerCase().startsWith('vi') ? 'vi' : 'en';
    }
  }

  /// Tra một khoá. Thiếu ở ngôn ngữ hiện tại thì lùi về en, thiếu nốt thì trả
  /// chính khoá — hiện khoá thô còn hơn nuốt mất chuỗi rồi vẽ ô trống.
  static String lookup(String key, [Map<String, Object?>? args]) {
    final table = _tables[resolvedCode] ?? _tables['en']!;
    var value = table[key] ?? _tables['en']![key] ?? key;
    if (args != null) {
      args.forEach((name, arg) {
        value = value.replaceAll('{$name}', '$arg');
      });
    }
    return value;
  }

  // --- lưu lựa chọn ---------------------------------------------------------
  // Ghi thẳng ra một file JSON nhỏ thay vì thêm shared_preferences +
  // path_provider. Vỏ này build offline qua Flatpak với danh sách pub source
  // đã ghim (`Packaging/flatpak/flutter-pub-sources.json`), nên mỗi dependency
  // mới đều phải sinh lại danh sách đó. Hai dependency cho một enum là không đáng.

  static File get _settingsFile {
    final home = Platform.isWindows
        ? (Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'] ?? '.')
        : (Platform.environment['XDG_CONFIG_HOME'] ??
            '${Platform.environment['HOME'] ?? '.'}/.config');
    return File('$home${Platform.pathSeparator}azpdf${Platform.pathSeparator}settings.json');
  }

  static Future<void> load() async {
    try {
      final file = _settingsFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final name = decoded['language'];
      language.value = AppLanguage.values.firstWhere(
        (candidate) => candidate.name == name,
        orElse: () => AppLanguage.system,
      );
    } on Object {
      // Cấu hình hỏng không được làm app chết lúc khởi động; im lặng dùng mặc định.
    }
  }

  static Future<void> save(AppLanguage value) async {
    language.value = value;
    try {
      final file = _settingsFile;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'language': value.name}));
    } on Object {
      // Không ghi được (đĩa đầy, chỉ đọc) thì lựa chọn vẫn có hiệu lực phiên này.
    }
  }

  /// Tập khoá của một bảng. Chỉ dùng cho test chẵn lẻ giữa hai ngôn ngữ.
  static Set<String> debugKeys(String code) => (_tables[code] ?? const {}).keys.toSet();

  static const Map<String, Map<String, String>> _tables = {
    'vi': _vi,
    'en': _en,
  };

  static const Map<String, String> _vi = _viTable;
  static const Map<String, String> _en = _enTable;
}

/// Cách gọi ngắn, khớp với `L(_:)` bên macOS.
String L(String key, [Map<String, Object?>? args]) =>
    AppStrings.lookup(key, args);

// GENERATED_TABLE_START
const Map<String, String> _viTable = {
  'language': 'Ngôn ngữ',
  'after_insert_hint': 'Sau khi chèn, kéo khung để di chuyển; kéo chấm xanh để đổi kích thước.',
  'after_signing_hint': 'Sau khi ký, hãy lưu bản cuối. Chỉnh sửa nội dung sau đó có thể làm chữ ký không còn hợp lệ.',
  'align_center': 'Căn giữa',
  'align_left': 'Căn trái',
  'align_right': 'Căn phải',
  'apply': 'Áp dụng',
  'auto_detect_orientation': 'Tự phát hiện hướng trang',
  'baseline_no_table_semantics': 'Baseline hiện chưa hiểu ngữ nghĩa bảng hoặc công thức. Các provider layout nâng cao sẽ được bổ sung riêng.',
  'black': 'Đen',
  'blue': 'Xanh dương',
  'cancel': 'Hủy',
  'cannot_review_layout': 'Không thể review bố cục',
  'cannot_secure_passfile': 'Không thể bảo vệ file mật khẩu PKCS#12.',
  'cannot_sign_pades': 'Không thể ký PAdES',
  'caption': 'Chú thích hình',
  'cert_self_signed': 'Certificate self-signed có thể untrusted dù chữ ký vẫn khớp dữ liệu.',
  'cert_stays_local': '{provider} {version} · certificate và mật khẩu chỉ xử lý trên máy',
  'cert_trust_unknown': 'Chưa xác định được certificate trust.',
  'cert_trusted': 'Certificate được trust store hiện tại tin cậy.',
  'cert_untrusted': 'Certificate chưa được trust store hiện tại tin cậy.',
  'checked_locally': '{provider} {version} · kiểm tra cục bộ',
  'choose_pkcs12': 'Chọn certificate PKCS#12…',
  'close': 'Đóng',
  'close_layout_review': 'Đóng review bố cục',
  'close_named': 'Đóng {name}',
  'content': 'Nội dung',
  'copy_in_reading_order': 'Sao chép theo reading order',
  'delete_selected': 'Xóa mục đang chọn',
  'deskew': 'Làm thẳng trang scan',
  'deskew_hint': 'Deskew các trang bị nghiêng nhẹ',
  'document_busy': 'Tài liệu đang bận hoặc chưa được mở.',
  'document_named': 'Tài liệu {name}',
  'dont_save': 'Không lưu',
  'edit_note': 'Sửa ghi chú',
  'edit_selected_hint': 'Sửa nội dung hoặc định dạng mục đang chọn',
  'edit_text_and_format': 'Sửa chữ và định dạng',
  'edits_after_signing': 'Mọi chỉnh sửa sau thời điểm ký có thể làm chữ ký không còn hợp lệ.',
  'engine_bad_ir': 'Engine không trả về DocumentIR hợp lệ.',
  'engine_exit_code': 'Engine PDF kết thúc với mã {code}.',
  'engine_no_data': 'Engine PDF không trả dữ liệu.',
  'engine_not_found': 'Không tìm thấy azpdf-engine. Đặt AZPDF_ENGINE tới executable đã build.',
  'engine_timeout': 'Engine PDF vượt quá {seconds} giây.',
  'engine_unknown_error': 'Engine PDF gặp lỗi không xác định.',
  'figure': 'Hình',
  'find_in_document': 'Tìm trong tài liệu',
  'font_size': 'Cỡ chữ',
  'footer': 'Chân trang',
  'footnote': 'Chú thích cuối trang',
  'formula': 'Công thức',
  'green': 'Xanh lá',
  'has_dss': 'Có dữ liệu validation/DSS.',
  'has_timestamp': 'Có timestamp.',
  'header': 'Đầu trang',
  'heading': 'Tiêu đề',
  'hide_password': 'Ẩn mật khẩu',
  'image': 'Ảnh',
  'insert_image_hint': 'Chèn ảnh có thể di chuyển và đổi kích thước',
  'insert_note': 'Chèn ghi chú',
  'insert_note_hint': 'Chèn ghi chú có thể di chuyển',
  'insert_text': 'Chèn chữ',
  'insert_text_hint': 'Chèn chữ có thể di chuyển và định dạng',
  'inserted_image': 'Ảnh đã chèn',
  'integrity_and_trust_independent': 'Tính toàn vẹn và certificate trust là hai kết quả độc lập. ',
  'integrity_unknown': 'Chưa xác định được tính toàn vẹn chữ ký.',
  'integrity_valid': 'Tính toàn vẹn chữ ký hợp lệ.',
  'ir_coords': 'Tọa độ top-left chuẩn hóa theo DocumentIR v1',
  'ir_missing_page': 'DocumentIR thiếu trang hiện tại',
  'ir_text_copied': 'Đã sao chép văn bản DocumentIR.',
  'lang_vi_en_name': 'Tiếng Việt + English',
  'lang_vi_name': 'Tiếng Việt',
  'list_item': 'Mục danh sách',
  'local_processing': 'Xử lý cục bộ',
  'lt_lta_contacts_tsa': 'LT/LTA sẽ kết nối TSA bạn chỉ định để lấy timestamp/validation info.',
  'mupdf_baseline_desc': 'MuPDF baseline: kiểm tra paragraph, hình và reading order cơ bản. ',
  'n_documents_unsaved': 'Có {count} tài liệu chứa thay đổi chưa được lưu.',
  'named_has_unsaved': '“{name}” có thay đổi chưa được lưu.',
  'no_dss': 'Chưa phát hiện dữ liệu validation/DSS.',
  'no_error_detail': 'Không có chi tiết lỗi.',
  'no_layout_blocks': 'Không phát hiện block bố cục.',
  'no_text': '(không có văn bản)',
  'no_timestamp': 'Chưa phát hiện timestamp.',
  'note_content': 'Nội dung ghi chú',
  'note_label': 'Ghi chú: {text}',
  'ocr_complete': 'OCR hoàn tất bằng {provider} {version}. Nhấn Ctrl+S để lưu vào file gốc.',
  'ocr_install_hint': '{error}\\n\\nCài OCRmyPDF hoặc đặt AZPDF_OCRMYPDF tới executable cục bộ.',
  'ocr_keeps_layout': 'Ảnh và bố cục trực quan được giữ nguyên; OCR thêm lớp chữ vô hình để tìm kiếm.',
  'ocr_local_hint': 'OCR cục bộ và tạo lớp chữ tìm kiếm',
  'ocr_not_ready': 'OCR chưa sẵn sàng',
  'ocr_whole_document': 'OCR toàn bộ tài liệu',
  'open_a_pdf': 'Mở một tài liệu PDF',
  'open_new_document': 'Mở tài liệu mới',
  'open_pdf': 'Mở PDF',
  'open_pdf_shortcut': 'Mở PDF (Ctrl+O)',
  'pades_b_offline': 'Baseline B hoạt động offline. Certificate trust được báo riêng với tính toàn vẹn.',
  'pades_done': 'Ký PAdES hoàn tất',
  'pades_not_ready': 'PAdES chưa sẵn sàng',
  'pades_sign': 'Ký số PAdES',
  'pades_sign_with_pkcs12': 'Ký số PAdES bằng PKCS#12',
  'page_content': 'Nội dung trang PDF {page}',
  'page_not_found': 'Không tìm thấy trang {page}.',
  'page_number': 'Số trang',
  'page_x_of_y': 'Trang hiện tại {page} trên {total}',
  'paragraph': 'Đoạn văn',
  'pdf_unsigned': 'PDF không có chữ ký số nhúng.',
  'pkcs12_password': 'Mật khẩu PKCS#12',
  'previous_page_shortcut': 'Trang trước (Page Up)',
  'processed_fully_locally': '{provider} {version} · xử lý hoàn toàn cục bộ',
  'processed_locally': 'Tài liệu được xử lý hoàn toàn trên máy của bạn.',
  'provider_no_layout_promise': 'Provider này không cam kết giữ nguyên bố cục trực quan.',
  'pyhanko_install_hint': '{error}\\n\\nCài pyHanko hoặc đặt AZPDF_PYHANKO tới executable cục bộ.',
  'recognition_language': 'Ngôn ngữ nhận dạng',
  'red': 'Đỏ',
  'redo_shortcut': 'Làm lại (Ctrl+Shift+Z)',
  'region_of_kind': 'Vùng {kind}',
  'review_layout': 'Review bố cục và reading order',
  'rotate_when_confident': 'Xoay trang khi độ tin cậy đủ cao',
  'save': 'Lưu',
  'save_all': 'Lưu tất cả',
  'save_as_shortcut': 'Lưu thành… (Ctrl+Shift+S)',
  'save_before_quit_q': 'Lưu trước khi thoát?',
  'save_changes_q': 'Lưu thay đổi?',
  'save_shortcut': 'Lưu (Ctrl+S)',
  'select_block': 'Chọn một block để xem chi tiết.',
  'show_password': 'Hiện mật khẩu',
  'sign_working_copy': 'Ký working copy',
  'signature_in_working_copy': 'Chữ ký đang ở working copy. Nhấn Ctrl+S để ghi vào file gốc. ',
  'signature_mismatch': 'Chữ ký không khớp với nội dung PDF.',
  'signed_pdf_failed_integrity': 'PDF đã ký không vượt qua xác minh toàn vẹn.',
  'signer_is': 'Người ký: {name}.',
  'start_ocr': 'Bắt đầu OCR',
  'structured_ocr_desc': 'Structured OCR provider: kiểm tra confidence, bảng, công thức, hình và reading order trước khi export.',
  'support_kofi': 'Ủng hộ AZpdf qua Ko-fi',
  'table': 'Bảng',
  'tables_need_advanced': 'Bảng, công thức và cấu trúc học thuật cần provider nâng cao.',
  'text_label': 'Chữ: {text}',
  'toggle_page_list': 'Ẩn/hiện danh sách trang',
  'unclassified': 'Chưa phân loại',
  'undo_shortcut': 'Hoàn tác (Ctrl+Z)',
  'verify_pades': 'Xác minh chữ ký PAdES',
  'verify_pades_integrity': 'Xác minh tính toàn vẹn chữ ký PAdES',
  'zoom_in_shortcut': 'Phóng to (Ctrl++)',
  'zoom_out_shortcut': 'Thu nhỏ (Ctrl+-)',
};

const Map<String, String> _enTable = {
  'language': 'Language',
  'after_insert_hint': 'Once inserted, drag the frame to move it and drag the blue dot to resize.',
  'after_signing_hint': 'Save the final copy after signing. Editing the contents afterwards can invalidate the signature.',
  'align_center': 'Center',
  'align_left': 'Left',
  'align_right': 'Right',
  'apply': 'Apply',
  'auto_detect_orientation': 'Detect page orientation automatically',
  'baseline_no_table_semantics': 'The baseline does not yet understand table or formula semantics. Advanced layout providers will be added separately.',
  'black': 'Black',
  'blue': 'Blue',
  'cancel': 'Cancel',
  'cannot_review_layout': 'Cannot review the layout',
  'cannot_secure_passfile': 'Could not secure the PKCS#12 password file.',
  'cannot_sign_pades': 'Cannot sign with PAdES',
  'caption': 'Caption',
  'cert_self_signed': 'A self-signed certificate can be untrusted even when the signature still matches the data.',
  'cert_stays_local': '{provider} {version} · certificate and password never leave this machine',
  'cert_trust_unknown': 'Certificate trust could not be determined.',
  'cert_trusted': 'The certificate is trusted by the current trust store.',
  'cert_untrusted': 'The certificate is not trusted by the current trust store.',
  'checked_locally': '{provider} {version} · checked locally',
  'choose_pkcs12': 'Choose a PKCS#12 certificate…',
  'close': 'Close',
  'close_layout_review': 'Close layout review',
  'close_named': 'Close {name}',
  'content': 'Content',
  'copy_in_reading_order': 'Copy in reading order',
  'delete_selected': 'Delete the selected item',
  'deskew': 'Straighten scanned pages',
  'deskew_hint': 'Deskew slightly tilted pages',
  'document_busy': 'The document is busy or not open.',
  'document_named': 'Document {name}',
  'dont_save': 'Don’t Save',
  'edit_note': 'Edit note',
  'edit_selected_hint': 'Edit the contents or formatting of the selected item',
  'edit_text_and_format': 'Edit text and formatting',
  'edits_after_signing': 'Any edit made after signing can invalidate the signature.',
  'engine_bad_ir': 'The engine did not return a valid DocumentIR.',
  'engine_exit_code': 'The PDF engine exited with code {code}.',
  'engine_no_data': 'The PDF engine returned no data.',
  'engine_not_found': 'azpdf-engine not found. Point AZPDF_ENGINE at the built executable.',
  'engine_timeout': 'The PDF engine exceeded {seconds} seconds.',
  'engine_unknown_error': 'The PDF engine hit an unknown error.',
  'figure': 'Figure',
  'find_in_document': 'Find in document',
  'font_size': 'Font size',
  'footer': 'Footer',
  'footnote': 'Footnote',
  'formula': 'Formula',
  'green': 'Green',
  'has_dss': 'Validation/DSS data present.',
  'has_timestamp': 'Timestamp present.',
  'header': 'Header',
  'heading': 'Heading',
  'hide_password': 'Hide password',
  'image': 'Image',
  'insert_image_hint': 'Insert an image you can move and resize',
  'insert_note': 'Insert note',
  'insert_note_hint': 'Insert a note you can move',
  'insert_text': 'Insert text',
  'insert_text_hint': 'Insert text you can move and format',
  'inserted_image': 'Inserted image',
  'integrity_and_trust_independent': 'Integrity and certificate trust are two independent results. ',
  'integrity_unknown': 'Signature integrity could not be determined.',
  'integrity_valid': 'Signature integrity is valid.',
  'ir_coords': 'Top-left coordinates normalised per DocumentIR v1',
  'ir_missing_page': 'DocumentIR is missing the current page',
  'ir_text_copied': 'DocumentIR text copied.',
  'lang_vi_en_name': 'Tiếng Việt + English',
  'lang_vi_name': 'Tiếng Việt',
  'list_item': 'List item',
  'local_processing': 'Processed locally',
  'lt_lta_contacts_tsa': 'LT/LTA contacts the TSA you specify to obtain timestamp and validation info.',
  'mupdf_baseline_desc': 'MuPDF baseline: checks paragraphs, figures and basic reading order. ',
  'n_documents_unsaved': '{count} documents have unsaved changes.',
  'named_has_unsaved': '“{name}” has unsaved changes.',
  'no_dss': 'No validation/DSS data detected.',
  'no_error_detail': 'No error details.',
  'no_layout_blocks': 'No layout blocks detected.',
  'no_text': '(no text)',
  'no_timestamp': 'No timestamp detected.',
  'note_content': 'Note content',
  'note_label': 'Note: {text}',
  'ocr_complete': 'OCR finished using {provider} {version}. Press Ctrl+S to save into the original file.',
  'ocr_install_hint': '{error}\\n\\nInstall OCRmyPDF or point AZPDF_OCRMYPDF at a local executable.',
  'ocr_keeps_layout': 'Images and visual layout are preserved; OCR adds an invisible text layer for search.',
  'ocr_local_hint': 'Run OCR locally and add a searchable text layer',
  'ocr_not_ready': 'OCR is not ready',
  'ocr_whole_document': 'OCR the whole document',
  'open_a_pdf': 'Open a PDF document',
  'open_new_document': 'Open a new document',
  'open_pdf': 'Open PDF',
  'open_pdf_shortcut': 'Open PDF (Ctrl+O)',
  'pades_b_offline': 'Baseline B works offline. Certificate trust is reported separately from integrity.',
  'pades_done': 'PAdES signing complete',
  'pades_not_ready': 'PAdES is not ready',
  'pades_sign': 'PAdES signature',
  'pades_sign_with_pkcs12': 'Sign with PAdES using PKCS#12',
  'page_content': 'Contents of PDF page {page}',
  'page_not_found': 'Page {page} was not found.',
  'page_number': 'Page number',
  'page_x_of_y': 'Page {page} of {total}',
  'paragraph': 'Paragraph',
  'pdf_unsigned': 'This PDF has no embedded digital signature.',
  'pkcs12_password': 'PKCS#12 password',
  'previous_page_shortcut': 'Previous page (Page Up)',
  'processed_fully_locally': '{provider} {version} · processed entirely on device',
  'processed_locally': 'The document is processed entirely on your machine.',
  'provider_no_layout_promise': 'This provider makes no promise to preserve the visual layout.',
  'pyhanko_install_hint': '{error}\\n\\nInstall pyHanko or point AZPDF_PYHANKO at a local executable.',
  'recognition_language': 'Recognition language',
  'red': 'Red',
  'redo_shortcut': 'Redo (Ctrl+Shift+Z)',
  'region_of_kind': '{kind} region',
  'review_layout': 'Review layout and reading order',
  'rotate_when_confident': 'Rotate pages when confidence is high enough',
  'save': 'Save',
  'save_all': 'Save All',
  'save_as_shortcut': 'Save As… (Ctrl+Shift+S)',
  'save_before_quit_q': 'Save before quitting?',
  'save_changes_q': 'Save changes?',
  'save_shortcut': 'Save (Ctrl+S)',
  'select_block': 'Select a block to see its details.',
  'show_password': 'Show password',
  'sign_working_copy': 'Sign the working copy',
  'signature_in_working_copy': 'The signature is in the working copy. Press Ctrl+S to write it to the original file. ',
  'signature_mismatch': 'The signature does not match the PDF contents.',
  'signed_pdf_failed_integrity': 'The signed PDF did not pass integrity verification.',
  'signer_is': 'Signed by: {name}.',
  'start_ocr': 'Start OCR',
  'structured_ocr_desc': 'Structured OCR provider: review confidence, tables, formulas, figures and reading order before exporting.',
  'support_kofi': 'Support AZpdf on Ko-fi',
  'table': 'Table',
  'tables_need_advanced': 'Tables, formulas and academic structure need an advanced provider.',
  'text_label': 'Text: {text}',
  'toggle_page_list': 'Show or hide the page list',
  'unclassified': 'Unclassified',
  'undo_shortcut': 'Undo (Ctrl+Z)',
  'verify_pades': 'Verify PAdES signature',
  'verify_pades_integrity': 'Verify PAdES signature integrity',
  'zoom_in_shortcut': 'Zoom in (Ctrl++)',
  'zoom_out_shortcut': 'Zoom out (Ctrl+-)',
};
// GENERATED_TABLE_END
