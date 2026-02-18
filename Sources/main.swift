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
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        makeNoteWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            makeNoteWindow()
        }
        return true
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
        window.level = .statusBar
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
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

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command) else { return event }
            guard !flags.contains(.option), !flags.contains(.control), !flags.contains(.function), !flags.contains(.shift) else {
                return event
            }
            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
            guard key == "q" || key == "w" else { return event }
            self.closeFocusedWindow()
            return nil
        }
    }

    private func closeFocusedWindow() {
        if let keyWindow = NSApp.keyWindow {
            keyWindow.close()
            return
        }
        NSApp.windows.last?.close()
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isPlainCommand = flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.function)
            && !flags.contains(.shift)

        if isPlainCommand, let key = event.charactersIgnoringModifiers?.lowercased(), key == "q" || key == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
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
            keyWindow.close()
            return
        }
        NSApp.windows.last?.close()
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

private final class GlowCursorTextView: NSTextView {
    struct CharacterFade {
        let location: Int
        let opacity: CGFloat
    }

    private var characterFades: [CharacterFade] = []

    func updateCharacterFades(_ fades: [CharacterFade]) {
        characterFades = fades
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawCharacterFadeOverlay(in: dirtyRect)
    }

    private func drawCharacterFadeOverlay(in dirtyRect: NSRect) {
        guard !characterFades.isEmpty else { return }
        guard let textContainer, let layoutManager else { return }

        let textLength = (string as NSString).length
        let textOrigin = textContainerOrigin

        for fade in characterFades {
            guard fade.opacity > 0.01 else { continue }
            guard fade.location >= 0, fade.location < textLength else { continue }

            let charRange = NSRange(location: fade.location, length: 1)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { continue }

            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard !rect.isNull, !rect.isEmpty else { continue }
            rect.origin.x += textOrigin.x
            rect.origin.y += textOrigin.y
            rect = rect.insetBy(dx: -2.6, dy: -1.8)
            guard rect.intersects(dirtyRect) else { continue }

            let outerRect = rect.insetBy(dx: -2.8, dy: -1.6)
            let innerRect = rect.insetBy(dx: -0.8, dy: -0.2)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .plusLighter

            let outerShadow = NSShadow()
            outerShadow.shadowBlurRadius = 8
            outerShadow.shadowOffset = .zero
            outerShadow.shadowColor = Theme.shimmer.withAlphaComponent(0.28 * fade.opacity)
            outerShadow.set()
            Theme.shimmer.withAlphaComponent(0.06 * fade.opacity).setFill()
            NSBezierPath(ovalIn: outerRect).fill()

            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .plusLighter
            Theme.shimmer.withAlphaComponent(0.10 * fade.opacity).setFill()
            NSBezierPath(ovalIn: innerRect).fill()

            NSGraphicsContext.restoreGraphicsState()
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

        let textView = GlowCursorTextView(frame: .zero, textContainer: textContainer)
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

    private struct CharacterFadeState {
        var location: Int
        var startedAt: TimeInterval
    }

    private weak var glowTextView: GlowCursorTextView?
    private weak var storage: NSTextStorage?
    private var isApplyingStyles = false
    private var styleUpdateScheduled = false
    private var activeCharacterFades: [CharacterFadeState] = []
    private var shimmerTimer: Timer?

    func attach(textView: NSTextView, storage: NSTextStorage) {
        self.glowTextView = textView as? GlowCursorTextView
        self.storage = storage
    }

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        registerCharacterFades(from: textStorage, editedRange: editedRange, delta: delta)
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

    private func registerCharacterFades(from textStorage: NSTextStorage, editedRange: NSRange, delta: Int) {
        rebaseCharacterFades(editedRange: editedRange, delta: delta)

        guard editedRange.length > 0 else {
            if activeCharacterFades.isEmpty {
                glowTextView?.updateCharacterFades([])
                stopShimmerTimer()
            }
            return
        }

        let source = textStorage.string as NSString
        let upper = min(source.length, editedRange.location + editedRange.length)
        guard editedRange.location < upper else { return }

        let now = Date.timeIntervalSinceReferenceDate
        for location in editedRange.location..<upper {
            let character = Self.characterAt(location, in: source)
            guard !character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            activeCharacterFades.removeAll { $0.location == location }
            activeCharacterFades.append(CharacterFadeState(location: location, startedAt: now))
        }

        if activeCharacterFades.isEmpty {
            glowTextView?.updateCharacterFades([])
            stopShimmerTimer()
            return
        }

        ensureShimmerTimer()
        tickCharacterFades()
    }

    private func rebaseCharacterFades(editedRange: NSRange, delta: Int) {
        guard !activeCharacterFades.isEmpty else { return }

        let oldEditedLength = max(0, editedRange.length - delta)
        let oldEditedRange = NSRange(location: editedRange.location, length: oldEditedLength)
        let oldEditedEnd = oldEditedRange.location + oldEditedRange.length

        activeCharacterFades = activeCharacterFades.compactMap { fade in
            if NSLocationInRange(fade.location, oldEditedRange) {
                return nil
            }

            var shifted = fade.location
            if shifted >= oldEditedEnd {
                shifted += delta
            }

            guard shifted >= 0 else { return nil }
            return CharacterFadeState(location: shifted, startedAt: fade.startedAt)
        }
    }

    private static func characterAt(_ index: Int, in source: NSString) -> String {
        source.substring(with: NSRange(location: index, length: 1))
    }

    private func ensureShimmerTimer() {
        guard shimmerTimer == nil else { return }
        shimmerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickCharacterFades()
            }
        }
        RunLoop.main.add(shimmerTimer!, forMode: .common)
    }

    private func stopShimmerTimer() {
        shimmerTimer?.invalidate()
        shimmerTimer = nil
    }

    private func tickCharacterFades() {
        guard let glowTextView else {
            activeCharacterFades.removeAll()
            stopShimmerTimer()
            return
        }
        guard let storage else {
            glowTextView.updateCharacterFades([])
            activeCharacterFades.removeAll()
            stopShimmerTimer()
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        let textLength = storage.length
        var nextStates: [CharacterFadeState] = []
        var renderStates: [GlowCursorTextView.CharacterFade] = []

        for fade in activeCharacterFades {
            guard fade.location >= 0, fade.location < textLength else { continue }

            let elapsed = now - fade.startedAt
            let progress = CGFloat(elapsed / Theme.characterFadeDuration)
            guard progress < 1 else { continue }

            let opacity = pow(1 - progress, 1.6)
            nextStates.append(fade)
            renderStates.append(GlowCursorTextView.CharacterFade(location: fade.location, opacity: opacity))
        }

        activeCharacterFades = nextStates

        if renderStates.isEmpty {
            glowTextView.updateCharacterFades([])
            stopShimmerTimer()
            return
        }

        glowTextView.updateCharacterFades(renderStates)
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
    static let cursor = NSColor(hex: "#ffd400")
    static let shimmer = NSColor(hex: "#ffe866")
    static let background = NSColor(hex: "#1a0533")
    static let foreground = NSColor(hex: "#e8e0f0")
    static let blue = NSColor(hex: "#7b5eff")
    static let magenta = NSColor(hex: "#ff59d6")
    static let cyan = NSColor(hex: "#00e5ff")
    static let brightWhite = NSColor(hex: "#ffffff")
    static let cursorWidth: CGFloat = 6.0
    static let characterFadeDuration: TimeInterval = 0.28

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
