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
    @Published var colorIndex = -1
    @Published var speakerState = "Chưa phát âm thanh"
    @Published var recorderState = "Chưa ghi âm"
    @Published var cameraState = "Chưa mở camera"
    @Published var portsText = "Chưa đọc danh sách thiết bị kết nối."
    @Published var recording = false
    @Published var microphonePlayedBack = false
    @Published var webcamRunning = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var speakerPlayer: AVAudioPlayer?
    private var cameraSession: AVCaptureSession?

    let colorCount = 12

    func mark(_ name: String) { attempted.insert(name) }
    func reset() {
        stopRecording()
        stopCamera()
        attempted.removeAll()
        capturedKeys.removeAll()
        dragSamples = 0
        colorIndex = -1
        speakerPlayer?.stop()
        speakerState = "Chưa phát âm thanh"
        recorderState = "Chưa ghi âm"
        microphonePlayedBack = false
        cameraState = "Chưa mở camera"
        portsText = "Chưa đọc danh sách thiết bị kết nối."
    }
    func canConfirm(_ name: String) -> Bool {
        switch name {
        case "Bàn phím": return capturedKeys.count >= 10
        case "Trackpad": return dragSamples >= 10
        case "Màn hình": return attempted.contains("Màn hình") && colorIndex == colorCount - 1
        case "Microphone": return attempted.contains(name) && microphonePlayedBack && !recording
        case "Loa", "Webcam", "Cổng kết nối": return attempted.contains(name)
        default: return true // Ngoại quan cần xác nhận bằng mắt
        }
    }
    func playSpeaker() {
        guard let path = Bundle.main.url(forResource: "StereoSpeakerTest", withExtension: "wav") else {
            speakerState = "Thiếu file stereo test WAV trong app. Không được đánh dấu Đạt."
            return
        }
        do {
            speakerPlayer = try AVAudioPlayer(contentsOf: path)
            speakerPlayer?.prepareToPlay()
            if speakerPlayer?.play() == true {
                attempted.insert("Loa")
                speakerState = "Đang phát nhạc thử: kênh trái trước, kênh phải sau. Hãy nghe từng bên."
            } else {
                speakerState = "Không phát được file test. Kiểm tra thiết bị đầu ra âm thanh."
            }
        } catch {
            speakerState = "Lỗi phát âm thanh: \(error.localizedDescription)"
        }
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
                    self.microphonePlayedBack = false
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
            microphonePlayedBack = player?.play() ?? false
            if microphonePlayedBack { recorderState = "Đang nghe lại — hãy đánh giá độ rõ tiếng." }
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
    override func flagsChanged(with event: NSEvent) {
        // Phím bổ trợ (Caps, Shift, Ctrl, Option, Cmd, Fn) KHÔNG bao giờ
        // gửi keyDown — macOS chỉ báo qua flagsChanged, với keyCode là phím
        // vật lý vừa đổi trạng thái (trái/phải phân biệt được: Shift trái 56,
        // Shift phải 60, Ctrl trái 59, Ctrl phải 62, Option trái 58, Option
        // phải 61, Cmd trái 55, Cmd phải 54, Caps 57, Fn 63). Không có hàm
        // này thì mọi phím bổ trợ đều không bao giờ sáng trên bàn phím ảo.
        // Chỉ nhận đúng 10 mã phím bổ trợ, bỏ qua mọi flagsChanged khác.
        // Ghi nhận kiểu insert-only như phím thường: bấm một lần là giữ xanh.
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        if modifierKeyCodes.contains(event.keyCode) { onKey?(event.keyCode) }
    }
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
    @EnvironmentObject private var lang: LanguageStore
    @State private var displaySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch name {
            case "Màn hình":
                Text(tr("Kiểm tra toàn màn hình với 12 màu (RGB, CMY, nhiều mức xám, trắng/đen). Dùng phím ← / → để chuyển, Esc để thoát."))
                Button(tr("Mở test toàn màn hình")) {
                    tools.mark("Màn hình")
                    tools.colorIndex = -1
                    FullscreenColorTester.shared.open { index in tools.colorIndex = index }
                }
                Text(trf("Đã xem %d/%d màu.", max(0, tools.colorIndex + 1), tools.colorCount))
                    .font(.caption)
            case "Bàn phím":
                Text(tr("Bàn phím ảo sáng lên khi phím vật lý được nhận. Nhấp vùng dưới để nhận bàn phím."))
                VirtualKeyboardView(pressed: tools.capturedKeys)
                KeyCapture { code in tools.capturedKeys.insert(code) }
                    .frame(height: 48).frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(Text(trf("Nhấp đây rồi gõ phím • Đã nhận %d phím", tools.capturedKeys.count))
                        .allowsHitTesting(false))
                Text(tr("Bấm từng phím bổ trợ trái/phải riêng để kiểm tra: Caps, Shift, Ctrl, Option, Cmd, Fn đều sáng khi nhận. Bàn phím MacBook tích hợp không có Ctrl phải — phím đó chỉ sáng khi dùng bàn phím rời."))
                    .font(.caption).foregroundStyle(.secondary)
            case "Trackpad":
                Text(tr("Chỉ cần di chuyển ngón tay trên trackpad, KHÔNG cần đè click. Thử nhấp, kéo, cuộn và đa điểm riêng."))
                PointerMotionCapture { tools.dragSamples += 1 }
                    .frame(height: 160).frame(maxWidth: .infinity)
                    .background(Color.teal.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(Text(trf("Di chuyển con trỏ trong vùng này — %d lượt di chuyển", tools.dragSamples))
                        .allowsHitTesting(false))
                Text(tr("Chuột rời cũng tạo chuyển động tương tự. Việc xác nhận trackpad thật vẫn cần người kiểm tra."))
                    .font(.caption).foregroundStyle(.secondary)
            case "Loa":
                Text(tr("Phát bản nhạc kiểm tra stereo gốc: giai điệu kênh TRÁI, sau đó kênh PHẢI. Chú ý loa rè/méo và âm lượng từng bên."))
                Button(tr("♫ Phát file nhạc test trái/phải")) { tools.playSpeaker() }
                Text(tr(tools.speakerState)).font(.caption).foregroundStyle(.secondary)
            case "Microphone":
                Text(tr("Ghi âm từ mic được chọn, sau đó nghe lại để xác nhận chất lượng."))
                HStack {
                    Button(tools.recording ? tr("■ Dừng ghi âm") : tr("● Ghi âm")) {
                        if tools.recording { tools.stopRecording() } else { tools.startRecording() }
                    }
                    Button(tr("▶ Nghe lại")) { tools.playRecording() }.disabled(tools.recording)
                }
                Text(tr(tools.recorderState)).font(.caption).foregroundStyle(.secondary)
            case "Webcam":
                Text(tr("Xin quyền Camera, xem hình trực tiếp rồi đánh giá độ rõ và hiện tượng nhiễu."))
                HStack {
                    Button(tools.webcamRunning ? tr("Dừng camera") : tr("Mở camera")) {
                        if tools.webcamRunning { tools.stopCamera() } else { tools.beginCamera() }
                    }
                    Text(tr(tools.cameraState)).font(.caption)
                }
                if let session = tools.cameraPreview() {
                    CameraPreview(session: session).frame(height: 185).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            case "Cổng kết nối":
                Text(tr("Cắm từng cổng USB/Thunderbolt thực tế và quan sát thiết bị xuất hiện trong danh sách."))
                Button(tr("Làm mới thiết bị kết nối")) { tools.detectPorts() }
                ScrollView {
                    Text(tr(tools.portsText)).font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(height: 135).padding(8).background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            default:
                Text(tr("Kiểm tra bằng mắt: vỏ máy, bản lề, điểm móp, dấu tháo lắp, pin phồng, cổng và ngoại quan. Không tự xác nhận."))
            }
        }
    }
}
