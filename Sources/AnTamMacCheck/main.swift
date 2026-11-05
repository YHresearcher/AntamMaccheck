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
    @Published var info = "Chào bạn! Khi sẵn sàng, hãy bấm Bắt đầu kiểm tra nhé."
    let checks = ["Màn hình", "Bàn phím", "Trackpad", "Loa", "Microphone", "Webcam", "Cổng kết nối", "Ngoại quan"]

    var conclusion: String {
        if mdm.status == "Phát hiện quản lý" {
            return "Máy đang có dấu hiệu quản lý từ xa. An Tâm khuyên bạn chưa mua cho đến khi người bán chứng minh quyền sở hữu và gỡ quản lý hợp lệ nhé!"
        }
        if results.contains(where: { $0.status == "Có lỗi" }) {
            return "Máy có một vài điểm cần để mắt tới! Xem lỗi đã ghi nhận trước khi xuống tiền nhé."
        }
        if results.count < checks.count || results.contains(where: { $0.status == "Chưa thử" }) {
            return "Chiếc Mac vẫn còn vài bí mật! Mình chưa đủ dữ liệu để đưa ra kết luận đâu nhé."
        }
        return "Các mục bạn đã xác nhận đều ổn! Tuy nhiên, còn cần xác minh MDM/Activation Lock và kiểm tra SMART, stress test trước khi quyết định mua nhé."
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
            info = "Xong rồi! Bạn xem kết luận ở trang Báo cáo nhé."
        }
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
    case overview = "Tổng quan", hardware = "Thông tin Mac", inspection = "Kiểm tra chi tiết", mdm = "MDM & Quản lý", report = "Báo cáo"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .hardware: return "cpu"
        case .inspection: return "checkmark.shield"
        case .mdm: return "lock.shield"
        case .report: return "doc.text"
        }
    }
}

struct MainView: View {
    @StateObject private var inspection = Inspection()
    @State private var page: Page = .overview
    @State private var showIssue = false
    @State private var showHelp = false

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
                    navButton(.mdm, "lock.shield")
                    navButton(.report, "chart.bar")
                    Divider().padding(.vertical, 10)
                    Button { showHelp = true } label: {
                        Label("Hướng dẫn", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }.buttonStyle(.plain)
                    Button { page = .report } label: {
                        Label("Giới thiệu", systemImage: "info.circle")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 12).padding(.top, 15)
                Spacer()
                Text("An Tâm Mac check • macOS")
                    .font(.caption).foregroundStyle(mutedInk).padding(.horizontal, 18)
            }
            .frame(minWidth: 235, maxWidth: 245, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, 15)
            .background(Color(red: 1.0, green: 0.97, blue: 0.935))
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(page == .overview ? "Xin chào! 👋" : page.rawValue)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(ink)
                            Text("Cùng An Tâm kiểm tra tổng thể chiếc Mac của bạn nhé!")
                                .font(.subheadline).foregroundStyle(mutedInk)
                        }
                        Spacer()
                        Label(inspection.running ? "Đang kiểm tra" : "Sẵn sàng", systemImage: inspection.running ? "circle.dotted" : "checkmark.circle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                    switch page {
                    case .overview: overview
                    case .hardware: hardware
                    case .inspection: testWizard
                    case .mdm: mdmDetail
                    case .report: report
                    }
                    Spacer(minLength: 10)
                    Divider()
                    HStack {
                        Link(Shop.name, destination: Shop.website)
                        Text("• \(Shop.warranty)").foregroundStyle(.secondary)
                        Spacer()
                        Text("An Tâm Mac check").foregroundStyle(.secondary)
                    }.font(.caption)
                }.padding(26).frame(maxWidth: 1160, alignment: .leading)
            }.background(backgroundColor)
        }
        .tint(anTamOrange)
        .frame(minWidth: 940, minHeight: 680)
        .alert("Hướng dẫn", isPresented: $showHelp) {
            Button("Đã hiểu") { }
        } message: {
            Text("Chọn Kiểm tra chi tiết để làm các bước kiểm tra thủ công. Xem MDM & Quản lý để kiểm tra trạng thái enrollment; chưa phát hiện không có nghĩa bảo đảm sạch MDM. Xuất JSON ở trang Báo cáo.")
        }
        .alert("Ghi nhận lỗi", isPresented: $showIssue) {
            TextField("Bạn gặp lỗi gì?", text: $inspection.errorNote)
            Button("Lưu lỗi & tiếp tục") { inspection.record("Có lỗi") }
                .disabled(inspection.errorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Quay lại", role: .cancel) {}
        } message: { Text("Cứ mô tả thật dễ hiểu nhé, An Tâm sẽ lưu lại vào báo cáo.") }
    }

    private func assetImage(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let path = Bundle.main.path(forResource: name, ofType: "png"),
               let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: name == "LaptopPreview" ? "laptopcomputer" : "checkmark.shield.fill")
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

    private var overview: some View {
        let completed = inspection.results.count
        let total = inspection.checks.count
        return VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                card {
                    HStack {
                        Label("Thiết bị đang kiểm tra", systemImage: "laptopcomputer")
                            .font(.headline)
                        Spacer()
                        Button("Đọc cấu hình") { inspection.readHardware() }
                            .disabled(inspection.running)
                    }
                    Text(inspection.hardware["Model"] ?? "MacBook / iMac của bạn")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                    Text("Thông số được lấy từ macOS — không phải kết quả chẩn đoán sức khỏe.")
                        .font(.caption).foregroundStyle(mutedInk)
                    ForEach(["Chip / CPU", "RAM (bytes)", "macOS"], id: \.self) { key in
                        HStack {
                            Text(key).foregroundStyle(mutedInk)
                            Spacer()
                            Text(inspection.hardware[key] ?? "Chưa đọc")
                                .fontWeight(.medium).lineLimit(1)
                        }.font(.system(size: 12))
                        Divider()
                    }
                    Button("Xem toàn bộ cấu hình") { page = .hardware }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                card {
                    Label("MDM & Quản lý thiết bị", systemImage: "lock.shield")
                        .font(.headline)
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title2).foregroundStyle(anTamOrange)
                        Text(inspection.mdm.status)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(warningBackground, in: RoundedRectangle(cornerRadius: 10))
                    Text("Chưa phát hiện quản lý hiện tại không có nghĩa máy chắc chắn sạch MDM nha!")
                        .font(.caption).foregroundStyle(mutedInk)
                    Button("Kiểm tra MDM & xem hướng dẫn") { page = .mdm }
                        .disabled(inspection.checkingMDM)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            HStack(alignment: .top, spacing: 16) {
                card {
                    HStack {
                        Label("Kết quả kiểm tra nhanh", systemImage: "checkmark.seal")
                            .font(.headline)
                        Spacer()
                        Text("\(completed)/\(total) mục")
                            .font(.caption.bold())
                            .foregroundStyle(anTamOrange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(anTamOrange.opacity(0.1), in: Capsule())
                    }
                    ForEach(inspection.checks, id: \.self) { name in
                        let result = inspection.results.first(where: { $0.name == name })
                        statusLine(name, result?.status ?? "Chưa thử",
                                   symbol: symbolForTest(name),
                                   done: result?.status == "Ổn")
                        if name != inspection.checks.last { Divider() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(spacing: 16) {
                    card {
                        Label("An Tâm nhắn bạn 🧡", systemImage: "heart.text.square")
                            .font(.headline)
                        Text(inspection.conclusion)
                            .font(.subheadline).foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Trạng thái chưa thử sẽ không được tính là đạt.")
                            .font(.caption).foregroundStyle(mutedInk)
                    }
                    shopCard
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            card {
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Button {
                            inspection.start()
                            page = .inspection
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title2).foregroundStyle(.white)
                                .frame(width: 76, height: 76)
                                .background(anTamOrange, in: Circle())
                        }.buttonStyle(.plain).disabled(inspection.running)
                        Text("AUTO INSPECTION").font(.caption.bold())
                    }
                    VStack(spacing: 8) {
                        Button { inspection.stop() } label: {
                            Image(systemName: "stop.fill")
                                .font(.title2).foregroundStyle(.white)
                                .frame(width: 76, height: 76)
                                .background(inspection.running ? Color.red : Color.gray.opacity(0.35), in: Circle())
                        }.buttonStyle(.plain).disabled(!inspection.running)
                        Text("DỪNG TOÀN BỘ").font(.caption.bold())
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tiến độ kiểm tra").font(.headline)
                        ProgressView(value: Double(completed), total: Double(total))
                            .tint(anTamOrange)
                        Text(inspection.info).font(.caption).foregroundStyle(mutedInk)
                        HStack {
                            Button("Kiểm tra chi tiết") { page = .inspection }
                            Button("Xuất báo cáo") { inspection.exportJSON() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Bước \(inspection.step + 1)/\(inspection.checks.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(inspection.checks[inspection.step]).font(.title.bold()).foregroundStyle(anTamOrange)
                Text("Hãy kiểm tra chức năng thực tế rồi cho An Tâm biết kết quả nha.")
                HStack {
                    Button("Ổn rồi!") { inspection.record("Ổn") }
                    Button("Có lỗi") { showIssue = true }
                    Button("Chưa thử") { inspection.record("Chưa thử") }
                    Button("Dừng toàn bộ", role: .destructive) { inspection.stop() }
                }
            } else {
                Text("Hiện không có bài test đang chạy. Bạn có thể bắt đầu từ trang Tổng quan.")
                    .foregroundStyle(.secondary)
            }
        }
    }
    private var report: some View {
        VStack(spacing: 16) {
            card {
                Text("Đánh giá mua máy").font(.headline)
                Text(inspection.conclusion)
                Text("Chưa đánh giá SSD, pin, Activation Lock; MDM chỉ phản ánh kết quả lệnh macOS tại thời điểm kiểm tra.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            mdmCard
            shopCard
            card {
                Text("Kết quả đã ghi nhận").font(.headline)
                if inspection.results.isEmpty {
                    Text("Chưa có kết quả nào.").foregroundStyle(.secondary)
                }
                ForEach(inspection.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.name).fontWeight(.medium)
                            Spacer()
                            Text(result.status).foregroundStyle(result.status == "Có lỗi" ? Color.red : Color.secondary)
                        }
                        if !result.note.isEmpty { Text(result.note).font(.caption).foregroundStyle(.secondary) }
                    }
                    Divider()
                }
                Button("Xuất báo cáo JSON") { inspection.exportJSON() }
            }
        }
    }
}

@main
struct AnTamMacCheckApp: App {
    var body: some Scene {
        WindowGroup("An Tâm Mac check") { MainView() }
    }
}
