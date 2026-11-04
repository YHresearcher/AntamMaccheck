# An Tâm Mac check

Ứng dụng macOS dùng để hỗ trợ kiểm tra MacBook cũ trước khi mua, phát triển độc lập bằng SwiftUI.

## Mục tiêu
- Giao diện sáng, màu cam của Vi tính An Tâm
- Không chạy bài kiểm tra lúc mở ứng dụng
- Có nút tròn **Bắt đầu** và **Dừng**
- Tự đọc thông số cơ bản qua `system_profiler`, `sysctl`
- Quy trình kiểm tra ngoại vi có xác nhận kết quả và ghi chú lỗi
- Báo cáo JSON lưu vào thư mục do người dùng chọn (không mặc định ghi vào máy người bán)
- Kết luận phân biệt **đã kiểm tra**, **chưa kiểm tra** và **cảnh báo**

## Cách build
GitHub → Actions → Build An Tam Mac check → Run workflow → tải artifact.

Trên Mac có Xcode Command Line Tools:
```sh
swift build -c release
swift run AnTamMacCheck
```

## Giới hạn bản khởi tạo
Phiên bản 0.1 là nền tảng ứng dụng **chưa phải công cụ kiểm định MacBook hoàn chỉnh**. Không có stress CPU/GPU, SMART sâu, phát hiện Activation Lock/MDM chắc chắn hay bảo đảm mọi thiết bị ngoại vi tốt. Đọc được thông số không đồng nghĩa linh kiện đã qua thử nghiệm. Phần kiểm tra chức năng yêu cầu người dùng xác nhận. Bản tải qua GitHub Actions **chưa ký số/notarize** nên macOS có thể cảnh báo khi mở.

Dự án này hiện chưa nhập mã của Aman Check, mac-check hay battery-info-mac. Trước khi tái sử dụng mã bên thứ ba cần kiểm tra giấy phép và thông báo bản quyền.

Thương hiệu: **Vi tính An Tâm** — https://vitinhantam.com
