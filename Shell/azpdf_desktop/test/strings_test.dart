import 'package:azpdf_desktop/src/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppStrings.language.value = AppLanguage.system);

  test('đổi ngôn ngữ đổi chuỗi trả về', () {
    AppStrings.language.value = AppLanguage.vietnamese;
    expect(L('open_a_pdf'), 'Mở một tài liệu PDF');
    AppStrings.language.value = AppLanguage.english;
    expect(L('open_a_pdf'), 'Open a PDF document');
  });

  test('placeholder được thay bằng giá trị thật, đúng trật tự từng ngôn ngữ', () {
    AppStrings.language.value = AppLanguage.vietnamese;
    expect(L('page_x_of_y', {'page': 3, 'total': 12}), 'Trang hiện tại 3 trên 12');
    AppStrings.language.value = AppLanguage.english;
    expect(L('page_x_of_y', {'page': 3, 'total': 12}), 'Page 3 of 12');
  });

  test('placeholder chưa truyền thì giữ nguyên, không nuốt chuỗi', () {
    AppStrings.language.value = AppLanguage.english;
    expect(L('page_x_of_y'), contains('{page}'));
  });

  test('khoá không tồn tại trả về chính khoá thay vì chuỗi rỗng', () {
    // Ô trống trong UI là lỗi im lặng; hiện khoá thô thì người ta thấy ngay.
    expect(L('khoa_khong_bao_gio_ton_tai'), 'khoa_khong_bao_gio_ton_tai');
  });

  test('hai bảng có cùng tập khoá', () {
    // Thiếu khoá ở vi nghĩa là tiếng Anh lọt vào giao diện tiếng Việt; thiếu ở
    // en nghĩa là ngược lại. Cả hai đều là lỗi nhìn thấy được, nên chặn ở đây.
    AppStrings.language.value = AppLanguage.vietnamese;
    final vi = AppStrings.debugKeys('vi');
    final en = AppStrings.debugKeys('en');
    expect(vi.difference(en), isEmpty, reason: 'có ở vi nhưng thiếu ở en');
    expect(en.difference(vi), isEmpty, reason: 'có ở en nhưng thiếu ở vi');
    expect(vi, isNotEmpty);
  });

  test('tên ngôn ngữ không bị dịch', () {
    // Người đang mắc kẹt trong UI không đọc được tìm ngôn ngữ của mình bằng
    // cách nhận ra chính tên nó, nên "Tiếng Việt" phải giống nhau ở cả hai bảng.
    AppStrings.language.value = AppLanguage.english;
    expect(L('lang_vi_name'), 'Tiếng Việt');
    AppStrings.language.value = AppLanguage.vietnamese;
    expect(L('lang_vi_name'), 'Tiếng Việt');
  });
}
