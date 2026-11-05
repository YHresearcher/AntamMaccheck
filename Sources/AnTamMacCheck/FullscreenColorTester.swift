import AppKit

/// Entire-display color test. Uses a genuine borderless macOS window rather
/// than a SwiftUI sheet, so pixels fill the display, including the menu bar.
@MainActor
final class FullscreenColorTester {
    static let shared = FullscreenColorTester()
    private var window: ColorTestWindow?
    private var index = 0
    private var onChange: ((Int) -> Void)?

    // Additional grayscale, RGB, CMY and contrast patterns for inspection.
    private let colors: [(String, NSColor)] = [
        ("Trắng", .white), ("Đen", .black), ("Đỏ", .red),
        ("Xanh lá", .green), ("Xanh dương", .blue),
        ("Xám 25%", NSColor(white: 0.25, alpha: 1)),
        ("Xám 50%", NSColor(white: 0.50, alpha: 1)),
        ("Xám 75%", NSColor(white: 0.75, alpha: 1)),
        ("Vàng", .yellow), ("Cyan", .cyan),
        ("Magenta", .magenta),
        ("Trắng ấm", NSColor(red: 1, green: 0.93, blue: 0.82, alpha: 1))
    ]
    var count: Int { colors.count }

    func open(onChange: @escaping (Int) -> Void) {
        close()
        self.onChange = onChange
        index = 0
        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main else { return }
        let w = ColorTestWindow(contentRect: screen.frame, styleMask: [.borderless],
                                backing: .buffered, defer: false, screen: screen)
        w.level = .screenSaver
        w.isOpaque = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.onNext = { [weak self] in self?.next() }
        w.onPrevious = { [weak self] in self?.previous() }
        w.onClose = { [weak self] in self?.close() }

        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.wantsLayer = true
        label.layer?.cornerRadius = 9
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.70).cgColor
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(label)
        if let content = w.contentView {
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
                label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                label.widthAnchor.constraint(greaterThanOrEqualToConstant: 380),
                label.heightAnchor.constraint(equalToConstant: 38)
            ])
        }
        w.statusLabel = label
        window = w
        showCurrent()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        w.makeFirstResponder(w.contentView)
    }

    private func showCurrent() {
        guard let w = window else { return }
        w.backgroundColor = colors[index].1
        w.contentView?.layer?.backgroundColor = colors[index].1.cgColor
        w.statusLabel?.stringValue = "  \(index + 1)/\(colors.count): \(colors[index].0)    ← / → đổi màu    Esc thoát  "
        onChange?(index)
    }
    private func next() {
        guard index < colors.count - 1 else { close(); return }
        index += 1
        showCurrent()
    }
    private func previous() {
        index = max(0, index - 1)
        showCurrent()
    }
    func close() {
        window?.orderOut(nil)
        window = nil
        onChange = nil
    }
}
final class ColorTestWindow: NSWindow {
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onClose: (() -> Void)?
    weak var statusLabel: NSTextField?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch event.keyCode {
            case 53: onClose?(); return      // Escape
            case 124: onNext?(); return     // Right arrow
            case 123: onPrevious?(); return // Left arrow
            default: break
            }
        }
        super.sendEvent(event)
    }
}
