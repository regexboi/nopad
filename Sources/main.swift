@preconcurrency import AppKit
import SwiftUI

@MainActor
@main
struct NoPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            NoPadCommands()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var noteWindow: BorderlessKeyWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        makeNoteWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        if closedWindow == noteWindow {
            noteWindow = nil
        }
    }

    private func makeNoteWindow() {
        let window = BorderlessKeyWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 700, height: 460)
        window.isReleasedWhenClosed = false
        window.center()

        let hostingView = NSHostingView(rootView: NoteWindowView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        noteWindow = window
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }
}

private final class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private struct NoPadCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(replacing: .saveItem) { }
        CommandGroup(replacing: .importExport) { }
        CommandGroup(replacing: .appTermination) {
            Button("Close Focused Note") {
                closeFocusedWindow()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        CommandGroup(after: .windowArrangement) {
            Button("Close Focused Note") {
                closeFocusedWindow()
            }
            .keyboardShortcut("w", modifiers: [.command])
        }
    }

    private func closeFocusedWindow() {
        if let keyWindow = NSApp.keyWindow {
            keyWindow.performClose(nil)
            return
        }
        NSApp.windows.last?.performClose(nil)
    }
}

@MainActor
private struct NoteWindowView: View {
    var body: some View {
        ZStack {
            GlassSurface()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(nsColor: Theme.cursor).opacity(0.6))
                    .frame(width: 74, height: 6)
                    .padding(.top, 14)
                    .padding(.bottom, 18)

                MarkdownEditor()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color(nsColor: Theme.accent).opacity(0.52), lineWidth: 1.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                .padding(1)
        )
        .padding(12)
        .frame(minWidth: 700, minHeight: 460)
    }
}

@MainActor
private struct GlassSurface: View {
    var body: some View {
        ZStack {
            VisualEffect(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color(nsColor: Theme.background).opacity(0.92),
                    Color(nsColor: Theme.blue).opacity(0.42),
                    Color(nsColor: Theme.magenta).opacity(0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [
                    Color(nsColor: Theme.cyan).opacity(0.28),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 520
            )

            Color(nsColor: Theme.background).opacity(0.52)
        }
    }
}

@MainActor
private struct MarkdownEditor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.allowsUndo = true
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false
        textView.insertionPointColor = Theme.cursor
        textView.selectedTextAttributes = [NSAttributedString.Key.backgroundColor: Theme.accent.withAlphaComponent(0.25)]
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.font = Theme.bodyFont
        textView.typingAttributes = MarkdownStyler.baseAttributes
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        context.coordinator.styler.attach(textView: textView, storage: textStorage)
        textStorage.delegate = context.coordinator.styler
        context.coordinator.styler.applyStyles()
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) { }

    @MainActor
    final class Coordinator {
        let styler = MarkdownStyler()
    }
}

@MainActor
private final class MarkdownStyler: NSObject, @preconcurrency NSTextStorageDelegate {
    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: Theme.bodyFont,
            .foregroundColor: Theme.foreground,
            .paragraphStyle: Theme.bodyParagraphStyle,
        ]
    }

    private weak var textView: NSTextView?
    private weak var storage: NSTextStorage?
    private var isApplyingStyles = false
    private var styleUpdateScheduled = false

    func attach(textView: NSTextView, storage: NSTextStorage) {
        self.textView = textView
        self.storage = storage
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        scheduleStyleUpdate()
    }

    private func scheduleStyleUpdate() {
        guard !styleUpdateScheduled else { return }
        styleUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.styleUpdateScheduled = false
            self.applyStyles()
        }
    }

    func applyStyles() {
        guard let storage else { return }
        guard !isApplyingStyles else { return }
        isApplyingStyles = true
        defer { isApplyingStyles = false }

        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        storage.setAttributes(Self.baseAttributes, range: fullRange)

        let source = storage.string as NSString
        source.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            guard lineRange.length > 0 else { return }
            guard let heading = Self.headingInfo(for: source.substring(with: lineRange)) else { return }

            storage.addAttributes(
                [
                    .font: Theme.headingFont(level: heading.level),
                    .foregroundColor: Theme.headingForeground,
                    .paragraphStyle: Theme.headingParagraphStyle(level: heading.level),
                ],
                range: lineRange
            )

            let markerRange = NSRange(
                location: lineRange.location + heading.markerStart,
                length: heading.markerLength
            )
            storage.addAttributes(
                [
                    .foregroundColor: Theme.accent,
                ],
                range: markerRange
            )
        }
        storage.endEditing()
    }

    private static func headingInfo(for line: String) -> (level: Int, markerStart: Int, markerLength: Int)? {
        let chars = Array(line)
        guard !chars.isEmpty else { return nil }

        var leadingWhitespace = 0
        while leadingWhitespace < chars.count && (chars[leadingWhitespace] == " " || chars[leadingWhitespace] == "\t") {
            leadingWhitespace += 1
        }

        var hashCount = 0
        while leadingWhitespace + hashCount < chars.count && chars[leadingWhitespace + hashCount] == "#" {
            hashCount += 1
        }

        guard hashCount > 0 && hashCount <= 6 else { return nil }
        if leadingWhitespace + hashCount < chars.count && chars[leadingWhitespace + hashCount] != " " {
            return nil
        }

        return (hashCount, leadingWhitespace, hashCount)
    }
}

@MainActor
private struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@MainActor
private enum Theme {
    static let accent = NSColor(hex: "#b44dff")
    static let cursor = NSColor(hex: "#e0aaff")
    static let background = NSColor(hex: "#1a0533")
    static let foreground = NSColor(hex: "#e8e0f0")
    static let blue = NSColor(hex: "#7b5eff")
    static let magenta = NSColor(hex: "#ff59d6")
    static let cyan = NSColor(hex: "#00e5ff")
    static let brightWhite = NSColor(hex: "#ffffff")

    static var bodyFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
    }

    static var headingForeground: NSColor {
        brightWhite.withAlphaComponent(0.96)
    }

    static var bodyParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 7
        return style
    }

    static func headingParagraphStyle(level: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = level <= 2 ? 10 : 8
        style.paragraphSpacingBefore = level <= 2 ? 4 : 2
        return style
    }

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: return NSFont.systemFont(ofSize: 36, weight: .bold)
        case 2: return NSFont.systemFont(ofSize: 31, weight: .semibold)
        case 3: return NSFont.systemFont(ofSize: 27, weight: .semibold)
        case 4: return NSFont.systemFont(ofSize: 23, weight: .medium)
        case 5: return NSFont.systemFont(ofSize: 20, weight: .medium)
        default: return NSFont.systemFont(ofSize: 18, weight: .medium)
        }
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let hasSixDigits = cleaned.count == 6
        let r = hasSixDigits ? Double((value >> 16) & 0xFF) / 255.0 : 1.0
        let g = hasSixDigits ? Double((value >> 8) & 0xFF) / 255.0 : 1.0
        let b = hasSixDigits ? Double(value & 0xFF) / 255.0 : 1.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
