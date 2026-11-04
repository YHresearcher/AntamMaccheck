import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let anTamOrange = Color(red: 0.94, green: 0.43, blue: 0.06)
private let backgroundColor = Color(red: 0.97, green: 0.98, blue: 0.99)

enum Shop {
    static let name = "Vi tính An Tâm"
    static let website = URL(string: "https://vitinhantam.com")!
    // Chưa xác minh địa chỉ từ hình đính kèm. Không tự suy đoán địa chỉ.
    static let address = ""
}

struct Result: Identifiable, Codable {
    var name: String
    var status: String
    var note: String
    var id: String { name }
}

@MainActor final class Inspection: ObservableObject {
    @Published var hardware: [String: String] = [:]
    @Published var results: [Result] = []
    @Published var running = false
    @Published var step = 0
    @Published var errorNote = ""
    @Published var info = "Chào bạn! Khi sẵn sàng, hãy bấm Bắt đầu kiểm tra nhé."
    let checks = ["Màn hình", "Bàn phím", "Trackpad", "Loa", "Microphone", "Webcam", "Cổng kết nối", "Ngoại quan"]

    var conclusion: String {
        if results.contains(where: { $0.status == "Có lỗi" }) {
            return "Máy có một vài điểm cần để mắt tới! Xem lỗi đã ghi nhận trước khi xuống tiền nhé."
        }
        if results.count < checks.count || results.contains(where: { $0.status == "Chưa thử" }) {
            return "Chiếc Mac vẫn còn vài bí mật! Mình chưa đủ dữ liệu để đưa ra kết luận đâu nhé."
        }
        return "Các mục bạn đã xác nhận đều ổn! Tuy vậy, chưa có kiểm tra SMART, khóa máy và stress test chuyên sâu."
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
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "hardware": hardware,
            "tests": results.map { ["name": $0.name, "status": $0.status, "note": $0.note] },
            "conclusion": conclusion,
            "limitations": "Các bài kiểm tra chức năng được xác nhận thủ công; chưa đánh giá SMART, MDM hay Activation Lock."
        ]
        do {
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: url, options: .atomic)
            info = "Đã lưu báo cáo. Cảm ơn bạn đã dùng An Tâm Mac check!"
        } catch { info = "Chưa lưu được báo cáo: \(error.localizedDescription)" }
    }
}

enum Page: String, CaseIterable, Identifiable {
    case overview = "Tổng quan", hardware = "Phần cứng", inspection = "Kiểm tra", report = "Báo cáo"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .hardware: return "cpu"
        case .inspection: return "checkmark.shield"
        case .report: return "doc.text"
        }
    }
}

struct MainView: View {
    @StateObject private var inspection = Inspection()
    @State private var page: Page = .overview
    @State private var showIssue = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    if let path = Bundle.main.path(forResource: "AnTamLogo", ofType: "png"),
                       let logo = NSImage(contentsOfFile: path) {
                        Image(nsImage: logo).resizable().scaledToFit().frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "checkmark.shield.fill").font(.largeTitle).foregroundStyle(anTamOrange)
                    }
                    VStack(alignment: .leading) {
                        Text("An Tâm").font(.headline)
                        Text("Mac check").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 16).padding(.top, 18)
                List(Page.allCases, selection: $page) { value in
                    Label(value.rawValue, systemImage: value.symbol).tag(value).padding(.vertical, 6)
                }.listStyle(.sidebar)
                Spacer()
                Link(Shop.name, destination: Shop.website).font(.caption)
                    .padding(.horizontal, 16)
                if !Shop.address.isEmpty {
                    Text(Shop.address).font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            }.padding(.bottom, 16)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(page.rawValue).font(.largeTitle.bold())
                            Text("Kiểm tra Mac trước khi mua • Nhẹ nhàng mà kỹ càng!").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(inspection.running ? "Đang kiểm tra" : "Chưa chạy test")
                            .font(.caption).padding(9).background(.white, in: Capsule())
                    }
                    switch page {
                    case .overview: overview
                    case .hardware: hardware
                    case .inspection: testWizard
                    case .report: report
                    }
                    Spacer(minLength: 10)
                    Divider()
                    HStack {
                        Link(Shop.name, destination: Shop.website)
                        if !Shop.address.isEmpty {
                            Text("• \(Shop.address)").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("An Tâm Mac check").foregroundStyle(.secondary)
                    }.font(.caption)
                }.padding(26).frame(maxWidth: 1100, alignment: .leading)
            }.background(backgroundColor)
        }
        .tint(anTamOrange)
        .frame(minWidth: 850, minHeight: 600)
        .alert("Ghi nhận lỗi", isPresented: $showIssue) {
            TextField("Bạn gặp lỗi gì?", text: $inspection.errorNote)
            Button("Lưu lỗi & tiếp tục") { inspection.record("Có lỗi") }
                .disabled(inspection.errorNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Quay lại", role: .cancel) {}
        } message: { Text("Cứ mô tả thật dễ hiểu nhé, An Tâm sẽ lưu lại vào báo cáo.") }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
    private var overview: some View {
        VStack(spacing: 16) {
            card {
                Text("Máy đang kiểm tra").font(.headline)
                Text(inspection.hardware.isEmpty ? "Chưa đọc cấu hình máy." : "Đã đọc \(inspection.hardware.count) thông số cơ bản.")
                    .foregroundStyle(.secondary)
                Button("Đọc cấu hình") { inspection.readHardware() }.disabled(inspection.running)
            }
            card {
                Text("Điều khiển kiểm tra").font(.headline)
                HStack(spacing: 36) {
                    VStack {
                        Button {
                            inspection.start()
                            page = .inspection
                        } label: {
                            Image(systemName: "play.fill").font(.title).foregroundStyle(.white)
                                .frame(width: 76, height: 76)
                                .background(anTamOrange, in: Circle())
                        }.buttonStyle(.plain).disabled(inspection.running)
                        Text("AUTO INSPECTION").font(.caption.bold())
                    }
                    VStack {
                        Button {
                            inspection.stop()
                        } label: {
                            Image(systemName: "stop.fill").font(.title).foregroundStyle(.white)
                                .frame(width: 76, height: 76)
                                .background(inspection.running ? Color.red : Color.gray.opacity(0.4), in: Circle())
                        }.buttonStyle(.plain).disabled(!inspection.running)
                        Text("DỪNG TOÀN BỘ").font(.caption.bold())
                    }
                    Spacer()
                }
                ProgressView(value: Double(inspection.results.count), total: Double(inspection.checks.count))
                Text(inspection.info).font(.callout).foregroundStyle(.secondary)
            }
            card {
                Text("An Tâm nhắn bạn").font(.headline)
                Text(inspection.conclusion)
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
                Text("Không đánh giá lỗi SSD, pin, iCloud/MDM nếu chưa có dữ liệu xác thực.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
                            Text(result.status).foregroundStyle(result.status == "Có lỗi" ? .red : .secondary)
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
