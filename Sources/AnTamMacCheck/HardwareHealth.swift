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
    var isCharging: Bool?
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
struct StorageVolumeSnapshot: Identifiable {
    let id: String
    let name: String
}
struct HardwareHealthSnapshot {
    var battery = BatterySnapshot()
    var storage: [StorageSnapshot] = []
    var storageVolumes: [StorageVolumeSnapshot] = []
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
        if output.contains("\"IsCharging\" = Yes") { battery.isCharging = true }
        else if output.contains("\"IsCharging\" = No") { battery.isCharging = false }
        return battery
    }
    private static func field(_ data: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = data[key] as? String, !value.isEmpty { return value }
            if let value = data[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }
    /// Only physical devices are shown as SSDs. APFS volumes are not disks:
    /// SPNVMeDataType may nest them under a device, while SPStorageDataType
    /// repeats the same volumes independently. Never count either as SSDs.
    private static func storage() -> ([StorageSnapshot], [StorageVolumeSnapshot], String) {
        guard let output = run("/usr/sbin/system_profiler",
                               ["SPNVMeDataType", "SPSerialATADataType", "-json"]),
              let root = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
        else { return ([], apfsVolumes(), "Không đọc được danh sách ổ vật lý từ system_profiler.") }

        var disks: [StorageSnapshot] = []
        var seen = Set<String>()
        for section in ["SPNVMeDataType", "SPSerialATADataType"] {
            guard let controllers = root[section] as? [[String: Any]] else { continue }
            // Controllers may contain a physical device under "items"; never
            // recurse further into its "volumes", "partitions", etc.
            func appendPhysical(_ node: [String: Any]) {
                let name = field(node, ["device_model", "model"])
                let capacity = field(node, ["size", "capacity", "spnvme_capacity"])
                    ?? (node["size_in_bytes"] as? NSNumber).map {
                        ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .decimal)
                    }
                guard let name, let capacity, !name.isEmpty else { return }
                // Identity intentionally excludes the source path: duplicate
                // sightings of the same device must not count twice.
                let identity = (name + "|" + capacity).lowercased()
                guard seen.insert(identity).inserted else { return }
                let smart = field(node, ["smart_status", "smart", "SMART", "s_m_a_r_t_status"])
                disks.append(StorageSnapshot(id: identity, name: name, capacity: capacity,
                                             smart: smart ?? "Không khả dụng", source: section))
            }
            for controller in controllers {
                if let items = controller["_items"] as? [[String: Any]] {
                    items.forEach(appendPhysical)
                } else if let items = controller["items"] as? [[String: Any]] {
                    items.forEach(appendPhysical)
                } else {
                    appendPhysical(controller)
                }
            }
        }
        let volumes = apfsVolumes()
        let note = disks.isEmpty
            ? "Chưa nhận diện được ổ vật lý; không suy luận SSD hỏng."
            : "Chỉ liệt kê ổ vật lý. APFS volumes được hiển thị riêng; SMART không khả dụng không đồng nghĩa SSD lỗi."
        return (disks, volumes, note)
    }

    /// Read APFS volumes independently and use their identifiers to remove
    /// duplicate entries. The list is informational, not a health verdict.
    private static func apfsVolumes() -> [StorageVolumeSnapshot] {
        guard let raw = run("/usr/sbin/diskutil", ["apfs", "list", "-plist"]),
              let data = raw.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let root = plist as? [String: Any],
              let containers = root["Containers"] as? [[String: Any]]
        else { return [] }
        var volumes: [StorageVolumeSnapshot] = []
        var seen = Set<String>()
        for container in containers {
            guard let nodes = container["Volumes"] as? [[String: Any]] else { continue }
            for node in nodes {
                guard let identifier = node["DeviceIdentifier"] as? String,
                      !identifier.isEmpty, seen.insert(identifier).inserted else { continue }
                let name = (node["Name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (node["APFSVolumeName"] as? String) ?? identifier
                volumes.append(StorageVolumeSnapshot(id: identifier, name: name))
            }
        }
        return volumes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
        let (disks, volumes, note) = storage()
        return HardwareHealthSnapshot(battery: battery, storage: disks,
                                      storageVolumes: volumes, diskInfo: note, status: "Đã thu thập dữ liệu khả dụng",
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
                    if !model.snapshot.storageVolumes.isEmpty {
                        DisclosureGroup("Xem các volume APFS (\(model.snapshot.storageVolumes.count))") {
                            ForEach(model.snapshot.storageVolumes) { volume in
                                HStack {
                                    Text(volume.name)
                                    Spacer()
                                    Text(volume.id).foregroundStyle(.secondary)
                                }.font(.caption)
                            }
                            Text("Các volume nằm bên trong ổ vật lý, không phải ổ cứng riêng.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
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
