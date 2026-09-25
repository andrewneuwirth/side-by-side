import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Image helpers

extension NSImage {
    /// Full-resolution CGImage (ignores point size / Retina scaling).
    var fullCGImage: CGImage? {
        if let rep = representations.compactMap({ $0 as? NSBitmapImageRep }).first, let cg = rep.cgImage {
            return cg
        }
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

/// Scales both images to the same height (the taller one's) and places them left-to-right.
func combine(_ left: NSImage, _ right: NSImage) -> Data? {
    guard let l = left.fullCGImage, let r = right.fullCGImage else { return nil }
    let height = max(l.height, r.height)
    let lw = Int((Double(l.width) * Double(height) / Double(l.height)).rounded())
    let rw = Int((Double(r.width) * Double(height) / Double(r.height)).rounded())

    guard let ctx = CGContext(
        data: nil, width: lw + rw, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.draw(l, in: CGRect(x: 0, y: 0, width: lw, height: height))
    ctx.draw(r, in: CGRect(x: lw, y: 0, width: rw, height: height))

    guard let out = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])
}

// MARK: - Drop zone

struct DropZone: View {
    let label: String
    @Binding var image: NSImage?
    @State private var targeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(targeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.4),
                              style: StrokeStyle(lineWidth: 2, dash: image == nil ? [8, 6] : []))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 40))
                    Text(label).font(.headline)
                    Text("Drop an image or click to choose").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
        .onDrop(of: [.fileURL, .image], isTargeted: $targeted, perform: handleDrop)
        .overlay(alignment: .topTrailing) {
            if image != nil {
                Button { image = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white, .black.opacity(0.6))
                .padding(12)
            }
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            image = img
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, let img = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async { image = img }
            }
            return true
        }
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                guard let img = obj as? NSImage else { return }
                DispatchQueue.main.async { image = img }
            }
            return true
        }
        return false
    }
}

// MARK: - Main view

struct ContentView: View {
    @State private var left: NSImage?
    @State private var right: NSImage?
    @State private var status = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                DropZone(label: "Left photo", image: $left)
                DropZone(label: "Right photo", image: $right)
            }

            HStack {
                Button {
                    swap(&left, &right)
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                .disabled(left == nil && right == nil)

                Text(status).font(.caption).foregroundStyle(.secondary)
                Spacer()

                Button(action: download) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(left == nil || right == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 420)
    }

    private func download() {
        guard let left, let right, let png = combine(left, right) else {
            status = "Couldn't combine those images."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "side-by-side \(stamp).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url)
            status = "Saved \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - App

/// Stays running in the background after the window closes so the global
/// Option+M hotkey can bring the window back at any time.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    private var window: NSWindow!
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Side by Side"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView())
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.delegate = self

        registerHotKey()
        try? SMAppService.mainApp.register()   // launch at login so the hotkey is always live
        showWindow()
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Option+M toggles: brings the window up, or hides it if it's already in front.
    func toggleWindow() {
        if window.isVisible && NSApp.isActive && window.isKeyWindow {
            window.close()
        } else {
            showWindow()
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // drop the Dock icon while hidden
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        return false
    }

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { AppDelegate.shared.toggleWindow() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x53425953) /* 'SBYS' */, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

@main
enum SideBySideApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppDelegate.shared = delegate
        app.delegate = delegate
        app.mainMenu = makeMenu()
        app.run()
    }

    /// Minimal menu so ⌘Q, ⌘W, copy/paste work without a SwiftUI App scene.
    private static func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Side by Side", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        return main
    }
}
