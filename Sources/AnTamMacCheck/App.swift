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
    let checks = ["Màn hình", "Bàn phím", "Trackpad", "Loa", "Microphone", "Webcam", "Cổng kết nối", "Ngoại quan"]

    var verdictTitle: String {
        if mdm.status == "Phát hiện quản lý" { return "KHÔNG KHUYẾN NGHỊ MUA" }
        if results.contains(where: { $0.status == "Có lỗi" }) { return "PHÁT HIỆN LỖI — CẦN ĐÁNH GIÁ" }
        if results.count < checks.count || results.contains(where: { $0.status == "Chưa thử" }) {
            return "CHƯA ĐỦ DỮ LIỆU — CHƯA KẾT LUẬN ĐƯỢC"
        }
        return "ĐÃ HOÀN TẤT KIỂM TRA CHỨC NĂNG — CẦN XÁC MINH THÊM"
    }
    var conclusion: String {
        if mdm.status == "Phát hiện quản lý" {
            return "Đã phát hiện dấu hiệu quản lý MDM/ADE. Không khuyến nghị giao dịch cho tới khi chủ sở hữu giải trình và gỡ quản lý hợp lệ."
        }
        let errors = results.filter { $0.status == "Có lỗi" }
        if !errors.isEmpty {
            let detail = errors.map { "\($0.name): \($0.note)" }.joined(separator: "; ")
            return "Có \(errors.count) hạng mục lỗi: \(detail). Cần kiểm tra hoặc sửa chữa trước khi cân nhắc mua."
        }
        let unknown = checks.filter { name in
            guard let result = results.first(where: { $0.name == name }) else { return true }
            return result.status == "Chưa thử"
        }
        if !unknown.isEmpty {
            return "Chưa đủ dữ liệu để kết luận. Còn \(unknown.count) hạng mục chưa xác nhận: \(unknown.joined(separator: ", "))."
        }
        return "8/8 bài kiểm tra chức năng được kỹ thuật viên xác nhận ổn. Chưa thể kết luận máy an toàn toàn diện: cần kiểm tra pin, SSD/SMART, tải CPU/GPU, Activation Lock và MDM bằng quy trình xác minh hợp lệ."
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
            let result = MDMCheck(
                status: status,
                enrollment: enrollment,
                automatedEnrollment: automated,
                checkedAt: ISO8601DateFormatter().string(from: Date()),
                details: raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
    func exportJSON() {
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
            "tests": results.map { ["name": $0.name, "status": $0.status, "note": $0.note] },
            "conclusion": conclusion,
            "limitations": "Các bài kiểm tra chức năng được xác nhận thủ công; MDM chỉ được kiểm tra từ trạng thái profiles hiện tại, không thay cho xác minh ADE/Activation Lock với người bán; chưa đánh giá SMART hoặc stress test."
        ]
        do {
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: url, options: .atomic)
            info = "Đã lưu báo cáo. Cảm ơn bạn đã dùng An Tâm Mac check!"
        } catch { info = "Chưa lưu được báo cáo: \(error.localizedDescription)" }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case overview = "Tổng quan", hardware = "Thông tin Mac", inspection = "Kiểm tra chi tiết", health = "Sức khỏe phần cứng", mdm = "MDM & Quản lý", report = "Báo cáo"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .hardware: return "cpu"
        case .inspection: return "checkmark.shield"
        case .health: return "battery.100percent"
        case .mdm: return "lock.shield"
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
                    assetImage("MascotChecklist", width: 90, height: 88)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("An Tâm").font(.system(size: 20, weight: .bold))
                        Text("Mac check").font(.system(size: 19, weight: .bold))
                    }
                }
                .padding(.horizontal, 12).padding(.top, 16)
                VStack(spacing: 7) {
                    navButton(.overview, "house.fill")
                    navButton(.inspection, "laptopcomputer")
                    navButton(.hardware, "cpu")
                    navButton(.health, "battery.100percent")
                    navButton(.mdm, "lock.shield")
                    navButton(.report, "chart.bar")
                    Divider().padding(.vertical, 10)
                    Button { showAbout = true } label: {
                        Label("Giới thiệu", systemImage: "info.circle")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 12).padding(.top, 15)
                Spacer()
                Text("Bán bằng tâm để bạn an tâm")
                    .font(.caption).foregroundStyle(mutedInk).padding(.horizontal, 18)
            }
            .frame(minWidth: 235, maxWidth: 245, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, 15)
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
                    case .hardware: hardware
                    case .health: HardwareHealthView(model: health)
                    case .inspection: testWizard
                    case .mdm: mdmDetail
                    case .report: report
                    }
                    Spacer(minLength: 10)
                }.padding(26).frame(maxWidth: 1160, alignment: .leading)
            }.background(backgroundColor)
        }
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
            .foregroundStyle(page == destination ? Color.white : ink)
            .padding(.horizontal, 13).padding(.vertical, 12)
            .background(page == destination ? anTamOrange : Color.white.opacity(0.56),
                        in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
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

    private var overview: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Xin chào! 👋").font(.system(size: 29, weight: .bold))
                    Text("Bán bằng tâm để bạn an tâm")
                        .font(.subheadline).foregroundStyle(mutedInk)
                }
                Spacer()
                Button("↻  Kiểm tra lại") {
                    tools.reset()
                    inspection.start()
                    page = .inspection
                }.disabled(inspection.running)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 15) {
                    overviewLeft.frame(minWidth: 350, maxWidth: .infinity)
                    overviewRight.frame(minWidth: 350, maxWidth: .infinity)
                }
                VStack(spacing: 15) {
                    overviewLeft
                    overviewRight
                }
            }
        }
    }

    private var overviewLeft: some View {
        VStack(spacing: 15) {
            card {
                HStack(alignment: .center, spacing: 14) {
                    assetImage("MacBookPreview", width: 170, height: 146)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(inspection.hardware["Model"] ?? "Mac đang kiểm tra")
                            .font(.system(size: 19, weight: .bold)).lineLimit(2)
                        Text("Thông số hệ thống").font(.caption).foregroundStyle(mutedInk)
                        Text("CPU: \(inspection.hardware["Chip / CPU"] ?? "Chưa đọc")").lineLimit(2)
                        Text("RAM: \(ramDescription)").lineLimit(1)
                        Text("macOS: \(inspection.hardware["macOS"] ?? "Chưa đọc")").lineLimit(1)
                        Button("Xem cấu hình chi tiết →") { page = .hardware }
                    }.font(.system(size: 12))
                }
            }
            card {
                HStack {
                    Label("Kết quả kiểm tra nhanh", systemImage: "questionmark.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                    Text("\(inspection.results.filter { $0.status != "Chưa thử" }.count)/\(inspection.checks.count) mục đã thử")
                        .font(.caption.bold()).foregroundStyle(anTamOrange)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(warningBackground, in: Capsule())
                }
                ForEach(["Màn hình", "Loa", "Webcam", "Bàn phím", "Trackpad", "Microphone", "Cổng kết nối", "Ngoại quan"], id: \.self) { name in
                    colorfulTestRow(name)
                }
            }
            card {
                HStack {
                    Label("Sức khỏe phần cứng", systemImage: "battery.100percent")
                        .font(.headline)
                    Spacer()
                    Button("Xem chi tiết →") { page = .health }
                }
                let b = health.snapshot.battery
                HStack {
                    Text("Pin").fontWeight(.medium)
                    Spacer()
                    Text(b.healthPercent.map { String(format: "%.1f%% (ước tính)", $0) }
                         ?? (b.present ? "Chưa đủ dữ liệu" : "Không khả dụng"))
                        .foregroundStyle(mutedInk)
                }.font(.caption)
                HStack {
                    Text("Ổ lưu trữ").fontWeight(.medium)
                    Spacer()
                    Text(health.snapshot.storage.isEmpty
                         ? "Chưa đọc được thông tin"
                         : "\(health.snapshot.storage.count) mục nhận diện")
                        .foregroundStyle(mutedInk)
                }.font(.caption)
                Text("Không có dữ liệu không có nghĩa thiết bị hỏng.")
                    .font(.caption2).foregroundStyle(mutedInk)
            }
            HStack(spacing: 12) {
                Button {
                    if !inspection.running { tools.reset(); inspection.start() }
                    page = .inspection
                } label: {
                    Label("Kiểm tra chi tiết", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(13)
                        .foregroundStyle(.white)
                        .background(anTamOrange, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                Button { inspection.exportJSON() } label: {
                    Label("Xuất báo cáo", systemImage: "doc.text")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
    }

    private var ramDescription: String {
        guard let raw = inspection.hardware["RAM (bytes)"], let bytes = Double(raw) else { return "Chưa đọc" }
        return String(format: "%.1f GB", bytes / 1_073_741_824)
    }

    private var overviewRight: some View {
        VStack(spacing: 15) {
            card {
                Label("MDM & Quản lý thiết bị", systemImage: "lock.shield.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(inspection.mdm.status == "Chưa phát hiện quản lý hiện tại"
                     ? "Chưa phát hiện MDM — cần xác minh thêm"
                     : inspection.mdm.status)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(anTamOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(warningBackground, in: RoundedRectangle(cornerRadius: 12))
                Text("✦  Bạn nên kiểm tra thêm để yên tâm:")
                    .font(.system(size: 13, weight: .bold))
                Text("1  Kiểm tra hồ sơ quản lý thiết bị")
                    .font(.system(size: 12, weight: .semibold))
                Text("Vào Cài đặt hệ thống → Cài đặt chung → Quản lý thiết bị.")
                    .font(.caption).foregroundStyle(mutedInk)
                Text("2  Kiểm tra sau khi xóa máy và kích hoạt lại")
                    .font(.system(size: 12, weight: .semibold))
                Text("Chỉ khi chủ máy đồng ý và đã sao lưu. Kết nối Internet, kiểm tra Remote Management.")
                    .font(.caption).foregroundStyle(mutedInk)
                HStack {
                    Button("Kiểm tra MDM") { inspection.checkMDM() }.disabled(inspection.checkingMDM)
                    Button("Xem chi tiết →") { page = .mdm }
                }
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
                Text("Chỉ thực hiện khi chủ máy đồng ý và đã sao lưu dữ liệu. Kết nối Internet khi thiết lập lại, xem có màn hình Remote Management xuất hiện không.")
                    .font(.caption).foregroundStyle(mutedInk)
                Text("Không phát hiện MDM không bảo đảm thiết bị chưa từng được tổ chức quản lý.")
                    .font(.caption.bold()).foregroundStyle(anTamOrange)
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
            ProgressView(value: Double(inspection.results.count), total: Double(inspection.checks.count))
            if inspection.running && inspection.step < inspection.checks.count {
                let current = inspection.checks[inspection.step]
                Text("Bước \(inspection.step + 1)/\(inspection.checks.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(current).font(.title.bold()).foregroundStyle(anTamOrange)
                DiagnosticToolView(name: current, tools: tools)
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
                    }.disabled(!tools.canConfirm(current))
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
        VStack(spacing: 16) {
            card {
                Label("Kết luận kiểm tra", systemImage: "checkmark.shield.fill").font(.title3.bold())
                Text(inspection.verdictTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(inspection.results.contains(where: { $0.status == "Có lỗi" })
                        || inspection.mdm.status == "Phát hiện quản lý" ? Color.red : anTamOrange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(warningBackground, in: RoundedRectangle(cornerRadius: 12))
                HStack(alignment: .top, spacing: 14) {
                    assetImage("MascotThinking", width: 115, height: 115)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("An Tâm nhắn bạn").font(.headline)
                        Text(inspection.conclusion).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Kết luận chỉ dựa trên kiểm tra chức năng do người dùng xác nhận và thông tin MDM hiện tại; không thay thế nghiệm thu phần cứng chuyên sâu.")
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
                Button("Xuất báo cáo JSON") { inspection.exportJSON() }
            }
            mdmCard
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
