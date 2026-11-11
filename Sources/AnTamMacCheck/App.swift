import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let anTamOrange = Color(red: 0.94, green: 0.43, blue: 0.06)
private let backgroundColor = Color(red: 0.985, green: 0.975, blue: 0.965)
private let ink = Color(red: 0.16, green: 0.21, blue: 0.29)
private let mutedInk = Color(red: 0.43, green: 0.46, blue: 0.52)
private let warningBackground = Color(red: 1.0, green: 0.96, blue: 0.87)

enum Shop {
    static let name = "Vi tính An Tâm"
    static let website = URL(string: "https://vitinhantam.com")!
    static let branch1 = "52 Nguyễn Cửu Vân, P. Long An, T. Tây Ninh"
    static let branch2 = "218/3 đường số 11, phường Thủ Đức, TP. Hồ Chí Minh"
    static let warranty = "Bảo hành 6 tháng nguyên máy"
    static let address = "CN1: \(branch1) • CN2: \(branch2)"
}

struct MDMCheck: Codable {
    var status: String = "Chưa kiểm tra"
    var enrollment: String = "Chưa xác định"
    var automatedEnrollment: String = "Chưa xác định"
    var checkedAt: String = ""
    var details: String = ""
    var warning: String = "Lệnh macOS chỉ kiểm tra trạng thái hiện tại, không bảo đảm máy không thuộc Apple Business/School Manager. Hãy xác minh với người bán qua quy trình kích hoạt hợp lệ."
}

struct Result: Identifiable, Codable {
    var name: String
    var status: String
    var note: String
    var id: String { name }
}

@MainActor final class Inspection: ObservableObject {
    @Published var hardware: [String: String] = [:]
    @Published var mdm = MDMCheck()
    @Published var checkingMDM = false
    @Published var results: [Result] = []
    @Published var running = false
    @Published var step = 0
    @Published var errorNote = ""
    @Published var info = "Bán bằng tâm để bạn an tâm"
    let checks = ["Màn hình", "Bàn phím", "Trackpad", "Loa", "Microphone", "Webcam", "Cổng kết nối", "Ngoại quan", "Pin", "SSD"]

    /// Mức kết luận tổng hợp từ TẤT CẢ các tab (chức năng + pin + ổ +
    /// MDM + Activation Lock), theo thứ tự ưu tiên như PCcheck
    /// (chặn > lỗi > chưa đủ dữ liệu > lưu ý > đạt). Trước đây kết luận chỉ
    /// nhìn 8 bài chức năng và MDM, nên pin/SSD đã đọc rồi vẫn không đổi
    /// được kết luận — đó là lý do trang Báo cáo cứ dừng ở "cần xác minh thêm".
    enum OverallTier { case blocked, error, incomplete, caution, good }

    /// Phát hiện từ pin / ổ / Activation Lock. Ngưỡng theo Apple: pin dưới
    /// 80% là đã suy giảm, nên tính chi phí thay; trên 1000 chu kỳ là vượt
    /// mức thiết kế của MacBook. SMART báo "Failing" là lỗi ổ thật; SMART
    /// không đọc được thì chỉ là chưa xác nhận, không tính là lỗi ổ.
    func healthFindings(for health: HardwareHealthSnapshot?) -> (errors: [String], cautions: [String]) {
        guard let health else { return ([], []) }
        var errors: [String] = []
        var cautions: [String] = []
        let b = health.battery
        if b.present {
            if let pct = b.healthPercent {
                if pct < 80 {
                    errors.append(String(format: "Pin còn %.1f%% (dưới 80%%) — đã suy giảm, nên tính chi phí thay pin", pct))
                } else if pct < 90 {
                    cautions.append(String(format: "Pin còn %.1f%% — đã hao, thời gian dùng pin sẽ ngắn hơn", pct))
                }
            } else {
                cautions.append("Chưa đọc được sức khỏe pin")
            }
            if let cycles = b.cycleCount, cycles > 1000 {
                cautions.append("Pin đã qua \(cycles) chu kỳ sạc (vượt mốc 1000 của Apple)")
            }
        } else {
            cautions.append("Chưa đọc được pin (máy bàn không có pin, hoặc chưa đọc được dữ liệu)")
        }
        if health.storage.isEmpty {
            cautions.append("Chưa nhận diện được ổ lưu trữ")
        }
        for disk in health.storage {
            let smart = disk.smart.lowercased()
            if smart.contains("fail") {
                errors.append("Ổ \(disk.name): SMART báo lỗi (\(disk.smart))")
            } else if smart == "không khả dụng" {
                cautions.append("Ổ \(disk.name): chưa đọc được SMART — chưa xác nhận được sức khỏe ổ")
            }
        }
        if health.activationLock == "Chưa xác định" {
            cautions.append("Chưa xác định được Activation Lock (máy không có trường này, hoặc chưa đọc được)")
        }
        return (errors, cautions)
    }

    func overallTier(for health: HardwareHealthSnapshot? = nil) -> OverallTier {
        if mdm.status == "Phát hiện quản lý" || health?.activationLock == "Đã bật" { return .blocked }
        let findings = healthFindings(for: health)
        if results.contains(where: { $0.status == "Có lỗi" }) || !findings.errors.isEmpty { return .error }
        if results.count < checks.count || results.contains(where: { $0.status == "Chưa thử" }) { return .incomplete }
        if !findings.cautions.isEmpty { return .caution }
        return .good
    }

    func verdictTitle(for health: HardwareHealthSnapshot? = nil) -> String {
        switch overallTier(for: health) {
        case .blocked: return "KHÔNG KHUYẾN NGHỊ MUA"
        case .error: return "PHÁT HIỆN LỖI — CẦN ĐÁNH GIÁ"
        case .incomplete: return "CHƯA ĐỦ DỮ LIỆU — CHƯA KẾT LUẬN ĐƯỢC"
        case .caution: return "ĐÃ HOÀN TẤT KIỂM TRA — CÓ ĐIỂM CẦN LƯU Ý"
        case .good: return "MÁY ỔN — ĐẠT CÁC MỤC ĐÃ KIỂM TRA"
        }
    }

    func conclusion(for health: HardwareHealthSnapshot? = nil) -> String {
        let tier = overallTier(for: health)
        let findings = healthFindings(for: health)
        switch tier {
        case .blocked:
            if mdm.status == "Phát hiện quản lý" {
                return "Đã phát hiện dấu hiệu quản lý MDM/ADE. Không khuyến nghị giao dịch cho tới khi chủ sở hữu giải trình và gỡ quản lý hợp lệ."
            }
            return "Activation Lock đang bật — máy còn khóa tài khoản Apple của chủ cũ. Không nên mua cho tới khi chủ cũ đăng xuất iCloud / gỡ khóa, hoặc xóa máy và kích hoạt lại mà không còn hỏi tài khoản cũ."
        case .error:
            var parts: [String] = []
            let functional = results.filter { $0.status == "Có lỗi" }
            if !functional.isEmpty {
                parts.append("Chức năng lỗi (\(functional.count)): " + functional.map {
                    $0.note.isEmpty ? $0.name : "\($0.name): \($0.note)"
                }.joined(separator: "; "))
            }
            parts.append(contentsOf: findings.errors)
            return parts.joined(separator: ". ") + ". Cần kiểm tra hoặc sửa chữa trước khi cân nhắc mua."
        case .incomplete:
            let unknown = checks.filter { name in
                guard let result = results.first(where: { $0.name == name }) else { return true }
                return result.status == "Chưa thử"
            }
            return "Chưa đủ dữ liệu để kết luận. Còn \(unknown.count) hạng mục chưa xác nhận: \(unknown.joined(separator: ", "))."
        case .caution:
            var text = "(checks.count)/(checks.count) bài kiểm tra đã xác nhận đạt. Còn điểm cần lưu ý: " + findings.cautions.joined(separator: "; ") + "."
            if mdm.enrollment == "Không" && mdm.automatedEnrollment == "Không" {
                text += " MDM cả hai mục đều Không — không phát hiện quản lý MDM hiện tại."
            }
            if health?.activationLock == "Đã tắt" { text += " Activation Lock đã tắt." }
            return text
        case .good:
            var text = "(checks.count)/(checks.count) bài kiểm tra đã xác nhận đạt"
            if let pct = health?.battery.healthPercent {
                text += String(format: "; pin còn %.1f%%", pct)
            }
            if let verified = health?.storage.filter({ $0.smart.lowercased() == "verified" }).map({ $0.name }),
               !verified.isEmpty {
                text += "; ổ \(verified.joined(separator: ", ")) SMART Verified"
            }
            text += "; MDM cả hai mục đều Không (không phát hiện quản lý MDM hiện tại); Activation Lock đã tắt."
            text += " Chưa test tải CPU/GPU, và chưa xóa máy kiểm tra lại — hai bước này vẫn nên làm khi cần chắc chắn hơn, nhưng không bắt buộc."
            return text
        }
    }

    /// Lời nhắn "An Tâm nhắn bạn" ở cuối Báo cáo, theo đúng cách PCcheck làm:
    /// 5 nhóm thơ của shop, chọn 1 cặp cố định theo kịch bản (không random lại
    /// mỗi lần vẽ); chưa đủ dữ liệu thì không có lời nhắn. Các cặp thơ lấy
    /// nguyên văn từ nhóm thơ của PCcheck (Phrasings.json / anTamGroups).
    func reassuranceNote(for health: HardwareHealthSnapshot? = nil) -> String? {
        let tier = overallTier(for: health)
        let findings = healthFindings(for: health)
        switch tier {
        case .blocked:
            return "Máy qua tay mấy người rồi,\nHỏi cho rõ gốc, kẻo ngồi âu lo."
        case .error:
            if findings.errors.contains(where: { $0.hasPrefix("Ổ ") || $0.hasPrefix("Pin còn") }) {
                return "Kiểm cho thật kỹ hôm nay,\nMai sau khỏi tiếc, đắng cay một mình."
            }
            return "Mua về chạy tốt mới vui,\nChứ còn sửa mãi, niềm vui còn gì."
        case .incomplete:
            return nil
        case .caution:
            return "Pin chai ổ yếu đừng quên,\nTrừ hao chi phí, nói lên giá mình."
        case .good:
            return "Máy ngon chẳng ngại đem soi,\nCàng xem càng thích, càng coi càng mừng."
        }
    }

    /// Mascot cuối Báo cáo đổi theo kết quả như PCcheck: máy ổn thì mascot
    /// checklist, còn lại mascot suy nghĩ (chỉ có 2 mascot này trong bản Mac).
    func reassuranceMascot(for health: HardwareHealthSnapshot? = nil) -> String {
        overallTier(for: health) == .good ? "MascotChecklist" : "MascotThinking"
    }
    func checkMDM() {
        guard !checkingMDM else { return }
        checkingMDM = true
        mdm = MDMCheck(status: "Đang kiểm tra")
        // Chạy lệnh ở background để giao diện không bị đứng.
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
            process.arguments = ["status", "-type", "enrollment"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            var raw = ""
            var exitCode: Int32 = -1
            do {
                try process.run()
                let bytes = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                exitCode = process.terminationStatus
                raw = String(data: bytes, encoding: .utf8) ?? ""
            } catch {
                raw = "Không chạy được lệnh profiles: \(error.localizedDescription)"
            }

            func value(for key: String) -> String {
                let pattern = "(?im)^\\s*" + NSRegularExpression.escapedPattern(for: key) + "\\s*:\\s*(Yes|No)\\b"
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
                      let range = Range(match.range(at: 1), in: raw) else { return "Chưa xác định" }
                return raw[range].lowercased() == "yes" ? "Có" : "Không"
            }
            let enrollment = value(for: "MDM enrollment")
            let automated = value(for: "Enrolled via DEP")
            let status: String
            if exitCode != 0 {
                status = "Không đọc được trạng thái"
            } else if enrollment == "Có" || automated == "Có" {
                status = "Phát hiện quản lý"
            } else if enrollment == "Không" && automated == "Không" {
                status = "Chưa phát hiện quản lý hiện tại"
            } else {
                status = "Chưa đủ dữ liệu"
            }
            // Cả hai mục đều Không: thiết bị của bạn có khoảng 80% là không
            // có MDM, không phải 100%. Xóa toàn bộ máy và kích hoạt lại chỉ
            // là lựa chọn thêm để chắc chắn hơn, không bắt buộc.
            let warning: String
            if enrollment == "Không" && automated == "Không" {
                warning = "MDM enrollment và Automated Enrollment đều là Không — không phát hiện quản lý MDM hiện tại. Để an tâm hơn, bạn nên kiểm tra thêm hồ sơ quản lý thiết bị; xóa toàn bộ máy và kích hoạt lại chỉ là lựa chọn thêm để chắc chắn hơn, không bắt buộc."
            } else {
                warning = MDMCheck().warning
            }
            let result = MDMCheck(
                status: status,
                enrollment: enrollment,
                automatedEnrollment: automated,
                checkedAt: ISO8601DateFormatter().string(from: Date()),
                details: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                warning: warning
            )
            DispatchQueue.main.async {
                self.mdm = result
                self.checkingMDM = false
                self.info = status == "Phát hiện quản lý"
                    ? "An Tâm thấy dấu hiệu MDM/ADE! Cần xác minh kỹ trước khi mua nha."
                    : "Đã đọc trạng thái MDM từ macOS. Nhớ xác minh với người bán nữa nhé."
            }
        }
    }

    func readHardware() {
        let queries: [(String, String, [String])] = [
            ("Model", "/usr/sbin/sysctl", ["-n", "hw.model"]),
            ("Chip / CPU", "/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"]),
            ("CPU logic", "/usr/sbin/sysctl", ["-n", "hw.logicalcpu"]),
            ("RAM (bytes)", "/usr/sbin/sysctl", ["-n", "hw.memsize"]),
            ("macOS", "/usr/bin/sw_vers", ["-productVersion"])
        ]
        var values: [String: String] = [:]
        var modelIdentifier = "Không khả dụng"
        for (name, path, args) in queries {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            do {
                try p.run()
                let output = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let value = p.terminationStatus == 0 ? (String(data: output, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : ""
                values[name] = value.isEmpty ? "Không khả dụng" : value
                if name == "Model" { modelIdentifier = values[name] ?? "Không khả dụng" }
            } catch { values[name] = "Không khả dụng" }
        }
        // Trên Apple Silicon, machdep.cpu.brand_string thường không tồn tại.
        // system_profiler cung cấp chip_type thực tế (Apple M1/M2/M3/...).
        if values["Chip / CPU"] == "Không khả dụng" {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPHardwareDataType", "-json"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = Pipe()
            do {
                try p.run()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if p.terminationStatus == 0,
                   let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let entries = root["SPHardwareDataType"] as? [[String: Any]],
                   let device = entries.first {
                    if let chip = device["chip_type"] as? String, !chip.isEmpty {
                        values["Chip / CPU"] = chip
                    }
                    if let model = device["machine_name"] as? String, !model.isEmpty {
                        values["Model"] = model
                    }
                }
            } catch { /* Giữ trạng thái Không khả dụng thay vì bịa CPU. */ }
        }
        values["Model Identifier"] = values["Model Identifier"] ?? modelIdentifier
        hardware = values
        info = "Đã đọc cấu hình cơ bản rồi nè! Đây chưa phải kết quả kiểm tra sức khỏe nha."
    }
    func start() {
        guard !running else { return }
        results = []
        step = 0
        errorNote = ""
        running = true
        info = "Bắt đầu rồi! Mình cùng kiểm tra từng mục nhé."
    }
    func record(_ status: String) {
        guard running && step < checks.count else { return }
        if status == "Có lỗi" && errorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        results.append(Result(name: checks[step], status: status, note: status == "Có lỗi" ? errorNote : ""))
        errorNote = ""
        step += 1
        if step == checks.count {
            running = false
            info = "Đã hoàn tất các bài test. Xem kết luận và các cảnh báo trong Báo cáo."
        }
    }
    func resume() {
        guard !running && step < checks.count else { return }
        running = true
        info = "Tiếp tục phiên kiểm tra từ bước \(step + 1)/\(checks.count)."
    }
    func stop() {
        running = false
        info = "Đã dừng kiểm tra. Những mục chưa thử sẽ không được tính là đạt nha."
    }
    func exportJSON(health: HardwareHealthSnapshot? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "AnTam-Mac-check-report.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let payload: [String: Any] = [
            "application": "An Tâm Mac check",
            "shop": Shop.name,
            "website": Shop.website.absoluteString,
            "address": Shop.address,
            "branches": [Shop.branch1, Shop.branch2],
            "warranty": Shop.warranty,
            "mdm": [
                "status": mdm.status,
                "enrollment": mdm.enrollment,
                "automated_enrollment": mdm.automatedEnrollment,
                "checked_at": mdm.checkedAt,
                "command_output": mdm.details,
                "warning": mdm.warning
            ],
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "hardware": hardware,
            "hardware_health": [
                "battery": [
                    "present": health?.battery.present as Any? ?? NSNull(),
                    "cycle_count": health?.battery.cycleCount as Any? ?? NSNull(),
                    "design_mAh": health?.battery.designMAh as Any? ?? NSNull(),
                    "full_charge_mAh": health?.battery.maxMAh as Any? ?? NSNull(),
                    "estimated_health_percent": health?.battery.healthPercent as Any? ?? NSNull()
                ],
                "storage": health?.storage.map { [
                    "name": $0.name, "capacity": $0.capacity,
                    "smart_status": $0.smart, "source": $0.source
                ] } ?? [],
                "activation_lock": health?.activationLock as Any? ?? NSNull(),
                "limitation": health?.diskInfo ?? "Chưa có dữ liệu sức khỏe phần cứng."
            ] as [String: Any],
            "tests": results.map { ["name": $0.name, "status": $0.status, "note": $0.note] },
            "verdict": verdictTitle(for: health),
            "conclusion": conclusion(for: health),
            "health_assessment": [
                "errors": healthFindings(for: health).errors,
                "cautions": healthFindings(for: health).cautions
            ] as [String: Any],
            "an_tam_nhan_ban": reassuranceNote(for: health) as Any? ?? NSNull(),
            "limitations": "Kết luận tổng hợp tự động từ kiểm tra chức năng, pin, ổ lưu trữ/SMART, MDM và Activation Lock; MDM chỉ đọc trạng thái profiles hiện tại; chưa test tải CPU/GPU; xóa máy và kích hoạt lại là bước chắc chắn thêm, không bắt buộc."
        ]
        do {
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: url, options: .atomic)
            info = "Đã lưu báo cáo. Cảm ơn bạn đã dùng An Tâm Mac check!"
        } catch { info = "Chưa lưu được báo cáo: \(error.localizedDescription)" }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case overview = "Tổng quan", inspection = "Kiểm tra chi tiết", report = "Báo cáo"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .inspection: return "checkmark.shield"
        case .report: return "doc.text"
        }
    }
}

struct MainView: View {
    @StateObject private var inspection = Inspection()
    @State private var page: Page = .overview
    @State private var showIssue = false
    @State private var showAbout = false
    @StateObject private var tools = DiagnosticSession()
    @StateObject private var health = HardwareHealthModel()

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    assetImage("AnTamLogo", width: 55, height: 55)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("An Tâm Mac check").font(.system(size: 17, weight: .bold))
                        Text("Bán bằng tâm để bạn an tâm")
                            .font(.system(size: 10)).foregroundStyle(mutedInk)
                    }
                }.padding(.horizontal, 12).padding(.top, 18)
                VStack(spacing: 8) {
                    navButton(.overview, "house.fill")
                    navButton(.inspection, "checklist")
                    navButton(.report, "chart.bar.fill")
                    Button { showAbout = true } label: {
                        Label("Giới thiệu", systemImage: "info.circle")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 12).padding(.top, 15)
                Spacer()
                assetImage("MascotChecklist", width: 215, height: 260)
                    .frame(maxWidth: .infinity)
                Link(destination: Shop.website) {
                    Label("vitinhantam.com", systemImage: "globe")
                        .font(.caption).foregroundStyle(mutedInk)
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }
            .frame(minWidth: 235, maxWidth: 245, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(ink)
            .background(Color(red: 1.0, green: 0.97, blue: 0.935))
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if page != .overview {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(page.rawValue).font(.system(size: 29, weight: .bold))
                                Text("Bán bằng tâm để bạn an tâm")
                                    .font(.subheadline).foregroundStyle(mutedInk)
                            }
                            Spacer()
                        }
                    }
                    switch page {
                    case .overview: overview
                    case .inspection: testWizard
                    case .report: report
                    }
                    Spacer(minLength: 10)
                }.padding(26).frame(maxWidth: 1160, alignment: .leading)
            }.background(backgroundColor)
        }
        // Brand uses fixed light surfaces. Never inherit white text from macOS Dark Mode.
        .preferredColorScheme(.light)
        .foregroundStyle(ink)
        .tint(anTamOrange)
        .frame(minWidth: 940, minHeight: 680)
        .sheet(isPresented: $showAbout) {
            aboutPopup
        }
        .onAppear {
            // Mở rộng ngay cả khi macOS khôi phục kích thước cửa sổ cũ.
            DispatchQueue.main.async {
                let window = NSApp.keyWindow
                    ?? NSApp.windows.first(where: { $0.title.contains("An Tâm Mac check") })
                if let window, !window.styleMask.contains(.fullScreen),
                   let screen = window.screen ?? NSScreen.main {
                    let visible = screen.visibleFrame
                    let width = min(1480.0, max(940.0, visible.width - 24))
                    let height = min(960.0, max(680.0, visible.height - 64))
                    if window.contentLayoutRect.width < width - 24 {
                        window.setContentSize(NSSize(width: width, height: height))
                        window.center()
                    }
                }
            }
            // Tự đọc cấu hình, không tự chạy stress test hay can thiệp quyền riêng tư.
            if inspection.hardware.isEmpty { inspection.readHardware() }
            if health.snapshot.readAt == nil { health.refresh() }
        }
        .alert("Ghi nhận lỗi", isPresented: $showIssue) {
            TextField("Bạn gặp lỗi gì?", text: $inspection.errorNote)
            Button("Lưu lỗi & tiếp tục") {
                inspection.record("Có lỗi")
                tools.stopCamera()
                tools.stopRecording()
                if !inspection.running { page = .report }
            }
                .disabled(inspection.errorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Quay lại", role: .cancel) {}
        } message: { Text("Cứ mô tả thật dễ hiểu nhé, An Tâm sẽ lưu lại vào báo cáo.") }
    }

    private var aboutPopup: some View {
        VStack(spacing: 17) {
            assetImage("AnTamLogo", width: 100, height: 100)
            Text("VI TÍNH AN TÂM")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Text("Bán bằng tâm để bạn an tâm")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(anTamOrange)
                .multilineTextAlignment(.center)
            Divider()
            VStack(alignment: .leading, spacing: 13) {
                Label("Chi nhánh 1: " + Shop.branch1, systemImage: "mappin.circle")
                Label("Chi nhánh 2: " + Shop.branch2, systemImage: "mappin.circle")
                Label(Shop.warranty, systemImage: "checkmark.shield")
                Link(destination: Shop.website) {
                    Label("vitinhantam.com", systemImage: "globe")
                }
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("An Tâm Mac check — công cụ hỗ trợ kiểm tra Mac đã qua sử dụng")
                .font(.caption).foregroundStyle(mutedInk)
            Button("Đóng") { showAbout = false }
                .keyboardShortcut(.cancelAction)
                .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 510)
        .background(backgroundColor)
        .foregroundStyle(ink)
        .preferredColorScheme(.light)
    }

    private func assetImage(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let path = Bundle.main.path(forResource: name, ofType: "png"),
               let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: name == "MacBookPreview" ? "laptopcomputer" : "checkmark.shield.fill")
                    .resizable().scaledToFit().foregroundStyle(anTamOrange)
            }
        }.frame(width: width, height: height)
    }

    private func navButton(_ destination: Page, _ icon: String) -> some View {
        Button { page = destination } label: {
            HStack(spacing: 13) {
                Image(systemName: icon).frame(width: 23)
                Text(destination.rawValue).font(.system(size: 14, weight: page == destination ? .bold : .medium))
                Spacer()
            }
            .foregroundStyle(page == destination ? anTamOrange : ink)
            .padding(.horizontal, 13).padding(.vertical, 12)
            .background(page == destination ? anTamOrange.opacity(0.13) : Color.white.opacity(0.56),
                        in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(ink)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
    }
    private func statusLine(_ label: String, _ detail: String, symbol: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(anTamOrange)
                .frame(width: 30, height: 30)
                .background(anTamOrange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            Text(label).font(.system(size: 13, weight: .semibold))
                .frame(width: 140, alignment: .leading)
            Text(detail).font(.system(size: 12)).foregroundStyle(mutedInk)
                .lineLimit(2)
            Spacer(minLength: 6)
            Image(systemName: done ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(done ? Color.green : Color.gray)
        }
        .padding(.vertical, 5)
    }

    private func testColor(_ name: String) -> Color {
        switch name {
        case "Màn hình": return Color(red: 0.83, green: 0.93, blue: 1.0)
        case "Loa": return Color(red: 0.91, green: 0.90, blue: 1)
        case "Webcam": return Color(red: 0.93, green: 0.86, blue: 1)
        case "Bàn phím": return Color(red: 1, green: 0.87, blue: 0.94)
        case "Trackpad": return Color(red: 0.83, green: 0.97, blue: 0.92)
        case "Microphone": return Color(red: 0.88, green: 0.98, blue: 0.84)
        case "Cổng kết nối": return Color(red: 1, green: 0.88, blue: 0.84)
        default: return Color(red: 1, green: 0.95, blue: 0.81)
        }
    }

    private func colorfulTestRow(_ name: String) -> some View {
        let result = inspection.results.first(where: { $0.name == name })
        let value = result?.status ?? "Chưa thử"
        return HStack(spacing: 10) {
            Image(systemName: symbolForTest(name))
                .font(.system(size: 16, weight: .bold)).foregroundStyle(ink)
                .frame(width: 31, height: 31)
                .background(.white.opacity(0.57), in: RoundedRectangle(cornerRadius: 8))
            Text(name).font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(.system(size: 12))
                .foregroundStyle(value == "Có lỗi" ? Color.red : mutedInk)
            Image(systemName: value == "Ổn" ? "checkmark.circle.fill"
                : value == "Có lỗi" ? "xmark.circle.fill" : "circle")
                .foregroundStyle(value == "Ổn" ? Color.green : value == "Có lỗi" ? Color.red : Color.gray)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(testColor(name), in: RoundedRectangle(cornerRadius: 11))
    }


    private var passCount: Int { inspection.results.filter { $0.status == "Ổn" }.count }
    private var failCount: Int { inspection.results.filter { $0.status == "Có lỗi" }.count }
    private var remainingCount: Int { inspection.checks.count - passCount - failCount }
    private var ramDescription: String {
        guard let raw = inspection.hardware["RAM (bytes)"], let bytes = Double(raw) else { return "Chưa đọc" }
        return "\(Int((bytes / 1_073_741_824).rounded())) GB"
    }
    private var macDisplayName: String {
        let model = inspection.hardware["Model"] ?? "Đang nhận diện Mac"
        let identifier = inspection.hardware["Model Identifier"] ?? ""
        let chip = inspection.hardware["Chip / CPU"] ?? ""
        switch identifier {
        case "Mac14,9": return "MacBook Pro 14\" (2023) · \(chip)"
        case "Mac14,10": return "MacBook Pro 16\" (2023) · \(chip)"
        case "Mac14,5": return "MacBook Pro 14\" (2023) · \(chip)"
        case "Mac14,6": return "MacBook Pro 16\" (2023) · \(chip)"
        default: return model
        }
    }
    private func summaryTile(_ title: String, _ detail: String, icon: String, color: Color = anTamOrange) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 27)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(mutedInk)
                Text(detail).font(.system(size: 14, weight: .bold)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.padding(12)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tổng quan thiết bị").font(.system(size: 29, weight: .bold))
                    Text("Thông tin Mac, trạng thái bảo mật và tiến độ các bài kiểm tra.")
                        .font(.subheadline).foregroundStyle(mutedInk)
                }
                Spacer()
                Button("Kiểm tra lại") {
                    inspection.readHardware()
                    health.refresh()
                    inspection.checkMDM()
                }
                Button("Xuất báo cáo") { inspection.exportJSON(health: health.snapshot) }
            }
            card {
                Label("Thông tin Mac", systemImage: "laptopcomputer")
                    .font(.title3.bold()).foregroundStyle(ink)
                HStack(alignment: .center, spacing: 20) {
                    assetImage("MacBookPreview", width: 250, height: 170)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(macDisplayName).font(.system(size: 21, weight: .bold))
                        Text("Model: \(inspection.hardware["Model Identifier"] ?? "Chưa đọc")").font(.caption).foregroundStyle(mutedInk)
                        Text("CPU: \(inspection.hardware["Chip / CPU"] ?? "Chưa đọc")").font(.subheadline)
                        Text("Số nhân CPU: \(inspection.hardware["CPU logic"] ?? "Chưa đọc")").font(.subheadline)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            summaryTile("RAM", ramDescription, icon: "memorychip")
                            summaryTile("SSD", health.snapshot.storage.first?.capacity ?? "Chưa đọc", icon: "internaldrive")
                        }
                        HStack(spacing: 10) {
                            let battery = health.snapshot.battery
                            summaryTile("Pin", battery.healthPercent.map { String(format: "%.0f%% sức khỏe", $0) } ?? "Chưa xác định", icon: "battery.100percent", color: .green)
                            summaryTile("Mức pin", battery.chargePercent.map { "\($0)%" } ?? "Chưa đọc", icon: "bolt")
                        }
                        summaryTile("macOS", inspection.hardware["macOS"] ?? "Chưa đọc", icon: "apple.logo")
                    }.frame(maxWidth: 480)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                card {
                    HStack {
                        Label("MDM (Quản lý thiết bị)", systemImage: "gearshape.2")
                            .font(.headline)
                        Spacer()
                        Button(inspection.checkingMDM ? "Đang kiểm tra" : "Kiểm tra lại") {
                            inspection.checkMDM()
                        }.disabled(inspection.checkingMDM)
                    }
                    Text(inspection.mdm.status)
                        .font(.subheadline.bold())
                        .foregroundStyle(inspection.mdm.status == "Phát hiện quản lý" ? Color.red : Color.green)
                    Text("MDM enrollment: \(inspection.mdm.enrollment)").font(.caption)
                    Text("Automated enrollment: \(inspection.mdm.automatedEnrollment)").font(.caption)
                    Text("Chỉ phản ánh trạng thái hiện tại của macOS, không xác nhận đăng ký tổ chức sau khi kích hoạt lại.")
                        .font(.caption).foregroundStyle(mutedInk)
                }
                card {
                    Label("Activation Lock", systemImage: "lock.shield")
                        .font(.headline)
                    Text(health.snapshot.activationLock)
                        .font(.subheadline.bold())
                        .foregroundStyle(health.snapshot.activationLock == "Đã bật" ? Color.red : Color.green)
                    Text("Đọc từ trạng thái mà macOS cung cấp.")
                        .font(.caption).foregroundStyle(mutedInk)
                }
            }
            card {
                HStack {
                    Label("Kết quả kiểm tra nhanh", systemImage: "checkmark.circle")
                        .font(.title3.bold())
                    Spacer()
                    Text("\(passCount)/\(inspection.checks.count)")
                        .font(.system(size: 25, weight: .bold)).foregroundStyle(anTamOrange)
                }
                ProgressView(value: Double(passCount), total: Double(inspection.checks.count))
                    .tint(.green)
                HStack(spacing: 20) {
                    Label("\(passCount) Đạt", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Label("\(failCount) Có lỗi", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                    Label("\(remainingCount) Chưa thử", systemImage: "minus.circle.fill").foregroundStyle(mutedInk)
                    Spacer()
                    Button("Tiếp tục kiểm tra chi tiết →") {
                        if !inspection.running && inspection.step < inspection.checks.count { inspection.resume() }
                        page = .inspection
                    }.buttonStyle(.borderedProminent)
                }.font(.subheadline)
            }
        }
    }

    private func symbolForTest(_ name: String) -> String {
        switch name {
        case "Màn hình": return "display"
        case "Bàn phím": return "keyboard"
        case "Trackpad": return "hand.point.up.left"
        case "Loa": return "speaker.wave.2"
        case "Microphone": return "mic"
        case "Webcam": return "camera"
        case "Cổng kết nối": return "cable.connector"
        case "Pin": return "battery.100percent"
        case "SSD": return "internaldrive"
        default: return "laptopcomputer"
        }
    }
    private var mdmDetail: some View {
        VStack(spacing: 16) {
            mdmCard
            card {
                Label("Kiểm tra thêm cho yên tâm nhé! ✨", systemImage: "checklist")
                    .font(.headline)
                Text("1. Kiểm tra hồ sơ quản lý")
                    .font(.subheadline.bold())
                Text("Mở Cài đặt hệ thống → Cài đặt chung → Quản lý thiết bị. Nếu có hồ sơ quản lý không rõ nguồn gốc, hãy hỏi người bán.")
                    .font(.caption).foregroundStyle(mutedInk)
                Divider()
                Text("2. Kiểm tra sau khi xóa và kích hoạt lại máy")
                    .font(.subheadline.bold())
                Text("Chỉ là lựa chọn thêm để chắc chắn hơn, không bắt buộc — chỉ thực hiện khi chủ máy đồng ý và đã sao lưu dữ liệu. Kết nối Internet khi thiết lập lại, xem có màn hình Remote Management xuất hiện không.")
                    .font(.caption).foregroundStyle(mutedInk)
                if inspection.mdm.enrollment == "Không" && inspection.mdm.automatedEnrollment == "Không" {
                    Text("Cả hai mục đều là Không — không phát hiện quản lý MDM hiện tại, không phải 100%. Để an tâm hơn, bạn nên làm thêm 2 bước ở trên; xóa toàn bộ máy và kích hoạt lại thì không bắt buộc.")
                        .font(.caption.bold()).foregroundStyle(anTamOrange)
                } else {
                    Text("Không phát hiện MDM không bảo đảm thiết bị chưa từng được tổ chức quản lý.")
                        .font(.caption.bold()).foregroundStyle(anTamOrange)
                }
            }
        }
    }

    private var mdmCard: some View {
        card {
            HStack {
                Label("Kiểm tra MDM trên Mac", systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                Button(inspection.checkingMDM ? "Đang kiểm tra..." : "Kiểm tra MDM") {
                    inspection.checkMDM()
                }.disabled(inspection.checkingMDM)
            }
            HStack {
                Image(systemName: "exclamationmark.shield").foregroundStyle(anTamOrange)
                Text(inspection.mdm.status).font(.title3.bold())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warningBackground, in: RoundedRectangle(cornerRadius: 10))
            Text("MDM enrollment: \(inspection.mdm.enrollment)").font(.caption)
            Text("Automated Enrollment: \(inspection.mdm.automatedEnrollment)").font(.caption)
            Text(inspection.mdm.warning).font(.caption).foregroundStyle(mutedInk)
            if !inspection.mdm.details.isEmpty {
                DisclosureGroup("Xem kết quả hệ thống") {
                    Text(inspection.mdm.details)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }
    private var shopCard: some View {
        card {
            HStack {
                Text("Vi tính An Tâm").font(.title3.bold())
                    .foregroundStyle(ink)
                Spacer()
                Image(systemName: "checkmark.shield.fill").foregroundStyle(anTamOrange)
            }
            Text("Bán bằng tâm để bạn an tâm").font(.caption.weight(.semibold)).foregroundStyle(anTamOrange)
            Text(Shop.warranty).font(.caption.bold()).foregroundStyle(anTamOrange)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(anTamOrange.opacity(0.1), in: Capsule())
            Label(Shop.branch1, systemImage: "mappin")
                .font(.caption)
            Label(Shop.branch2, systemImage: "mappin")
                .font(.caption)
            Label("vitinhantam.com", systemImage: "globe")
                .font(.caption)
            Link(destination: Shop.website) {
                HStack {
                    Spacer()
                    Label("Tham quan shop", systemImage: "arrow.up.right.square")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(anTamOrange, lineWidth: 1))
            }
        }
    }
    private var hardware: some View {
        card {
            HStack {
                Text("Hardware Information").font(.headline)
                Spacer()
                Button("Làm mới") { inspection.readHardware() }.disabled(inspection.running)
            }
            if inspection.hardware.isEmpty {
                Text("Bấm Đọc cấu hình để xem thông số từ macOS nhé.").foregroundStyle(.secondary)
            } else {
                ForEach(inspection.hardware.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key).foregroundStyle(.secondary).frame(width: 170, alignment: .leading)
                        Text(inspection.hardware[key] ?? "Không khả dụng").textSelection(.enabled)
                        Spacer()
                    }.padding(7).background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    private var testWizard: some View {
        card {
            Text("Kiểm tra từng bước").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185))], spacing: 8) {
                ForEach(inspection.checks, id: \.self) { name in
                    HStack {
                        Image(systemName: symbolForTest(name)).foregroundStyle(anTamOrange)
                        Text(name).font(.caption.bold())
                        Spacer()
                        let result = inspection.results.first(where: { $0.name == name })
                        Image(systemName: result?.status == "Ổn" ? "checkmark.circle.fill" : result?.status == "Có lỗi" ? "xmark.circle.fill" : "circle")
                            .foregroundStyle(result?.status == "Ổn" ? Color.green : result?.status == "Có lỗi" ? Color.red : Color.gray)
                    }.padding(10).background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            ProgressView(value: Double(inspection.results.count), total: Double(inspection.checks.count))
            if inspection.running && inspection.step < inspection.checks.count {
                let current = inspection.checks[inspection.step]
                Text("Bước \(inspection.step + 1)/\(inspection.checks.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(current).font(.title.bold()).foregroundStyle(anTamOrange)
                if current == "Pin" {
                    let b = health.snapshot.battery
                    Text("Sức khỏe: " + (b.healthPercent.map { String(format: "%.1f%%", $0) } ?? "Chưa xác định"))
                    Text("Chu kỳ sạc: " + (b.cycleCount.map(String.init) ?? "Chưa đọc"))
                    Text("Mức pin: " + (b.chargePercent.map { "\($0)%" } ?? "Chưa đọc"))
                    Button("Đọc lại thông tin pin") { health.refresh() }
                } else if current == "SSD" {
                    ForEach(health.snapshot.storage) { disk in
                        Text("\(disk.name) · \(disk.capacity) · SMART: \(disk.smart)")
                    }
                    if health.snapshot.storage.isEmpty {
                        Text("Chưa nhận diện được SSD vật lý.")
                    }
                    Button("Đọc lại SSD") { health.refresh() }
                    Text("SMART không khả dụng không đồng nghĩa ổ bị lỗi. Chưa bao gồm benchmark.")
                        .font(.caption).foregroundStyle(mutedInk)
                } else {
                    DiagnosticToolView(name: current, tools: tools)
                }
                Text(tools.canConfirm(current)
                     ? "Hãy tự quan sát kết quả rồi xác nhận."
                     : "Hãy thực hiện bài test trước khi xác nhận Đạt. Có thể chọn Có lỗi hoặc Chưa thử bất cứ lúc nào.")
                    .font(.caption).foregroundStyle(mutedInk)
                HStack {
                    Button("Ổn rồi!") {
                        inspection.record("Ổn")
                        if !inspection.running { page = .report }
                        if current == "Webcam" { tools.stopCamera() }
                        if current == "Microphone" { tools.stopRecording() }
                    }.disabled((current == "Pin" && health.snapshot.battery.healthPercent == nil) || (current == "SSD" && health.snapshot.storage.isEmpty) || (!["Pin", "SSD"].contains(current) && !tools.canConfirm(current)))
                    Button("Có lỗi") { showIssue = true }
                    Button("Chưa thử") {
                        inspection.record("Chưa thử")
                        if !inspection.running { page = .report }
                        tools.stopRecording()
                        tools.stopCamera()
                    }
                    Button("Dừng toàn bộ", role: .destructive) {
                        tools.stopRecording()
                        tools.stopCamera()
                        inspection.stop()
                    }
                }
            } else {
                Text(inspection.results.count == inspection.checks.count ? "Phiên kiểm tra đã hoàn tất. Xem kết luận trong Báo cáo." : "Phiên kiểm tra đang dừng. Mở Báo cáo để xem kết quả đã ghi nhận.")
                    .foregroundStyle(.secondary)
                Button("Xem kết quả & kết luận") { page = .report }
                if inspection.results.isEmpty {
                    Button("Bắt đầu kiểm tra mới") {
                        tools.reset()
                        inspection.start()
                    }
                }
            }
        }
    }
    private var report: some View {
        let tier = inspection.overallTier(for: health.snapshot)
        return VStack(spacing: 16) {
            card {
                Label("Kết luận kiểm tra", systemImage: "checkmark.shield.fill").font(.title3.bold())
                Text(inspection.verdictTitle(for: health.snapshot))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tier == .good ? Color.green
                        : tier == .blocked || tier == .error ? Color.red : anTamOrange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(warningBackground, in: RoundedRectangle(cornerRadius: 12))
                Text(inspection.conclusion(for: health.snapshot)).fixedSize(horizontal: false, vertical: true)
                Text("Kết luận tổng hợp tự động từ 8 bài kiểm tra chức năng, pin, ổ lưu trữ/SMART, MDM và Activation Lock; chưa gồm tải CPU/GPU.")
                    .font(.caption).foregroundStyle(mutedInk)
            }
            card {
                HStack {
                    Text("Tiến độ phiên kiểm tra").font(.headline)
                    Spacer()
                    Text("\(inspection.results.count)/\(inspection.checks.count) hạng mục").font(.caption.bold())
                }
                ProgressView(value: Double(inspection.results.count), total: Double(inspection.checks.count))
                if !inspection.running && inspection.results.count == inspection.checks.count {
                    Text("Đã hoàn tất phiên kiểm tra.").foregroundStyle(.green)
                } else if inspection.running {
                    Button("Tiếp tục kiểm tra") { page = .inspection }
                } else {
                    Text("Còn bài chưa kiểm tra.").foregroundStyle(mutedInk)
                    Button("Tiếp tục kiểm tra") {
                        inspection.resume()
                        page = .inspection
                    }
                }
            }
            card {
                Text("Kết quả chi tiết").font(.headline)
                ForEach(inspection.checks, id: \.self) { name in
                    let result = inspection.results.first(where: { $0.name == name })
                    HStack {
                        Text(name).fontWeight(.medium).frame(maxWidth: .infinity, alignment: .leading)
                        Text(result?.status ?? "Chưa thử")
                            .foregroundStyle(result?.status == "Có lỗi" ? Color.red : Color.secondary)
                    }
                    if let note = result?.note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(mutedInk)
                    }
                    Divider()
                }
                Button("Xuất báo cáo JSON") { inspection.exportJSON(health: health.snapshot) }
            }
            card {
                HStack {
                    Text("Pin & Lưu trữ").font(.headline)
                    Spacer()
                    Button("Đọc lại dữ liệu") { health.refresh() }
                }
                let b = health.snapshot.battery
                Text("Pin: " + (b.healthPercent.map { String(format: "%.1f%% (ước tính)", $0) } ?? "Chưa đủ dữ liệu"))
                Text("Chu kỳ pin: " + (b.cycleCount.map(String.init) ?? "Không khả dụng"))
                Text("Ổ lưu trữ nhận diện: \(health.snapshot.storage.count)")
                Text("Activation Lock: \(health.snapshot.activationLock)")
                Text("SMART không khả dụng không được coi là lỗi ổ.")
                    .font(.caption).foregroundStyle(mutedInk)
            }
            card {
                Label("An Tâm nhắn bạn", systemImage: "heart.fill").font(.title3.bold())
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let note = inspection.reassuranceNote(for: health.snapshot) {
                            Text(note).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Chưa đủ dữ liệu nên chưa có lời nhắn — làm nốt các mục còn thiếu rồi quay lại đây nhé.")
                        }
                    }
                }
            }
        }
    }

}

@main
struct AnTamMacCheckApp: App {
    var body: some Scene {
        WindowGroup("An Tâm Mac check") { MainView() }
            .defaultSize(width: 1480, height: 960)
    }
}
