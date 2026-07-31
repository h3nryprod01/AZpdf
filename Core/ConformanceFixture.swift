import Foundation

/// PDF + PNG nhúng sẵn để `azpdf-engine selftest` chạy harness conform trên môi trường
/// không có bash để sinh fixture (Windows). `pdf` là đúng bytes của
/// `Tests/Fixtures/source/two-page.pdf` mà `MuPDFOperationMatrixTests` dùng — trang 0 chứa
/// `AZPDF-P1`, trang 1 chứa `AZPDF-P2`, đúng postcondition mà harness đọc lại. Foundation-only
/// để chạy được trên cả ba nền tảng.
public enum ConformanceFixture {
    /// PDF 2 trang có text marker, cho postcondition read-back của harness.
    public static let pdf: Data = Data(base64Encoded: "JVBERi0xLjcKJcK1wrYKJSBXcml0dGVuIGJ5IE11UERGIDEuMjguMAoKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFIvSW5mbzw8L1Byb2R1Y2VyKE11UERGIDEuMjguMCk+Pj4+CmVuZG9iagoKMiAwIG9iago8PC9UeXBlL1BhZ2VzL0NvdW50IDIvS2lkc1s2IDAgUiA5IDAgUl0+PgplbmRvYmoKCjMgMCBvYmoKPDwvVHlwZS9Gb250L1N1YnR5cGUvVHlwZTEvQmFzZUZvbnQvSGVsdmV0aWNhL0VuY29kaW5nL1dpbkFuc2lFbmNvZGluZz4+CmVuZG9iagoKNCAwIG9iago8PC9Gb250PDwvRjAgMyAwIFI+Pj4+CmVuZG9iagoKNSAwIG9iago8PC9MZW5ndGggMTA0L0ZpbHRlci9GbGF0ZURlY29kZT4+CnN0cmVhbQp4nHMK4dJ3M1AwMlEISeMyUADBonQucyMFc2MDhZAULg3HqAAXN90AQ02FkCywUkMjiFJdYzOwAv+C1KLEksz8PIXk/Ly0/KLcxLzkVIW0zIqS0qJUHYWCxPRUBUM9sHbXEC4A5cMdfwplbmRzdHJlYW0KZW5kb2JqCgo2IDAgb2JqCjw8L1R5cGUvUGFnZS9NZWRpYUJveFswIDAgNTk1IDg0Ml0vUm90YXRlIDAvUmVzb3VyY2VzIDQgMCBSL0NvbnRlbnRzIDUgMCBSL1BhcmVudCAyIDAgUj4+CmVuZG9iagoKNyAwIG9iago8PC9Gb250PDwvRjAgMyAwIFI+Pj4+CmVuZG9iagoKOCAwIG9iago8PC9MZW5ndGggMTA0L0ZpbHRlci9GbGF0ZURlY29kZT4+CnN0cmVhbQp4nHMK4dJ3M1AwMlEISeMyUADBonQucyMFc2MDhZAULg3HqAAXN90AI02FkCywUkMjiFJdYzOwAv+C1KLEksz8PIXk/Ly0/KLcxLzkVIW0zIqS0qJUHYWCxPRUBSM9sHbXEC4A5hUdgQplbmRzdHJlYW0KZW5kb2JqCgo5IDAgb2JqCjw8L1R5cGUvUGFnZS9NZWRpYUJveFswIDAgNTk1IDg0Ml0vUm90YXRlIDAvUmVzb3VyY2VzIDcgMCBSL0NvbnRlbnRzIDggMCBSL1BhcmVudCAyIDAgUj4+CmVuZG9iagoKeHJlZgowIDEwCjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDA0MiAwMDAwMCBuIAowMDAwMDAwMTIwIDAwMDAwIG4gCjAwMDAwMDAxNzggMDAwMDAgbiAKMDAwMDAwMDI2NyAwMDAwMCBuIAowMDAwMDAwMzA2IDAwMDAwIG4gCjAwMDAwMDA0NzkgMDAwMDAgbiAKMDAwMDAwMDU4NSAwMDAwMCBuIAowMDAwMDAwNjI0IDAwMDAwIG4gCjAwMDAwMDA3OTcgMDAwMDAgbiAKCnRyYWlsZXIKPDwvU2l6ZSAxMC9Sb290IDEgMCBSPj4Kc3RhcnR4cmVmCjkwMwolJUVPRgo=")!
    /// Tài liệu phụ để gộp cho `insertDocument`. Harness nhận cùng một PDF làm phụ
    /// (đây cũng là cách `MuPDFOperationMatrixTests` gọi).
    public static let auxiliaryPDF: Data = pdf
    /// PNG 1×1 tối thiểu hợp lệ (69 byte), đúng bytes `MuPDFOperationMatrixTests` dùng.
    public static let imagePNG: Data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4z8AAAAMBAQD3A0FDAAAAAElFTkSuQmCC")!
}
