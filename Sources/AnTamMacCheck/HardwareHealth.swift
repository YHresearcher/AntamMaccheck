import Foundation
import SwiftUI

/// Battery collection adapted from the AppleSmartBattery property-selection
/// approach documented in MacMonitor (MIT), without its UI or private SMC bridge.
/// Source: https://github.com/ryyansafar/MacMonitor
/// Copyright (c) 2025-2026 MacMonitor contributors — see THIRD_PARTY_NOTICES.md.
/// All values may be unavailable, particularly on desktops / newer macOS.
struct BatterySnapshot {
    var present = false
    var cycleCount: Int?
    var designMAh: Int?
    var maxMAh: Int?
    var chargePercent: Int?
    var condition: String?
    var healthPercent: Double? {
        guard let maxMAh, let designMAh, maxMAh > 0, designMAh > 0 else { return nil }
        let ratio = Double(maxMAh) / Double(designMAh) * 100
        return (ratio > 0 && ratio < 150) ? ratio : nil
    }
}
struct StorageSnapshot: Identifiable {
    let id: String
    let name: String
    let capacity: String
    let smart: String
    let source: String
}
struct HardwareHealthSnapshot {
    var battery = BatterySnapshot()
    var storage: [StorageSnapshot] = []
    var diskInfo = ""
    var status = "Chưa đọc dữ liệu"
    var readAt: Date?
    /// "Đã bật" / "Đã tắt" / "Chưa xác định". Chỉ đọc được trên máy
    /// Apple Silicon / chip T2; máy Intel không T2 không có trường này.
    var activationLock = "Chưa xác định"
}

enum NativeHealthProbe {
    private static func run(_ binary: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }
    private static func int(_ key: String, in text: String) -> Int? {
        let regexText = NSRegularExpression.escapedPattern(for: key) + #""\s*=\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: regexText),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }
    private static func battery() -> BatterySnapshot {
        guard let output = run("/usr/sbin/ioreg", ["-l", "-r", "-n", "AppleSmartBattery"]),
              output.contains("AppleSmartBattery") else { return BatterySnapshot() }
        var battery = BatterySnapshot()
        battery.present = true
        battery.cycleCount = int("CycleCount", in: output)
        battery.designMAh = int("DesignCapacity", in: output)
        battery.maxMAh = int("AppleRawMaxCapacity", in: output)
            ?? int("NominalChargeCapacity", in: output)
        battery.chargePercent = int("CurrentCapacity", in: output)
        return battery
    }
    private static func field(_ data: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, !value.isEmpty { return value }
            if let value = data[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }
    private static func storage() -> ([StorageSnapshot], String) {
        // system_profiler provides a read-only inventory. SMART may be absent
        // on Apple Silicon, USB, bridged or external disks.
        guard let output = run("/usr/sbin/system_profiler",
                               ["SPNVMeDataType", "SPSerialATADataType", "SPStorageDataType", "-json"]),
              let root = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
        else { return ([], "system_profiler không trả dữ liệu lưu trữ.") }
        var records: [StorageSnapshot] = []
        var seen = Set<String>()
        func walk(_ value: Any, source: String) {
            if let nodes = value as? [Any] {
                nodes.forEach { walk($0, source: source) }
                return
            }
            guard let node = value as? [String: Any] else { return }
            let name = field(node, ["device_model", "model", "_name", "medium_type"])
            let capacity = field(node, ["size", "capacity", "spnvme_capacity"]) ?? (node["size_in_bytes"] as? NSNumber).map { ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .decimal) }
            let smart = field(node, ["smart_status", "smart", "SMART", "s_m_a_r_t_status"])
            let hardwareLike = node.keys.contains("smart_status")
                || node.keys.contains("device_model")
                || node.keys.contains("physical_drive")
                || node.keys.contains("size_in_bytes")
            if hardwareLike, let name, let capacity {
                let key = source + ":" + name + ":" + capacity
                if seen.insert(key).inserted {
                    records.append(StorageSnapshot(id: key, name: name, capacity: capacity,
                        smart: smart ?? "Không khả dụng", source: source))
                }
            }
            for (key, child) in node where child is [Any] || child is [String: Any] {
                walk(child, source: source + "/" + key)
            }
        }
        for section in ["SPNVMeDataType", "SPSerialATADataType", "SPStorageDataType"] {
            if let values = root[section] { walk(values, source: section) }
        }
        if records.isEmpty {
            return ([], "Chưa xác định được ổ lưu trữ từ system_profiler. Không suy luận SSD hỏng.")
        }
        return (records, "Dữ liệu hệ thống chỉ xác nhận ổ được nhận diện; SMART không khả dụng không phải lỗi ổ.")
    }
    /// Activation Lock đọc được ngay trên máy, không cần mật khẩu hay xóa máy:
    /// system_profiler SPHardwareDataType -json trả activation_lock_status =
    /// activation_lock_enabled / activation_lock_disabled (chỉ có trên máy
    /// Apple Silicon / T2). Apple đã bỏ trang tra cứu công khai theo số serial
    /// từ 2017 nên không tra được từ xa; chắc chắn nhất vẫn là xóa máy và
    /// kích hoạt lại xem có hỏi tài khoản Apple cũ không.
    private static func activationLock() -> String {
        guard let output = run("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"]),
              let data = output.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["SPHardwareDataType"] as? [[String: Any]],
              let device = entries.first,
              let status = device["activation_lock_status"] as? String else { return "Chưa xác định" }
        switch status {
        case "activation_lock_enabled": return "Đã bật"
        case "activation_lock_disabled": return "Đã tắt"
        default: return "Chưa xác định"
        }
    }
    static func collect() -> HardwareHealthSnapshot {
        let battery = battery()
        let (disks, note) = storage()
        return HardwareHealthSnapshot(battery: battery, storage: disks,
                                      diskInfo: note, status: "Đã thu thập dữ liệu khả dụng",
                                      readAt: Date(), activationLock: activationLock())
    }
}

@MainActor
final class HardwareHealthModel: ObservableObject {
    @Published var snapshot = HardwareHealthSnapshot()
    @Published var isReading = false
    func refresh() {
        guard !isReading else { return }
        isReading = true
        DispatchQueue.global(qos: .utility).async {
            let result = NativeHealthProbe.collect()
            DispatchQueue.main.async {
                self.snapshot = result
                self.isReading = false
            }
        }
    }
}

struct HardwareHealthView: View {
    @ObservedObject var model: HardwareHealthModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sức khỏe phần cứng").font(.system(size: 25, weight: .bold))
                Spacer()
                Button(model.isReading ? "Đang đọc..." : "Đọc lại dữ liệu") {
                    model.refresh()
                }.disabled(model.isReading)
            }
            GroupBox("Battery Analyzer") {
                VStack(alignment: .leading, spacing: 8) {
                    let b = model.snapshot.battery
                    if b.present {
                        value("Chu kỳ sạc", b.cycleCount.map(String.init) ?? "Không khả dụng")
                        value("Dung lượng thiết kế", b.designMAh.map { "\($0) mAh" } ?? "Không khả dụng")
                        value("Dung lượng sạc đầy gần nhất", b.maxMAh.map { "\($0) mAh" } ?? "Không khả dụng")
                        value("Sức khỏe ước tính", b.healthPercent.map { String(format: "%.1f%%", $0) } ?? "Không khả dụng")
                        value("Mức sạc hiện tại", b.chargePercent.map { "\($0)%" } ?? "Không khả dụng")
                    } else {
                        Text("Không tìm thấy AppleSmartBattery. Có thể máy không có pin hoặc macOS hạn chế dữ liệu.")
                    }
                    Text("Dữ liệu nguồn: ioreg / AppleSmartBattery; tỷ lệ dung lượng chỉ là ước tính, không chứng nhận pin tốt.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }
            GroupBox("Storage & SMART") {
                VStack(alignment: .leading, spacing: 9) {
                    if model.snapshot.storage.isEmpty {
                        Text("Không có dữ liệu ổ lưu trữ phù hợp để hiển thị.")
                    }
                    ForEach(model.snapshot.storage) { disk in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(disk.name).fontWeight(.semibold)
                            value("Dung lượng", disk.capacity)
                            value("SMART", disk.smart)
                            Text("Nguồn: \(disk.source)").font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                    Text(model.snapshot.diskInfo)
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }
            GroupBox("Activation Lock") {
                VStack(alignment: .leading, spacing: 8) {
                    value("Trạng thái", model.snapshot.activationLock)
                    Text("Đọc từ system_profiler SPHardwareDataType; chỉ có trên máy Apple Silicon / chip T2. Đã bật = máy còn khóa tài khoản Apple của chủ cũ, không nên mua khi chưa gỡ. Chắc chắn nhất vẫn là xóa máy và kích hoạt lại.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }
            Text(model.snapshot.status).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func value(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.system(size: 13))
    }
}
