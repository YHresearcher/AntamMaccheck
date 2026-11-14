🌐 **Ngôn ngữ / Language:** Tiếng Việt | [English](README_EN.md)

# An Tâm  Check

<p align="center">
  <img src="resources/MascotSidebar.png" alt="Mascot An Tâm Check — laptop cầm bảng kiểm tra" width="180">
</p>

<p align="center"><strong>Ứng dụng kiểm tra Mac cũ trước khi mua của <a href="https://vitinhantam.com">Vi tính An Tâm</a>.</strong></p>

> **Bán bằng tâm để bạn yên tâm.**

Mở app lên, nó tự đọc cấu hình máy rồi dẫn bạn kiểm tra từng món: màn hình, bàn phím, trackpad, loa, micro, webcam, cổng kết nối, ngoại quan, pin, ổ cứng, MDM và Activation Lock. Xong thì trang Báo cáo tự tổng kết: máy ổn hay không, còn điểm nào cần lưu ý, và một lời nhắn của An Tâm ở cuối.

App viết bằng SwiftUI, chạy trên **macOS 13 trở lên**. Bản hiện tại là **1.2**.

## Tải về

- Tất cả các bản: https://github.com/YHresearcher/AntamMaccheck/releases
- Bản mới nhất (không cần đăng nhập GitHub): https://github.com/YHresearcher/AntamMaccheck/releases/latest/download/AnTam-Mac-check-macOS.zip

Tải zip về, giải nén 1 lần là có `An Tam Mac check.app`. Mở app lên dùng ngay, không cần kéo vào Applications.

### Mở app lần đầu

App chưa ký số Apple và chưa notarize (chỉ ký ad-hoc), nên macOS có thể chặn lúc mở:

1. Nhấp chuột phải vào app → **Open (Mở)** → bấm **Open**.
2. Nếu vẫn bị chặn: **System Settings → Privacy & Security → Open Anyway**.
3. Không tắt Gatekeeper toàn hệ thống, không chạy bằng quyền root.

## Ảnh thực tế

Ảnh chụp màn hình thật trên MacBook Pro (14-inch, 2023) M2 Pro:

### Tổng quan

<p align="center">
  <img src="docs/screenshots/overview.png" alt="Trang Tổng quan — thông tin máy, MDM, Activation Lock" width="800">
</p>

### Kiểm tra chi tiết

<p align="center">
  <img src="docs/screenshots/detailed-checks.png" alt="Trang Kiểm tra chi tiết — lưới 10 bài kiểm tra đều đạt" width="800">
</p>

### Báo cáo

<p align="center">
  <img src="docs/screenshots/report.png" alt="Trang Báo cáo — kết luận và kết quả chi tiết" width="800">
</p>

## Quyền riêng tư

App chỉ xin đúng **2 quyền**, và chỉ xin khi bạn tự bắt đầu bài test đó:

| Quyền | Khi nào | Dùng để làm gì |
| --- | --- | --- |
| **Camera** | Bài **Webcam** | Hiện hình trực tiếp để bạn tự xem. Không quay, không lưu, không gửi đi. |
| **Microphone** | Bài **Microphone** | Ghi thử rồi phát lại trên máy để bạn tự nghe. Chỉ lưu tạm trong máy. |

App **không** xin Screen Recording, Input Monitoring, Accessibility hay Location. Ngôn ngữ hộp thoại theo ngôn ngữ hệ thống macOS, không theo nút chuyển ngữ trong app. Lỡ bấm "Không cho phép" thì bật lại ở **System Settings → Privacy & Security → Camera / Microphone**.

<p align="center">
  <img src="docs/screenshots/permission-camera.png" alt="Hộp thoại xin quyền camera" width="300">
  <img src="docs/screenshots/permission-microphone.png" alt="Hộp thoại xin quyền microphone" width="300">
</p>

## Cách dùng

Sidebar có 3 mục: **Tổng quan** (thông tin máy, MDM + Activation Lock, tóm tắt "Đã pass x/10"), **Kiểm tra chi tiết** (lưới 10 bài + wizard từng bước), **Báo cáo** (kết luận, kết quả, lời nhắn An Tâm, xuất JSON). Nút **Giới thiệu** mở bảng giới thiệu shop; nút **EN/VI** (hình quả cầu) đổi toàn bộ giao diện, lựa chọn được nhớ cho lần sau.

### 10 bài kiểm tra

- **Màn hình:** 12 màu toàn màn hình (← / → đổi, Esc thoát), xem hết mới xác nhận được.
- **Bàn phím:** gõ phím thật, phím ảo sáng xanh; cần ít nhất 10 phím.
- **Trackpad:** di chuyển ngón tay, không cần click; cần ít nhất 10 lượt.
- **Loa:** nhạc stereo 8 giây (4 giây trái, 4 giây phải), nghe rè/méo/lệch không.
- **Microphone:** ghi âm rồi nghe lại, tự đánh giá độ rõ.
- **Webcam:** hiện hình trực tiếp, tự xem độ rõ và nhiễu.
- **Cổng kết nối:** danh sách thiết bị USB/Thunderbolt hệ thống thấy; cắm thiết bị thật vào từng cổng để chắc.
- **Ngoại quan:** kiểm tra bằng mắt (vỏ, bản lề, móp, pin phồng...).
- **Pin:** sức khỏe %, chu kỳ sạc; dưới 80% là đã suy giảm.
- **SSD:** từng ổ + SMART; SMART không đọc được không có nghĩa ổ hỏng hay tốt.

**Pin, MDM, Activation Lock:** pin dưới 80% hoặc quá 1000 chu kỳ thì tính chi phí thay. MDM: cả hai mục đều Không thì có khoảng 80% là không có MDM (không phải 100%). Activation Lock đang bật thì máy còn khóa tài khoản Apple của chủ cũ — không nên mua khi chưa gỡ.

## Kết luận (trang Báo cáo)

| Kết luận | Khi nào |
| --- | --- |
| **KHÔNG KHUYẾN NGHỊ MUA** | Có MDM/ADE, hoặc Activation Lock đang bật. |
| **PHÁT HIỆN LỖI — CẦN ĐÁNH GIÁ** | Có hạng mục lỗi, pin dưới 80%, hoặc SMART báo lỗi. |
| **CHƯA ĐỦ DỮ LIỆU** | Còn hạng mục chưa thử. |
| **CÓ ĐIỂM CẦN LƯU Ý** | Chức năng ổn nhưng pin 80–89%, quá 1000 chu kỳ, SMART chưa đọc được... |
| **MÁY ỔN** | 10/10 đều ổn. |

"An Tâm nhắn bạn" ở cuối trang Báo cáo: 1 cặp thơ theo kịch bản (máy ổn, dùng được, cần thương lượng, nhiều lỗi, không nên mua).

## Giới hạn cần biết

- Các bài kiểm tra do kỹ thuật viên tự quan sát và xác nhận, app không tự chẩn đoán. Chưa có test tải CPU/GPU.
- Kết luận không phải chứng nhận Mac an toàn để mua.
- App không gửi dữ liệu đi đâu.

## Build từ source

Cần macOS 13 trở lên có Swift toolchain: `swift run AnTamMacCheck`. Mỗi build thành công trên `main` tạo 1 Release mới kèm `AnTam-Mac-check-macOS.zip`.

## Thông tin shop

- **Vi tính An Tâm** — https://vitinhantam.com
- Chi nhánh 1: 52 Nguyễn Cửu Vân, P. Long An, T. Tây Ninh
- Chi nhánh 2: 218/3 đường số 11, phường Thủ Đức, TP. Hồ Chí Minh
- Bảo hành 6 tháng nguyên máy.

## Giấy phép

App theo **PolyForm Noncommercial License 1.0.0** (xem `LICENSE`): dùng/sửa/chia sẻ cho mục đích **phi thương mại**; dùng thương mại cần xin phép shop trước. Cách đọc pin tham khảo MacMonitor (MIT) — xem `THIRD_PARTY_NOTICES.md`.
