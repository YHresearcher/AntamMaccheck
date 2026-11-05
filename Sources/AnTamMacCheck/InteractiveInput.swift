import SwiftUI
import AppKit

/// Static ANSI keyboard drawing: keyCode follows macOS hardware key codes.
/// Color is driven by actual keyDown, never by a fabricated test pass.
struct VirtualKeyboardView: View {
    let pressed: Set<UInt16>
    private let layout: [[(UInt16, String)]] = [
        [(50,"~"),(18,"1"),(19,"2"),(20,"3"),(21,"4"),(23,"5"),(22,"6"),(26,"7"),(28,"8"),(25,"9"),(29,"0"),(27,"-"),(24,"="),(51,"⌫")],
        [(48,"Tab"),(12,"Q"),(13,"W"),(14,"E"),(15,"R"),(17,"T"),(16,"Y"),(32,"U"),(34,"I"),(31,"O"),(35,"P"),(33,"["),(30,"]"),(42,"\\")],
        [(57,"Caps"),(0,"A"),(1,"S"),(2,"D"),(3,"F"),(5,"G"),(4,"H"),(38,"J"),(40,"K"),(37,"L"),(41,";"),(39,"'"),(36,"↵")],
        [(56,"⇧"),(6,"Z"),(7,"X"),(8,"C"),(9,"V"),(11,"B"),(45,"N"),(46,"M"),(43,","),(47,"."),(44,"/"),(60,"⇧")],
        [(59,"Ctrl"),(58,"⌥"),(55,"⌘"),(49,"Space"),(54,"⌘"),(61,"⌥"),(123,"←"),(125,"↓"),(126,"↑"),(124,"→")]
    ]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(layout.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(layout[row], id: \.0) { code, label in
                        Text(label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(pressed.contains(code) ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 29)
                            .background(pressed.contains(code) ? Color.green : Color.gray.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.22), lineWidth: 0.5))
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Receives normal pointer motion without any mouse down. This detects
/// hardware cursor activity, not specifically trackpad identity.
struct PointerMotionCapture: NSViewRepresentable {
    var onMotion: () -> Void
    func makeNSView(context: Context) -> MotionNSView {
        let view = MotionNSView()
        view.onMotion = onMotion
        return view
    }
    func updateNSView(_ view: MotionNSView, context: Context) {
        view.onMotion = onMotion
    }
}
final class MotionNSView: NSView {
    var onMotion: (() -> Void)?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }
    private var lastPoint: NSPoint?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for tracking in trackingAreas { removeTrackingArea(tracking) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    override func mouseMoved(with event: NSEvent) {
        let next = convert(event.locationInWindow, from: nil)
        if let previous = lastPoint, hypot(next.x - previous.x, next.y - previous.y) >= 3 {
            onMotion?()
        }
        lastPoint = next
    }
    override func mouseExited(with event: NSEvent) { lastPoint = nil }
}
