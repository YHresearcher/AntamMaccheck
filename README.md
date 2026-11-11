# An Tâm Mac check

Ứng dụng kiểm tra Mac cũ trước khi mua của **Vi tính An Tâm** — https://vitinhantam.com.

> **Bán bằng tâm để bạn yên tâm.**

Mở app lên, nó tự đọc cấu hình máy rồi dẫn bạn kiểm tra từng món: màn hình, bàn phím, trackpad, loa, micro, webcam, cổng kết nối, ngoại quan, pin, ổ cứng, MDM và Activation Lock. Xong hết thì trang Báo cáo tự tổng kết lại: máy ổn hay không, còn điểm nào cần lưu ý, và một lời nhắn của An Tâm ở cuối.

App viết bằng SwiftUI, chạy trên macOS 13 trở lên. Bản hiện tại là 1.2.

## Tải về

Bản mới nhất luôn nằm ở mục **Releases** của repo này. Mỗi lần có bản build mới trên nhánh `main` là có 1 Release mới, bản mới nhất được đánh dấu Latest:

- Xem tất cả các bản: https://github.com/YHresearcher/AntamMaccheck/releases
- Tải thẳng bản mới nhất (không cần đăng nhập GitHub): https://github.com/YHresearcher/AntamMaccheck/releases/latest/download/AnTam-Mac-check-macOS.zip

Tải file zip về, giải nén 1 lần là có `An Tam Mac check.app`, kéo vào thư mục Applications rồi mở.

## Mở app lần đầu

Bản này chưa ký số Apple và chưa notarize (chỉ ký ad-hoc để chống sửa đổi sau khi đóng gói), nên macOS có thể chặn lúc mở. Cách mở:

1. Nhấp chuột phải vào app rồi chọn **Open (Mở)**. Nếu vẫn bị chặn, vào **System Settings → Privacy & Security → Open Anyway**.
2. Không tắt Gatekeeper toàn hệ thống, không chạy bằng quyền root để vượt qua cảnh báo.

Nếu app thoát ngay hoặc không hiện cửa sổ, mở Terminal chạy:

```bash
"/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
```

Sao chép thông báo lỗi cuối cùng gửi cho nhóm phát triển. Kiểm tra thêm chữ ký và phiên bản macOS bằng:

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/An Tam Mac check.app"
file "/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
sw_vers -productVersion
```

## Cách dùng

Mở app là nó tự đọc cấu hình máy (tên máy, model ID, S/N, chip, RAM, macOS) và tự đọc pin với ổ cứng, không tự chạy test nào khác. Sidebar có 3 mục, theo thứ tự:

- **Tổng quan:** thẻ Thông tin Mac (tên thân thiện, Model ID, S/N, CPU, số nhân, RAM, SSD, pin + độ chai + đang sạc/không sạc, macOS), thẻ MDM, thẻ Activation Lock, và thẻ tóm tắt "Đã pass x/10 bài kiểm tra".
- **Kiểm tra chi tiết:** lưới 10 bài kiểm tra tô màu theo trạng thái, rồi wizard làm từng bước một. Mỗi bước có 4 lựa chọn: **Ổn rồi**, **Có lỗi** (ghi rõ lỗi gặp phải), **Chưa thử**, **Dừng toàn bộ**. Nút **Ổn rồi** chỉ bấm được sau khi bạn đã thực hiện bài test đó, không phải cứ mở lên là đạt. Bài Pin và SSD hiện số liệu đã đọc được rồi mới cho xác nhận.
- **Báo cáo:** kết luận tổng hợp, kết quả chi tiết, lời nhắn của An Tâm, và nút xuất báo cáo JSON (`AnTam-Mac-check-report.json`).

Nút **Giới thiệu** ở sidebar mở bảng giới thiệu shop (logo, slogan, 2 chi nhánh, bảo hành 6 tháng, vitinhantam.com, phiên bản).

### 10 bài kiểm tra

- **Màn hình:** test toàn màn hình với 12 màu. Dùng phím ← / → để chuyển màu, Esc để thoát. Phải xem hết 12 màu mới xác nhận được. App không tự phát hiện điểm chết hay ám màu, bạn tự quan sát.
- **Bàn phím:** gõ phím thật thì phím tương ứng trên bàn phím ảo sáng xanh. Cần nhận ít nhất 10 phím mới xác nhận được. Phím bổ trợ trái/phải (Caps, Shift, Ctrl, Option, Cmd, Fn) được nhận qua `flagsChanged` của macOS, vì chúng không gửi sự kiện bấm phím thường. Bàn phím MacBook tích hợp không có Ctrl phải, phím đó chỉ sáng khi dùng bàn phím rời.
- **Trackpad:** chỉ cần di chuyển ngón tay trên trackpad, không cần đè click. Cần ít nhất 10 lượt di chuyển. Chuột rời cũng tạo chuyển động tương tự, nên việc xác nhận trackpad thật vẫn cần người kiểm tra (thử click, kéo, cuộn, đa điểm).
- **Loa:** phát bản nhạc kiểm tra stereo 8 giây: 4 giây kênh trái trước, 4 giây kênh phải sau. Nghe từng bên xem có rè, méo hay lệch âm lượng không.
- **Microphone:** bấm ghi âm, nói một câu, dừng rồi bấm nghe lại để tự đánh giá độ rõ.
- **Webcam:** app xin quyền camera rồi hiện hình trực tiếp, bạn tự quan sát độ rõ và nhiễu.
- **Cổng kết nối:** đọc danh sách thiết bị USB/Thunderbolt mà hệ thống nhìn thấy. Muốn chắc từng cổng thì cắm thiết bị thật vào từng cổng và xem nó có xuất hiện trong danh sách không. Danh sách có thiết bị không có nghĩa mọi cổng vật lý đều tốt.
- **Ngoại quan:** kiểm tra bằng mắt: vỏ máy, bản lề, điểm móp, dấu tháo lắp, pin phồng, cổng sạc.
- **Pin:** hiện sức khỏe pin (%), số chu kỳ sạc và mức pin hiện tại. Nút "Ổn rồi" chỉ bấm được khi đã đọc được sức khỏe pin. Pin dưới 80% là đã suy giảm, nên tính chi phí thay.
- **SSD:** hiện từng ổ đã nhận diện (tên, dung lượng, SMART). Nút "Ổn rồi" chỉ bấm được khi đã nhận diện được ổ. SMART không đọc được không có nghĩa ổ hỏng, cũng không có nghĩa ổ tốt, chỉ là chưa xác nhận được.

### Pin, ổ cứng và Activation Lock

- **Pin (Battery Analyzer):** số chu kỳ sạc, dung lượng thiết kế, dung lượng sạc đầy gần nhất, sức khỏe ước tính theo phần trăm, mức sạc hiện tại. Tỉ lệ dung lượng chỉ là ước tính, không chứng nhận pin tốt.
- **Ổ lưu trữ và SMART:** tên ổ, dung lượng, trạng thái SMART. SMART không đọc được (thường gặp trên Apple Silicon) không có nghĩa ổ hỏng, cũng không có nghĩa ổ tốt, chỉ là chưa xác nhận được.
- **Activation Lock:** đọc được ngay trên máy, không cần mật khẩu hay xóa máy, bằng `system_profiler SPHardwareDataType`. Chỉ có trên máy Apple Silicon hoặc chip T2. Nếu đang bật thì máy còn khóa tài khoản Apple của chủ cũ, không nên mua khi chưa gỡ. Apple đã bỏ trang tra cứu công khai theo số serial từ 2017 nên không tra được từ xa. Chắc chắn nhất vẫn là xóa máy và kích hoạt lại xem có hỏi tài khoản Apple cũ không, nhưng đó chỉ là bước thêm, không bắt buộc.

### MDM

Bấm **Kiểm tra MDM** để app chạy `profiles status -type enrollment` và đọc 2 mục: MDM enrollment và Automated Enrollment (DEP).

- Một trong hai là Có thì kết luận chặn luôn: không khuyến nghị mua cho tới khi chủ sở hữu giải trình và gỡ quản lý hợp lệ.
- Cả hai đều là Không thì thiết bị của bạn có khoảng **80% là không có MDM**, không phải 100%. Để an tâm hơn, bạn nên kiểm tra thêm hồ sơ quản lý thiết bị, và chỉ xóa máy kích hoạt lại xem có hiện màn hình Remote Management không khi muốn chắc chắn hơn. Nhớ chỉ làm khi chủ máy đồng ý và đã sao lưu dữ liệu.
- Lệnh này chỉ đọc trạng thái hiện tại, không xác minh được quyền sở hữu hay liên kết Apple Business/School Manager trong mọi tình huống.

## Kết luận tổng hợp (trang Báo cáo)

Kết luận được tổng hợp tự động từ tất cả các tab, theo thứ tự ưu tiên: chặn, rồi lỗi, rồi chưa đủ dữ liệu, rồi lưu ý, rồi đạt.

| Kết luận | Khi nào |
| --- | --- |
| **KHÔNG KHUYẾN NGHỊ MUA** | Phát hiện MDM/ADE, hoặc Activation Lock đang bật. |
| **PHÁT HIỆN LỖI — CẦN ĐÁNH GIÁ** | Có hạng mục chức năng lỗi, pin dưới 80%, hoặc SMART báo lỗi. |
| **CHƯA ĐỦ DỮ LIỆU — CHƯA KẾT LUẬN ĐƯỢC** | Còn hạng mục chức năng chưa thử. |
| **ĐÃ HOÀN TẤT KIỂM TRA — CÓ ĐIỂM CẦN LƯU Ý** | Chức năng đều ổn nhưng còn điểm cần lưu ý: pin 80–89%, pin quá 1000 chu kỳ, SMART chưa đọc được, Activation Lock chưa xác định... |
| **MÁY ỔN — ĐẠT CÁC MỤC ĐÃ KIỂM TRA** | 10/10 hạng mục đều ổn: 8 bài chức năng đạt, pin từ 90%, SMART Verified, MDM cả hai mục đều Không, Activation Lock đã tắt. |

Ngưỡng pin theo Apple: dưới 80% là pin đã suy giảm, nên tính chi phí thay; trên 1000 chu kỳ là vượt mức thiết kế của MacBook.

**"An Tâm nhắn bạn"** nằm ở cuối trang Báo cáo, theo đúng cách app PCcheck của shop làm: 5 nhóm thơ của shop, chọn 1 cặp cố định theo kịch bản (máy ổn, máy dùng được, cần thương lượng, nhiều lỗi, không nên mua). Chưa đủ dữ liệu thì chưa có lời nhắn. Mascot cuối báo cáo cũng đổi theo kết quả. Kết luận tổng hợp, lời nhắn và Activation Lock đều có trong báo cáo JSON xuất ra.

## Giới hạn cần biết

- Các bài kiểm tra chức năng là do kỹ thuật viên tự quan sát và xác nhận, app không tự chẩn đoán thay bạn. Chưa có test tải CPU/GPU.
- Kết luận không phải chứng nhận Mac an toàn để mua. Nó chỉ tổng kết những gì đã kiểm tra được trong app.
- App không gửi dữ liệu đi đâu. Camera và micro chỉ bật khi bạn tự bắt đầu bài test đó, bản ghi âm chỉ lưu tạm trong máy.
- Kiểm tra MDM và Activation Lock chỉ đọc trạng thái hiện tại trên máy, không thay cho việc xóa máy và kích hoạt lại để kiểm tra cuối cùng với người bán.

## Build từ source

Cần macOS 13 trở lên có Swift toolchain:

```bash
swift run AnTamMacCheck
```

Build trên GitHub (Actions → **Build An Tam Mac check**) chạy mỗi khi push lên `main`, khi mở pull request và khi chạy tay. Mỗi build thành công trên `main` tạo 1 Release mới (tag `build-<số build>-<lần thử>`, đánh dấu Latest) kèm file `AnTam-Mac-check-macOS.zip`. Build của pull request thì không tạo Release. Artifact của build vẫn được giữ lại trong Actions để đối chiếu.

## Thông tin shop

- **Vi tính An Tâm** — https://vitinhantam.com
- Chi nhánh 1: 52 Nguyễn Cửu Vân, P. Long An, T. Tây Ninh
- Chi nhánh 2: 218/3 đường số 11, phường Thủ Đức, TP. Hồ Chí Minh
- Bảo hành 6 tháng nguyên máy (nội dung giới thiệu cửa hàng, không phải cam kết phần mềm).

## Giấy phép

Cách đọc pin tham khảo phương pháp chọn thuộc tính AppleSmartBattery của MacMonitor (MIT), không dùng giao diện hay cầu nối SMC riêng của họ — xem `THIRD_PARTY_NOTICES.md`. Dự án chưa nhập source của Aman Check, mac-check hay Battery Monitor. Bất kỳ mã bên thứ ba nào đưa vào sau này phải tuân thủ điều khoản cấp phép và giữ thông báo bản quyền.
