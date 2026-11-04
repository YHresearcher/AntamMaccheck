# An Tâm Mac check

Ứng dụng kiểm tra Mac cũ trước khi mua của **Vi tính An Tâm** — https://vitinhantam.com.

## Thiết kế v0.1
- SwiftUI, nền sáng và điểm nhấn cam
- Sidebar: Tổng quan / Phần cứng / Kiểm tra / Báo cáo
- **Không tự chạy kiểm tra khi mở app**
- Start/Stop là hai nút tròn
- Đọc thông tin hệ thống cơ bản từ macOS khi bấm **Đọc cấu hình**
- Kiểm tra các hạng mục chức năng theo wizard và ghi nhận: Ổn / Có lỗi / Chưa thử
- Tự động đánh dấu chưa đủ dữ liệu nếu bỏ dở; xuất JSON qua hộp thoại lưu tệp
- Footer có hyperlink Vi tính An Tâm
- Dashboard/Báo cáo có thông tin 2 chi nhánh, bảo hành 6 tháng và nút Tham quan shop
- Kiểm tra MDM/ADE hiện tại qua `/usr/bin/profiles status -type enrollment` (bấm thủ công, chạy nền, không tự quét khi mở app)

## Giới hạn hiện tại
Đây là **bản khởi tạo chạy thử giao diện**, chưa phải phần mềm kiểm tra tự động hoàn chỉnh. Wizard hiện ghi nhận kết quả do người dùng xác nhận; chưa tự thực hiện test loa/micro, màn hình, bàn phím, SMART hay CPU/GPU stress. Kiểm tra MDM chỉ đọc trạng thái hiện tại do macOS trả về, không xác minh được quyền sở hữu, liên kết Apple Business/School Manager trong mọi tình huống hay Activation Lock. Không được hiểu kết luận từ wizard là chứng nhận Mac an toàn để mua.

Logo PNG gốc chưa được đưa vào repo. App đã có mã hiển thị `AnTamLogo.png` nếu resource tồn tại và dùng biểu tượng mặc định nếu chưa có.

### Thông tin shop
- Chi nhánh 1: **52 Nguyễn Cửu Vân, P. Long An, T. Tây Ninh**
- Chi nhánh 2: **218/3 đường số 11, phường Thủ Đức, TP. Hồ Chí Minh**
- Website: **https://vitinhantam.com**
- Chính sách hiển thị: **Bảo hành 6 tháng nguyên máy** (nội dung giới thiệu cửa hàng, không phải cam kết phần mềm).

## Build trên GitHub
1. Vào Actions → **Build An Tam Mac check** → Run workflow.
2. Tải artifact ZIP sau khi workflow thành công.
3. Giải nén trên Mac tương thích, mở ứng dụng. Bản này chưa ký số và chưa notarize, Gatekeeper có thể cảnh báo.

Có thể chạy locally trên macOS 13+ có Swift toolchain: `swift run AnTamMacCheck`.

## Kế hoạch tiếp theo
Kết nối adapters cho IOKit/System Profiler, kiểm tra pin/SSD và bổ sung hướng dẫn xác minh bảo mật khi kích hoạt lại với người bán; phát triển bài kiểm tra thực tế có Stop All; kiểm thử máy Intel và Apple Silicon; sau đó bổ sung logo nguyên gốc, địa chỉ shop, báo cáo PDF và ký số nếu phân phối.

## Giấy phép
Dự án mới chưa nhập source của Aman Check, mac-check hoặc Battery Monitor. Bất kỳ mã bên thứ ba nào được đưa vào sau này phải tuân thủ điều khoản cấp phép và giữ thông báo bản quyền.
