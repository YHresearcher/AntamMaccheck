import Foundation
import SwiftUI

/// Ngôn ngữ giao diện của An Tâm Check. Tiếng Việt là văn bản gốc trong
/// code; tiếng Anh nằm trong `enStrings` dưới đây. Lựa chọn được lưu trong
/// UserDefaults ("appLanguage") nên lần mở sau vẫn giữ ngôn ngữ đã chọn.
enum AppLanguage: String, CaseIterable {
    case vi, en
    /// Nhãn trên nút chuyển ngữ = ngôn ngữ sẽ chuyển SANG (như PCcheck).
    var toggleLabel: String { self == .vi ? "EN" : "VI" }
    /// Tên đầy đủ của ngôn ngữ sẽ chuyển sang, hiện cạnh nút.
    var toggleTargetName: String { self == .vi ? "English" : "Tiếng Việt" }
}

enum L10n {
    static let defaultsKey = "appLanguage"
    static var language: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "vi") ?? .vi }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }
}

/// Observable wrapper quanh `L10n.language` để SwiftUI vẽ lại mọi view
/// đang đọc nó khi user bấm chuyển ngữ. MainView giữ một `@StateObject`
/// LanguageStore và đẩy xuống `.environmentObject`; các view con
/// (DiagnosticToolView, HardwareHealthView) khai báo `@EnvironmentObject`
/// để tự vẽ lại — chỉ đổi UserDefaults thì view con không vẽ lại.
final class LanguageStore: ObservableObject {
    @Published var language: AppLanguage = L10n.language {
        didSet { L10n.language = language }
    }
    func toggle() { language = language == .vi ? .en : .vi }
}

/// Dịch một chuỗi giao diện tiếng Việt. Chuỗi không có trong từ điển thì
/// trả về nguyên văn tiếng Việt — không bao giờ hiện key, không bao giờ rỗng.
func tr(_ vi: String) -> String {
    guard L10n.language == .en else { return vi }
    if let en = enStrings[vi] { return en }
    for (prefix, enPrefix) in enPrefixes where vi.hasPrefix(prefix) {
        return enPrefix + String(vi.dropFirst(prefix.count))
    }
    return vi
}

/// Biến thể format-string: khóa trong từ điển là mẫu tiếng Việt
/// (giữ nguyên placeholder %d / %@ / %.1f%%); bản tiếng Anh giữ đúng
/// placeholder, đúng thứ tự, và %% cho dấu % thật.
func trf(_ vi: String, _ args: CVarArg...) -> String {
    String(format: tr(vi), arguments: args)
}

/// Chuỗi ghép từ tiền tố cố định + phần động (mô tả lỗi của hệ thống).
/// `tr()` thử khớp chính xác trước, không khớp thì dịch tiền tố, giữ nguyên
/// phần động (vốn đã là tiếng của hệ thống, không do app viết).
private let enPrefixes: [(String, String)] = [
    ("Lỗi phát âm thanh: ", "Audio playback error: "),
    ("Lỗi ghi âm: ", "Recording error: "),
    ("Không phát lại được: ", "Could not play back: "),
    ("Lỗi camera: ", "Camera error: "),
    ("Lỗi đọc thiết bị: ", "Error reading devices: "),
    ("Không chạy được lệnh profiles: ", "Could not run the profiles command: "),
    ("Chưa lưu được báo cáo: ", "Could not save the report: "),
]

/// Từ điển tiếng Anh. Khóa = đúng từng chữ tiếng Việt trong code (kể cả
/// placeholder và \n trong thơ); giá trị = bản tiếng Anh. Chuỗi logic nội bộ
/// (so sánh trạng thái "Ổn"/"Có lỗi", tên bài test trong switch) KHÔNG có
/// ở đây — chúng không hiển thị, chỉ được dịch lúc vẽ qua `tr()`.
///
/// Slogan + tên shop giữ nguyên là thương hiệu; câu slogan dịch sang tiếng
/// Anh theo yêu cầu "tất cả nội dung đều đổi". Địa chỉ chi nhánh là danh từ
/// riêng nên giữ nguyên, chỉ dịch nhãn "Chi nhánh 1/2".
/// 5 cặp thơ "An Tâm nhắn bạn" lấy nguyên bản thơ vần tiếng Anh của PCcheck
/// (Phrasings.json / anTamGroupsEn), theo đúng nhóm: blocked→notBuy[0],
/// error-ổ/pin→manyFaults[2], error-khác→fair[4], caution→negotiate[1],
/// good→good[4].
private let enStrings: [String: String] = [
    // MARK: - Shop / thương hiệu
    "Bán bằng tâm để bạn yên tâm": "Sold with care, so you can buy with peace of mind.",
    "Bảo hành 6 tháng nguyên máy": "6-month warranty on the whole machine",
    "Chi nhánh 1: ": "Branch 1: ",
    "Chi nhánh 2: ": "Branch 2: ",
    "An Tâm \u{F8FF} Check — công cụ hỗ trợ kiểm tra Mac đã qua sử dụng": "An Tâm \u{F8FF} Check — a tool for checking used Macs",
    "Tham quan shop": "Visit the shop",
    "Chuyển sang tiếng Anh": "Switch to Vietnamese",

    // MARK: - Điều hướng / trang
    "Tổng quan": "Overview",
    "Kiểm tra chi tiết": "Detailed checks",
    "Báo cáo": "Report",
    "Giới thiệu": "About",
    "Tổng quan thiết bị": "Device overview",
    "Màn hình này hiển thị thông tin Mac, trạng thái bảo mật và tiến độ các bài kiểm tra.": "This screen shows the Mac's information, security status and check progress.",
    "Thông tin Mac": "Mac information",
    "Kết quả kiểm tra nhanh": "Quick check results",
    "Danh sách bài kiểm tra (%d)": "Check list (%d)",
    "Kiểm tra lại": "Check again",
    "Xuất báo cáo": "Export report",
    "Đã pass": "Passed",
    "bài kiểm tra.": "checks.",
    "Tiếp tục kiểm tra chi tiết": "Continue detailed checks",
    "Làm mới": "Refresh",
    "Bấm Đọc cấu hình để xem thông số từ macOS nhé.": "Press Read configuration to see the specs from macOS.",
    "Hardware Information": "Hardware Information",

    // MARK: - Tên bài test (10 bài)
    "Màn hình": "Screen",
    "Bàn phím": "Keyboard",
    "Trackpad": "Trackpad",
    "Loa": "Speakers",
    "Microphone": "Microphone",
    "Webcam": "Webcam",
    "Cổng kết nối": "Ports",
    "Ngoại quan": "Appearance",
    "Pin": "Battery",
    "SSD": "SSD",

    // MARK: - Trạng thái chung
    "Ổn": "Passed",
    "Có lỗi": "Failed",
    "Chưa thử": "Not tried",
    "Đạt": "Passed",
    "Chưa đọc": "Not read",
    "Chưa xác định": "Not determined",
    "Không khả dụng": "Not available",
    "Chưa đủ dữ liệu": "Not enough data",
    "Đang kiểm tra": "Checking…",
    "Đang nhận diện Mac": "Identifying this Mac…",
    "Đang đọc...": "Reading…",
    "Đang sạc": "Charging",
    "Không sạc": "Not charging",
    "Có": "Yes",
    "Không": "No",
    "Đã tắt": "Off",
    "Đã bật": "On",
    "Không bật": "Off",
    "Chưa xác minh": "Not verified",
    "Chưa xác minh được trạng thái khóa.": "Could not verify the lock status.",
    "Thiết bị chưa bị khóa bởi iCloud.": "This device is not locked by iCloud.",
    "Thiết bị đang bị khóa bởi iCloud.": "This device is locked by iCloud.",
    "Không đọc được trạng thái": "Could not read status",
    "Chưa kiểm tra": "Not checked yet",

    // MARK: - Thẻ Thông tin Mac
    "Số nhân: %@ CPU / %@ GPU": "Cores: %@ CPU / %@ GPU",
    "Số nhân: %@ CPU": "Cores: %@ CPU",
    "%.0f%% (độ chai %.0f%%)": "%.0f%% (wear %.0f%%)",
    "Trạng thái pin": "Battery status",

    // MARK: - MDM
    "MDM (Quản lý thiết bị)": "MDM (Device Management)",
    "Phát hiện quản lý": "Management detected",
    "Chưa phát hiện quản lý hiện tại": "No management detected",
    "Lệnh macOS chỉ kiểm tra trạng thái hiện tại, không bảo đảm máy không thuộc Apple Business/School Manager. Hãy xác minh với người bán qua quy trình kích hoạt hợp lệ.": "The macOS command only checks the current state; it does not guarantee the machine is not owned by an Apple Business/School Manager organisation. Verify with the seller through a proper activation process.",
    "MDM enrollment và Automated Enrollment đều là Không — thiết bị của bạn có khoảng 80% là không bị quản lý MDM. Để an tâm hơn, bạn nên kiểm tra thêm hồ sơ quản lý thiết bị; xóa toàn bộ máy và kích hoạt lại chỉ là lựa chọn thêm để chắc chắn hơn, không bắt buộc.": "Both MDM enrollment and Automated Enrollment are No — your device is about 80% likely not managed by MDM. To be safer, check the device management profiles; erasing the machine and activating it again is only an extra step for more certainty, not required.",
    "An Tâm thấy dấu hiệu MDM/ADE! Cần xác minh kỹ trước khi mua nha.": "An Tâm found signs of MDM/ADE! Please verify carefully before buying.",
    "Đã đọc trạng thái MDM từ macOS. Nhớ xác minh với người bán nữa nhé.": "Read the MDM status from macOS. Remember to verify with the seller too.",
    "Kiểm tra thêm cho yên tâm nhé!": "A few extra checks for peace of mind!",
    "1. Kiểm tra hồ sơ quản lý": "1. Check the management profiles",
    "Mở Cài đặt hệ thống → Cài đặt chung → Quản lý thiết bị. Nếu có hồ sơ quản lý không rõ nguồn gốc, hãy hỏi người bán.": "Open System Settings → General → Device Management. If there is a management profile from an unknown source, ask the seller.",
    "2. Kiểm tra sau khi xóa và kích hoạt lại máy": "2. Check after erasing and reactivating the machine",
    "Chỉ là lựa chọn thêm để chắc chắn hơn, không bắt buộc — chỉ thực hiện khi chủ máy đồng ý và đã sao lưu dữ liệu. Kết nối Internet khi thiết lập lại, xem có màn hình Remote Management xuất hiện không.": "This is only an extra step for more certainty, not required — only do it with the owner's agreement and after backing up data. Connect to the Internet while setting up, and watch for a Remote Management screen.",
    "Cả hai mục đều là Không — thiết bị của bạn có khoảng 80% là không có MDM, không phải 100%.": "Both items are No — your device is about 80% likely to have no MDM, not 100%.",
    "Không phát hiện MDM không bảo đảm thiết bị chưa từng được tổ chức quản lý.": "No MDM detected does not guarantee the device was never managed by an organisation.",

    // MARK: - Kết luận mua (verdict)
    "KHÔNG KHUYẾN NGHỊ MUA": "NOT RECOMMENDED TO BUY",
    "PHÁT HIỆN LỖI — CẦN ĐÁNH GIÁ": "ISSUES FOUND — NEEDS REVIEW",
    "CHƯA ĐỦ DỮ LIỆU — CHƯA KẾT LUẬN ĐƯỢC": "NOT ENOUGH DATA — NO VERDICT YET",
    "ĐÃ HOÀN TẤT KIỂM TRA — CÓ ĐIỂM CẦN LƯU Ý": "CHECK COMPLETE — A FEW THINGS TO NOTE",
    "MÁY ỔN — ĐẠT CÁC MỤC ĐÃ KIỂM TRA": "MACHINE LOOKS GOOD — PASSED THE CHECKED ITEMS",
    "Đã phát hiện dấu hiệu quản lý MDM/ADE. Không khuyến nghị giao dịch cho tới khi chủ sở hữu giải trình và gỡ quản lý hợp lệ.": "Signs of MDM/ADE management were found. We do not recommend proceeding until the owner explains and properly removes the management.",
    "Activation Lock đang bật — máy còn khóa tài khoản Apple của chủ cũ. Không nên mua cho tới khi chủ cũ đăng xuất iCloud / gỡ khóa, hoặc xóa máy và kích hoạt lại mà không còn hỏi tài khoản cũ.": "Activation Lock is on — the machine is still locked to the previous owner's Apple account. Do not buy until the previous owner signs out of iCloud / removes the lock, or the machine is erased and reactivated without asking for the old account.",
    "Chức năng lỗi (%d): ": "Faulty functions (%d): ",
    ". Cần kiểm tra hoặc sửa chữa trước khi cân nhắc mua.": ". Please check or repair before considering a purchase.",
    "Chưa đủ dữ liệu để kết luận. Còn %d hạng mục chưa xác nhận: %@.": "Not enough data to conclude. %d items are still unconfirmed: %@.",
    "%d/%d bài kiểm tra đã xác nhận đạt. Còn điểm cần lưu ý: ": "%d/%d checks confirmed passed. Points to note: ",
    " MDM cả hai mục đều Không — không phát hiện quản lý MDM hiện tại.": " Both MDM items are No — no MDM management detected.",
    " Activation Lock đã tắt.": " Activation Lock is off.",
    "%d/%d bài kiểm tra đã xác nhận đạt": "%d/%d checks confirmed passed",
    "; pin còn %.1f%%": "; battery at %.1f%%",
    "; ổ %@ SMART Verified": "; drive %@ SMART Verified",
    "; MDM cả hai mục đều Không (không phát hiện quản lý MDM hiện tại); Activation Lock đã tắt.": "; both MDM items are No (no MDM management detected); Activation Lock is off.",
    " Chưa test tải CPU/GPU, và chưa xóa máy kiểm tra lại — hai bước này vẫn nên làm khi cần chắc chắn hơn, nhưng không bắt buộc.": " CPU/GPU load testing and a full erase-and-reactivate check have not been done yet — both are still worth doing when you need more certainty, but they are not required.",

    // MARK: - Phát hiện pin / ổ / Activation Lock
    "Pin còn %.1f%% (dưới 80%%) — đã suy giảm, nên tính chi phí thay pin": "Battery at %.1f%% (below 80%%) — degraded, factor in the cost of a replacement battery",
    "Pin còn %.1f%% — đã hao, thời gian dùng pin sẽ ngắn hơn": "Battery at %.1f%% — worn, battery life will be shorter",
    "Chưa đọc được sức khỏe pin": "Could not read battery health",
    "Pin đã qua %d chu kỳ sạc (vượt mốc 1000 của Apple)": "Battery has been through %d charge cycles (over Apple's 1000-cycle mark)",
    "Chưa đọc được pin (máy bàn không có pin, hoặc chưa đọc được dữ liệu)": "Could not read battery data (a desktop has no battery, or the data could not be read)",
    "Chưa nhận diện được ổ lưu trữ": "No storage drive detected",
    "Ổ %@: SMART báo lỗi (%@)": "Drive %@: SMART reports an error (%@)",
    "Ổ %@: chưa đọc được SMART — chưa xác nhận được sức khỏe ổ": "Drive %@: could not read SMART — drive health unconfirmed",
    "Chưa xác định được Activation Lock (máy không có trường này, hoặc chưa đọc được)": "Could not determine the Activation Lock status (this machine may not have this field, or it could not be read)",

    // MARK: - "An Tâm nhắn bạn" (thơ vần tiếng Anh của PCcheck)
    "Máy qua tay mấy người rồi,\nHỏi cho rõ gốc, kẻo ngồi âu lo.": "Through how many hands has this machine been?\nAsk where it's from, or you'll worry again.",
    "Kiểm cho thật kỹ hôm nay,\nMai sau khỏi tiếc, đắng cay một mình.": "Check it thoroughly today,\nso no bitter regret comes your way.",
    "Mua về chạy tốt mới vui,\nChứ còn sửa mãi, niềm vui còn gì.": "Joy is a machine that runs well from day one,\nendless repairs leave joy with none.",
    "Pin chai ổ yếu đừng quên,\nTrừ hao chi phí, nói lên giá mình.": "Worn battery, weak drive — keep in mind,\nsubtract the cost, and a fair price you'll find.",
    "Máy ngon chẳng ngại đem soi,\nCàng xem càng thích, càng coi càng mừng.": "A good machine fears no inspection,\nthe more you look, the more affection.",

    // MARK: - Wizard kiểm tra từng bước
    "Kiểm tra từng bước": "Step-by-step checks",
    "Bước %d/%d": "Step %d/%d",
    "Sức khỏe: ": "Health: ",
    "Chu kỳ sạc: ": "Charge cycles: ",
    "Mức pin: ": "Battery level: ",
    "Đọc lại thông tin pin": "Re-read battery info",
    "Đọc lại SSD": "Re-read SSD",
    "Chưa nhận diện được SSD vật lý.": "No physical SSD detected.",
    "SMART không khả dụng không đồng nghĩa ổ bị lỗi. Chưa bao gồm benchmark.": "SMART being unavailable does not mean the drive is faulty. No benchmark included.",
    "Hãy tự quan sát kết quả rồi xác nhận.": "Observe the result yourself, then confirm.",
    "Hãy thực hiện bài test trước khi xác nhận Đạt. Có thể chọn Có lỗi hoặc Chưa thử bất cứ lúc nào.": "Run the test before confirming Passed. You can choose Failed or Not tried at any time.",
    "Ổn rồi!": "All good!",
    "Dừng toàn bộ": "Stop all",
    "Phiên kiểm tra đã hoàn tất. Xem kết luận trong Báo cáo.": "The check session is complete. See the verdict in the Report.",
    "Phiên kiểm tra đang dừng. Mở Báo cáo để xem kết quả đã ghi nhận.": "The check session is paused. Open the Report to see the results so far.",
    "Xem kết quả & kết luận": "See results & verdict",
    "Bắt đầu kiểm tra mới": "Start a new check",

    // MARK: - Trang Báo cáo
    "Kết luận kiểm tra": "Check verdict",
    "Kết luận tổng hợp tự động từ 8 bài kiểm tra chức năng, pin, ổ lưu trữ/SMART, MDM và Activation Lock; chưa gồm tải CPU/GPU.": "Automatically summarised from 8 functional checks, battery, storage/SMART, MDM and Activation Lock; CPU/GPU load testing not included.",
    "Tiến độ phiên kiểm tra": "Check session progress",
    "%d/%d hạng mục": "%d/%d items",
    "Đã hoàn tất phiên kiểm tra.": "Check session complete.",
    "Tiếp tục kiểm tra": "Continue checking",
    "Còn bài chưa kiểm tra.": "Some checks are still unfinished.",
    "Kết quả chi tiết": "Detailed results",
    "Xuất báo cáo JSON": "Export JSON report",
    "Pin & Lưu trữ": "Battery & Storage",
    "Đọc lại dữ liệu": "Re-read data",
    "%.1f%% (ước tính)": "%.1f%% (estimated)",
    "Pin: ": "Battery: ",
    "Chu kỳ pin: ": "Battery cycles: ",
    "Ổ lưu trữ nhận diện: %d": "Storage drives detected: %d",
    "SMART không khả dụng không được coi là lỗi ổ.": "SMART being unavailable is not counted as a drive fault.",
    "An Tâm nhắn bạn": "A note from An Tâm",
    "Chưa đủ dữ liệu nên chưa có lời nhắn — làm nốt các mục còn thiếu rồi quay lại đây nhé.": "Not enough data for a note yet — finish the remaining items, then come back here.",

    // MARK: - Alert ghi nhận lỗi + About
    "Ghi nhận lỗi": "Report an issue",
    "Bạn gặp lỗi gì?": "What went wrong?",
    "Lưu lỗi & tiếp tục": "Save issue & continue",
    "Quay lại": "Go back",
    "Cứ mô tả thật dễ hiểu nhé, An Tâm sẽ lưu lại vào báo cáo.": "Just describe it in plain words — An Tâm will save it into the report.",
    "Đóng": "Close",

    // MARK: - Export JSON
    "Chưa có dữ liệu sức khỏe phần cứng.": "No hardware health data yet.",
    "Kết luận tổng hợp tự động từ kiểm tra chức năng, pin, ổ lưu trữ/SMART, MDM và Activation Lock; MDM chỉ đọc trạng thái profiles hiện tại; chưa test tải CPU/GPU; xóa máy và kích hoạt lại là bước chắc chắn thêm, không bắt buộc.": "Automatically summarised from functional checks, battery, storage/SMART, MDM and Activation Lock; MDM only reads the current profiles state; CPU/GPU load testing not done; erasing the machine and activating it again is an extra step for more certainty, not required.",

    // MARK: - Sức khỏe phần cứng (HardwareHealthView)
    "Chưa đọc dữ liệu": "No data read yet",
    "Đã thu thập dữ liệu khả dụng": "Available data collected",
    "Không đọc được danh sách ổ vật lý từ system_profiler.": "Could not read the physical drive list from system_profiler.",
    "Chưa nhận diện được ổ vật lý; không suy luận SSD hỏng.": "No physical drive detected; do not assume the SSD is faulty.",
    "Chỉ liệt kê ổ vật lý. APFS volumes được hiển thị riêng; SMART không khả dụng không đồng nghĩa SSD lỗi.": "Only physical drives are listed. APFS volumes are shown separately; SMART being unavailable does not mean the SSD is faulty.",
    "Sức khỏe phần cứng": "Hardware health",
    "Chu kỳ sạc": "Charge cycles",
    "Dung lượng thiết kế": "Design capacity",
    "Dung lượng sạc đầy gần nhất": "Full charge capacity",
    "Sức khỏe ước tính": "Estimated health",
    "Mức sạc hiện tại": "Current charge level",
    "Không tìm thấy AppleSmartBattery. Có thể máy không có pin hoặc macOS hạn chế dữ liệu.": "AppleSmartBattery not found. The machine may have no battery, or macOS may be restricting the data.",
    "Dữ liệu nguồn: ioreg / AppleSmartBattery; tỷ lệ dung lượng chỉ là ước tính, không chứng nhận pin tốt.": "Data source: ioreg / AppleSmartBattery; the capacity ratio is only an estimate, not proof of a healthy battery.",
    "Không có dữ liệu ổ lưu trữ phù hợp để hiển thị.": "No suitable storage data to display.",
    "Dung lượng": "Capacity",
    "Nguồn: %@": "Source: %@",
    "Xem các volume APFS (%d)": "Show APFS volumes (%d)",
    "Các volume nằm bên trong ổ vật lý, không phải ổ cứng riêng.": "These volumes live inside a physical drive; they are not separate drives.",
    "Trạng thái": "Status",
    "Đọc từ system_profiler SPHardwareDataType; chỉ có trên máy Apple Silicon / chip T2. Đã bật = máy còn khóa tài khoản Apple của chủ cũ, không nên mua khi chưa gỡ. Chắc chắn nhất vẫn là xóa máy và kích hoạt lại.": "Read from system_profiler SPHardwareDataType; only available on Apple Silicon / T2 machines. On = the machine is still locked to the previous owner's Apple account — do not buy before it is removed. The surest check is still to erase the machine and activate it again.",

    // MARK: - Công cụ kiểm tra (DiagnosticSession + DiagnosticToolView)
    "Chưa phát âm thanh": "No audio played yet",
    "Chưa ghi âm": "No recording yet",
    "Chưa mở camera": "Camera not opened yet",
    "Chưa đọc danh sách thiết bị kết nối.": "Connected-device list not read yet.",
    "Thiếu file stereo test WAV trong app. Không được đánh dấu Đạt.": "The stereo test WAV file is missing from the app. Do not mark as Passed.",
    "Đang phát nhạc thử: kênh trái trước, kênh phải sau. Hãy nghe từng bên.": "Playing the test tune: left channel first, then right. Listen to each side.",
    "Không phát được file test. Kiểm tra thiết bị đầu ra âm thanh.": "Could not play the test file. Check the audio output device.",
    "Chưa được cấp quyền Microphone": "Microphone permission not granted",
    "Không khởi động được ghi âm": "Could not start recording",
    "Đang ghi âm — hãy nói một câu rồi bấm Dừng": "Recording — say a sentence, then press Stop",
    "Đã ghi âm — bấm Nghe lại để tự đánh giá": "Recorded — press Play back to judge it yourself",
    "Chưa có bản ghi": "No recording yet",
    "Đang nghe lại — hãy đánh giá độ rõ tiếng.": "Playing back — judge how clear it sounds.",
    "Chưa được cấp quyền Camera": "Camera permission not granted",
    "Không tìm thấy camera": "No camera found",
    "Không thêm được camera": "Could not add the camera",
    "Đã mở camera — quan sát hình ở cửa sổ xem trước": "Camera open — watch the image in the preview window",
    "Đang đọc USB/Thunderbolt — danh sách chỉ xác nhận thiết bị được hệ thống nhìn thấy, không xác nhận mọi cổng vật lý.": "Reading USB/Thunderbolt — the list only confirms devices the system can see, not every physical port.",
    "Không đọc được.": "Could not read.",
    "system_profiler không trả kết quả hợp lệ.": "system_profiler did not return valid results.",
    "Kiểm tra toàn màn hình với 12 màu (RGB, CMY, nhiều mức xám, trắng/đen). Dùng phím ← / → để chuyển, Esc để thoát.": "Full-screen check with 12 colours (RGB, CMY, several greys, white/black). Use ← / → to change, Esc to exit.",
    "Mở test toàn màn hình": "Open full-screen test",
    "Đã xem %d/%d màu.": "Viewed %d/%d colours.",
    "Bàn phím ảo sáng lên khi phím vật lý được nhận. Nhấp vùng dưới để nhận bàn phím.": "The on-screen keyboard lights up when a physical key is recognised. Click the area below to capture the keyboard.",
    "Nhấp đây rồi gõ phím • Đã nhận %d phím": "Click here, then type • %d keys recognised",
    "Bấm từng phím bổ trợ trái/phải riêng để kiểm tra: Caps, Shift, Ctrl, Option, Cmd, Fn đều sáng khi nhận. Bàn phím MacBook tích hợp không có Ctrl phải — phím đó chỉ sáng khi dùng bàn phím rời.": "Press each left/right modifier separately to check it: Caps, Shift, Ctrl, Option, Cmd and Fn all light up when recognised. The built-in MacBook keyboard has no right Ctrl — that key only lights up with an external keyboard.",
    "Chỉ cần di chuyển ngón tay trên trackpad, KHÔNG cần đè click. Thử nhấp, kéo, cuộn và đa điểm riêng.": "Just move a finger on the trackpad, NO need to press click. Try tapping, dragging, scrolling and multi-touch separately.",
    "Di chuyển con trỏ trong vùng này — %d lượt di chuyển": "Move the pointer in this area — %d movements",
    "Chuột rời cũng tạo chuyển động tương tự. Việc xác nhận trackpad thật vẫn cần người kiểm tra.": "An external mouse creates similar movement. Confirming it is really the trackpad still needs a person to check.",
    "Phát bản nhạc kiểm tra stereo gốc: giai điệu kênh TRÁI, sau đó kênh PHẢI. Chú ý loa rè/méo và âm lượng từng bên.": "Plays the original stereo test tune: the LEFT channel melody, then the RIGHT channel. Listen for distortion and the volume of each side.",
    "♫ Phát file nhạc test trái/phải": "♫ Play the left/right test tune",
    "Ghi âm từ mic được chọn, sau đó nghe lại để xác nhận chất lượng.": "Record from the selected mic, then play it back to confirm the quality.",
    "■ Dừng ghi âm": "■ Stop recording",
    "● Ghi âm": "● Record",
    "▶ Nghe lại": "▶ Play back",
    "Xin quyền Camera, xem hình trực tiếp rồi đánh giá độ rõ và hiện tượng nhiễu.": "Grant camera permission, watch the live image, then judge its clarity and noise.",
    "Dừng camera": "Stop camera",
    "Mở camera": "Open camera",
    "Cắm từng cổng USB/Thunderbolt thực tế và quan sát thiết bị xuất hiện trong danh sách.": "Plug each real USB/Thunderbolt port and watch the device appear in the list.",
    "Làm mới thiết bị kết nối": "Refresh connected devices",
    "Kiểm tra bằng mắt: vỏ máy, bản lề, điểm móp, dấu tháo lắp, pin phồng, cổng và ngoại quan. Không tự xác nhận.": "Check by eye: case, hinges, dents, signs of opening, swollen battery, ports and appearance. Do not confirm by yourself.",

    // MARK: - Test toàn màn hình (màu)
    "Trắng": "White",
    "Đen": "Black",
    "Đỏ": "Red",
    "Xanh lá": "Green",
    "Xanh dương": "Blue",
    "Xám 25%": "Grey 25%",
    "Xám 50%": "Grey 50%",
    "Xám 75%": "Grey 75%",
    "Vàng": "Yellow",
    "Trắng ấm": "Warm white",
    "  %d/%d: %@    ← / → đổi màu    Esc thoát  ": "  %d/%d: %@    ← / → change colour    Esc to exit  ",
]
