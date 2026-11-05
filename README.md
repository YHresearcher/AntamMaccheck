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

## Không mở được ứng dụng trên macOS

Gói tải từ GitHub Actions chứa ZIP lồng nhau: giải nén artifact `AnTam-Mac-check-macOS.zip` do GitHub tạo, rồi giải nén tiếp `AnTam-Mac-check-macOS.zip` nằm bên trong để nhận `An Tam Mac check.app`.

1. Kéo `An Tam Mac check.app` vào **Applications** trên Mac.
2. Nhấp chuột phải → **Open (Mở)**. Nếu bị chặn, vào **System Settings → Privacy & Security → Open Anyway** sau khi chắc chắn tải đúng nguồn.
3. Nếu app thoát ngay hoặc không có cửa sổ, mở **Terminal**, chạy:

```bash
"/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
```

Sao chép **thông báo lỗi cuối cùng** gửi cho nhóm phát triển. Có thể xem thêm chữ ký bằng:

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/An Tam Mac check.app"
file "/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
sw_vers -productVersion
```

Bản build được ký ad-hoc để đảm bảo gói `.app` không bị thay đổi sau khi đóng gói, nhưng **chưa notarize**. Vì vậy Gatekeeper vẫn có thể chặn file vừa tải về. Không nên tắt Gatekeeper trên toàn hệ thống hoặc chạy phần mềm bằng quyền root để vượt qua cảnh báo. Khi gặp lỗi, cần phân biệt rõ cảnh báo Gatekeeper, kiến trúc CPU không phù hợp, macOS quá cũ (yêu cầu macOS 13+), và app crash.

## Trải nghiệm mở ứng dụng & thương hiệu (bản cập nhật)

- Ứng dụng **tự đọc cấu hình** khi mở. Nút Làm mới vẫn giữ ở trang Thông tin Mac để chủ động đọc lại.
- Cửa sổ mặc định **1480 × 960**, đồng thời nới rộng khi macOS khôi phục kích thước cũ, có giới hạn theo màn hình hiện tại để không tràn màn hình.
- Bỏ menu **Hướng dẫn**.
- **Giới thiệu** mở cửa sổ popup riêng, có logo Vi tính An Tâm nguyên bản, hai địa chỉ chi nhánh, website và bảo hành 6 tháng.
- Slogan thống nhất: **“Bán bằng tâm để bạn an tâm”**.
- Thẻ thiết bị dùng **hình MacBook riêng**, không dùng ảnh laptop Windows.

## Tính năng kiểm tra trong bản thử mới

Giao diện `Kiểm tra chi tiết` có công cụ thực tế theo từng bước:
- **Màn hình:** vùng đổi 5 màu để quan sát điểm chết và ám màu; không tự nhận biết điểm chết, chưa thay thế test toàn màn hình.
- **Bàn phím:** vùng nhận mã phím thực; cần người dùng thử toàn bộ phím, ít nhất một phím mới cho phép xác nhận.
- **Trackpad:** vùng kéo tương tác; không phân biệt được thao tác bằng chuột rời và trackpad. Cần tự thử click/cuộn/đa điểm.
- **Loa:** phát lời nói qua đầu ra âm thanh hiện tại; người dùng nghe và xác nhận.
- **Microphone:** xin quyền hệ thống, ghi âm tạm và phát lại; không tự đánh giá chất lượng.
- **Webcam:** xin quyền hệ thống và phát hình xem trước; người dùng quan sát.
- **Cổng kết nối:** đọc danh sách thiết bị USB/Thunderbolt bằng `system_profiler`; **không** kết luận mọi cổng vật lý tốt chỉ từ danh sách.
- **Ngoại quan:** kiểm tra và xác nhận bằng mắt.

Nút **Ổn rồi** là xác nhận của kỹ thuật viên sau thao tác, không phải máy tự động chẩn đoán. Khi không thử có nút **Chưa thử**, khi phát hiện bất thường dùng **Có lỗi** để nhập mô tả. Chưa có kiểm tra tự động SSD SMART, pin, CPU/GPU stress, hay kết luận Activation Lock.

App có biểu tượng `AnTamMacCheck.icns` lấy từ logo SVG gốc. Build GitHub Actions có ký ad-hoc và xác minh ZIP nhưng **chưa notarized**.

## Kế hoạch tiếp theo
Kết nối adapters cho IOKit/System Profiler, kiểm tra pin/SSD và bổ sung hướng dẫn xác minh bảo mật khi kích hoạt lại với người bán; phát triển bài kiểm tra thực tế có Stop All; kiểm thử máy Intel và Apple Silicon; sau đó bổ sung logo nguyên gốc, địa chỉ shop, báo cáo PDF và ký số nếu phân phối.

## Giấy phép
Dự án mới chưa nhập source của Aman Check, mac-check hoặc Battery Monitor. Bất kỳ mã bên thứ ba nào được đưa vào sau này phải tuân thủ điều khoản cấp phép và giữ thông báo bản quyền.
