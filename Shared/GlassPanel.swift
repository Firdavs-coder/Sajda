import AppKit
import SwiftUI

/// Shared dark glass tint so white labels stay readable over bright wallpapers.
enum ControlGlassStyle {
    static let legibilityTint = Color.black.opacity(0.55)
    /// Card surface — near-black, matches the MenuBarExtra host fill.
    static let darkBase = Color(red: 0.08, green: 0.10, blue: 0.12).opacity(0.94)
}

/// Control Center–style liquid glass surface.
///
/// On macOS 26+ this is pure system `glassEffect` (the same material used by
/// Wi‑Fi / Focus / Display tiles). A dark base tint keeps white labels readable
/// over bright wallpapers while still letting the desktop refract through.
extension View {
    /// Wraps content in a Control Center glass tile.
    ///
    /// - Parameter tint: Optional accent (e.g. cyan). Always mixed over a dark
    ///   base so white text stays readable.
    func controlGlass(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        modifier(
            ControlGlassModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive
            )
        )
    }

    /// Legacy name used around the app — same Control Center glass.
    func glassPanel(
        shape: some InsettableShape,
        tint: Color = .clear,
        strokeOpacity: Double = 0.22,
        clear: Bool = false,
        interactive: Bool = true
    ) -> some View {
        modifier(
            GlassPanelModifier(
                shape: shape,
                tint: tint == .clear ? ControlGlassStyle.legibilityTint : tint,
                strokeOpacity: strokeOpacity,
                clear: clear,
                interactive: interactive
            )
        )
    }
}

// MARK: - Control Center tile

private struct ControlGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Glass tint: dark by default, or a darkened accent when one is provided.
    private var glassTint: Color {
        if let tint {
            return tint.opacity(0.50)
        }
        return ControlGlassStyle.legibilityTint
    }

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background { shape.fill(ControlGlassStyle.darkBase) }
                .glassEffect(glassConfiguration, in: shape)
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(ControlGlassStyle.darkBase)
                    if let tint {
                        shape.fill(tint.opacity(0.35))
                    }
                }
                .clipShape(shape)
        }
    }

    @available(macOS 26.0, *)
    private var glassConfiguration: Glass {
        var glass: Glass = .regular.tint(glassTint)
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

// MARK: - Shape-based glass (flexible)

private struct GlassPanelModifier<PanelShape: InsettableShape>: ViewModifier {
    let shape: PanelShape
    let tint: Color?
    let strokeOpacity: Double
    let clear: Bool
    let interactive: Bool

    private var resolvedTint: Color {
        tint ?? ControlGlassStyle.legibilityTint
    }

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background { shape.fill(ControlGlassStyle.darkBase) }
                .glassEffect(glassConfiguration, in: shape)
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(ControlGlassStyle.darkBase)
                    shape.fill(resolvedTint)
                }
                .clipShape(shape)
        }
    }

    @available(macOS 26.0, *)
    private var glassConfiguration: Glass {
        var glass: Glass = clear ? .clear : .regular
        glass = glass.tint(resolvedTint)
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

// MARK: - MenuBarExtra host window

/// Dark fill matching the prayer card — used only on the `NSWindow`, never on
/// SwiftUI hosting views (painting those hides all content).
enum MenuBarHostStyle {
    static let cardFill = NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
}

/// Configures the MenuBarExtra `NSWindow` only: dark fill, no light border plate.
/// Does not paint SwiftUI hosting layers (that hides content).
struct TransparentMenuBarWindow: NSViewRepresentable {
    var cornerRadius: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        MenuBarHostView(cornerRadius: cornerRadius)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MenuBarHostView else { return }
        view.cornerRadius = cornerRadius
        view.applyHostStyle()
    }
}

private final class MenuBarHostView: NSView {
    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyHostStyle()
    }

    override func layout() {
        super.layout()
        applyHostStyle()
    }

    func applyHostStyle() {
        guard let window else { return }

        // Match the card — no white window chrome or hairline border.
        window.isOpaque = true
        window.backgroundColor = MenuBarHostStyle.cardFill
        window.hasShadow = true

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = MenuBarHostStyle.cardFill.cgColor
            contentView.layer?.cornerRadius = cornerRadius
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
            contentView.layer?.borderWidth = 0
            contentView.layer?.borderColor = NSColor.clear.cgColor

            stripBorders(in: contentView)
        }
    }

    private func stripBorders(in root: NSView) {
        root.layer?.borderWidth = 0
        root.layer?.borderColor = NSColor.clear.cgColor

        for subview in root.subviews {
            let name = NSStringFromClass(type(of: subview))
            if name.contains("NSHosting") || name.contains("HostingView") {
                subview.layer?.borderWidth = 0
                continue
            }
            stripBorders(in: subview)
        }
    }
}
