import SwiftUI
import AppKit
import AVFoundation

/// User-driven diagnostics. A tool starting or running never constitutes a pass.
/// Confirmation is separate and requires a relevant interaction when available.
@MainActor
final class DiagnosticSession: ObservableObject {
    @Published var attempted: Set<String> = []
    @Published var capturedKeys: Set<UInt16> = []
    @Published var dragSamples = 0
    @Published var colorIndex = 0
    @Published var recorderState = "Chưa ghi âm"
    @Published var cameraState = "Chưa mở camera"
    @Published var portsText = "Chưa đọc danh sách thiết bị kết nối."
    @Published var recording = false
    @Published var webcamRunning = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private let voice = NSSpeechSynthesizer()
    private var cameraSession: AVCaptureSession?

    let colors: [(String, Color)] = [
        ("Trắng", .white), ("Đen", .black), ("Đỏ", .red),
        ("Xanh lá", .green), ("Xanh dương", .blue)
    ]

    func mark(_ name: String) { attempted.insert(name) }
    func reset() {
        stopRecording()
        stopCamera()
        attempted.removeAll()
        capturedKeys.removeAll()
        dragSamples = 0
        colorIndex = 0
        recorderState = "Chưa ghi âm"
        cameraState = "Chưa mở camera"
        portsText = "Chưa đọc danh sách thiết bị kết nối."
    }
    func canConfirm(_ name: String) -> Bool {
        switch name {
        case "Bàn phím": return !capturedKeys.isEmpty
        case "Trackpad": return dragSamples > 0
        case "Màn hình": return attempted.contains("Màn hình") && colorIndex == colors.count - 1
        case "Loa", "Microphone", "Webcam", "Cổng kết nối": return attempted.contains(name)
        default: return true // Ngoại quan cần xác nhận bằng mắt
        }
    }
    func playSpeaker() {
        attempted.insert("Loa")
        voice.stopSpeaking()
        voice.startSpeaking("An Tâm Mac check. Hãy nghe âm thanh từ cả hai loa, kiểm tra có rè hoặc mất tiếng không.")
    }
    func startRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { allowed in
            Task { @MainActor in
                guard allowed else { self.recorderState = "Chưa được cấp quyền Microphone"; return }
                do {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("antam-mic-test.m4a")
                    let rec = try AVAudioRecorder(url: url, settings: [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ])
                    rec.prepareToRecord()
                    guard rec.record() else { self.recorderState = "Không khởi động được ghi âm"; return }
                    self.recorder = rec
                    self.recording = true
                    self.attempted.insert("Microphone")
                    self.recorderState = "Đang ghi âm — hãy nói một câu rồi bấm Dừng"
                } catch { self.recorderState = "Lỗi ghi âm: \(error.localizedDescription)" }
            }
        }
    }
    func stopRecording() {
        recorder?.stop()
        if recording { recorderState = "Đã ghi âm — bấm Nghe lại để tự đánh giá" }
        recording = false
    }
    func playRecording() {
        guard let url = recorder?.url else { recorderState = "Chưa có bản ghi"; return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch { recorderState = "Không phát lại được: \(error.localizedDescription)" }
    }
    func beginCamera() {
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            Task { @MainActor in
                guard allowed else { self.cameraState = "Chưa được cấp quyền Camera"; return }
                guard let device = AVCaptureDevice.default(for: .video) else {
                    self.cameraState = "Không tìm thấy camera"; return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    let session = AVCaptureSession()
                    guard session.canAddInput(input) else {
                        self.cameraState = "Không thêm được camera"; return
                    }
                    session.addInput(input)
                    self.cameraSession = session
                    self.webcamRunning = true
                    self.cameraState = "Đã mở camera — quan sát hình ở cửa sổ xem trước"
                    self.attempted.insert("Webcam")
                    DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
                } catch { self.cameraState = "Lỗi camera: \(error.localizedDescription)" }
            }
        }
    }
    func stopCamera() {
        if let cameraSession {
            DispatchQueue.global(qos: .userInitiated).async { cameraSession.stopRunning() }
        }
        cameraSession = nil
        webcamRunning = false
    }
    func cameraPreview() -> AVCaptureSession? { cameraSession }
    func detectPorts() {
        attempted.insert("Cổng kết nối")
        portsText = "Đang đọc USB/Thunderbolt — danh sách chỉ xác nhận thiết bị được hệ thống nhìn thấy, không xác nhận mọi cổng vật lý."
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPUSBDataType", "SPThunderboltDataType", "-detailLevel", "mini"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            do {
                try p.run()
                let raw = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let text = String(data: raw, encoding: .utf8) ?? "Không đọc được."
                Task { @MainActor in self.portsText = p.terminationStatus == 0 ? text : "system_profiler không trả kết quả hợp lệ." }
            } catch {
                Task { @MainActor in self.portsText = "Lỗi đọc thiết bị: \(error.localizedDescription)" }
            }
        }
    }
}

struct KeyCapture: NSViewRepresentable {
    var onKey: (UInt16) -> Void
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKey = onKey
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKey = onKey
        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== nsView { nsView.window?.makeFirstResponder(nsView) }
        }
    }
}
final class KeyCaptureNSView: NSView {
    var onKey: ((UInt16) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) { onKey?(event.keyCode) }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer = layer
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        (view.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}

struct DiagnosticToolView: View {
    let name: String
    @ObservedObject var tools: DiagnosticSession
    @State private var displaySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch name {
            case "Màn hình":
                Text("Hiển thị lần lượt 5 vùng màu lớn để tìm điểm chết và ám màu. Muốn kiểm tra toàn bộ bề mặt, hãy phóng to cửa sổ.")
                Button("Mở bài test 5 màu") {
                    tools.mark("Màn hình")
                    tools.colorIndex = 0
                    displaySheet = true
                }
                Text("Đã xem \(min(tools.colorIndex + 1, 5))/5 màu.").font(.caption)
            case "Bàn phím":
                Text("Nhấp vào vùng dưới rồi nhấn lần lượt các phím thực tế. Phím đã nhận: \(tools.capturedKeys.count)")
                KeyCapture { code in tools.capturedKeys.insert(code) }
                    .frame(height: 70).frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(Text("Nhấn phím ở đây").allowsHitTesting(false))
                Text("Kiểm tra từng phím còn cần đối chiếu toàn bộ bàn phím; app không tự kết luận đạt.").font(.caption)
            case "Trackpad":
                Text("Dùng trackpad kéo liên tục trong vùng bên dưới; thử cả nhấp, cuộn và đa điểm bằng tay.")
                RoundedRectangle(cornerRadius: 12).fill(Color.teal.opacity(0.14))
                    .frame(height: 105)
                    .overlay(Text("↔  Kéo thử trên trackpad (\(tools.dragSamples))"))
                    .gesture(DragGesture(minimumDistance: 5).onChanged { _ in tools.dragSamples += 1 })
                Text("Chuột rời cũng có thể tạo thao tác kéo; xác nhận trackpad thực bằng quan sát.").font(.caption)
            case "Loa":
                Text("Phát câu thử qua thiết bị âm thanh đang chọn. Nghe cả hai bên, kiểm tra rè/méo.")
                Button("▶ Phát tiếng thử") { tools.playSpeaker() }
            case "Microphone":
                Text("Ghi âm từ mic được chọn, sau đó nghe lại để xác nhận chất lượng.")
                HStack {
                    Button(tools.recording ? "■ Dừng ghi âm" : "● Ghi âm") {
                        if tools.recording { tools.stopRecording() } else { tools.startRecording() }
                    }
                    Button("▶ Nghe lại") { tools.playRecording() }.disabled(tools.recording)
                }
                Text(tools.recorderState).font(.caption).foregroundStyle(.secondary)
            case "Webcam":
                Text("Xin quyền Camera, xem hình trực tiếp rồi đánh giá độ rõ và hiện tượng nhiễu.")
                HStack {
                    Button(tools.webcamRunning ? "Dừng camera" : "Mở camera") {
                        if tools.webcamRunning { tools.stopCamera() } else { tools.beginCamera() }
                    }
                    Text(tools.cameraState).font(.caption)
                }
                if let session = tools.cameraPreview() {
                    CameraPreview(session: session).frame(height: 185).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            case "Cổng kết nối":
                Text("Cắm từng cổng USB/Thunderbolt thực tế và quan sát thiết bị xuất hiện trong danh sách.")
                Button("Làm mới thiết bị kết nối") { tools.detectPorts() }
                ScrollView {
                    Text(tools.portsText).font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(height: 135).padding(8).background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            default:
                Text("Kiểm tra bằng mắt: vỏ máy, bản lề, điểm móp, dấu tháo lắp, pin phồng, cổng và ngoại quan. Không tự xác nhận.")
            }
        }
        .sheet(isPresented: $displaySheet) {
            VStack {
                HStack {
                    Text("Màu \(tools.colorIndex + 1)/5 — \(tools.colors[tools.colorIndex].0)")
                        .font(.headline)
                    Spacer()
                    Button("Đóng") { displaySheet = false }
                }.padding(12)
                Rectangle().fill(tools.colors[tools.colorIndex].1)
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                Button(tools.colorIndex == 4 ? "Hoàn tất quan sát" : "Màu tiếp theo →") {
                    if tools.colorIndex < 4 { tools.colorIndex += 1 }
                    else { displaySheet = false }
                }.padding(12)
            }.frame(minWidth: 630, minHeight: 460)
        }
    }
}
