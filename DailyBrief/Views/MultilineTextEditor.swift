import AppKit
import SwiftUI

struct MultilineTextEditor: NSViewRepresentable {
    enum TabDirection {
        case forward
        case backward
    }

    @Binding var text: String
    var isFocused: Bool
    var onFocus: () -> Void
    var onTab: (TabDirection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = TabNavigatingTextView()
        textView.delegate = context.coordinator
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.textContainerInset = NSSize(width: 4, height: 7)
        textView.textContainer?.lineFragmentPadding = 0
        textView.onFocus = onFocus
        textView.onTab = onTab

        let scrollView = ActiveScrollOnlyScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .automatic
        scrollView.hideScrollerImmediately()

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TabNavigatingTextView else {
            return
        }

        context.coordinator.parent = self
        textView.onFocus = onFocus
        textView.onTab = onTab

        if textView.string != text {
            textView.string = text
        }

        if isFocused, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextEditor

        init(parent: MultilineTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                parent.onTab(.forward)
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                parent.onTab(.backward)
                return true
            default:
                return false
            }
        }
    }
}

private final class TabNavigatingTextView: NSTextView {
    var onFocus: (() -> Void)?
    var onTab: ((MultilineTextEditor.TabDirection) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        if becameFirstResponder {
            onFocus?()
        }
        return becameFirstResponder
    }

    override func insertTab(_ sender: Any?) {
        onTab?(.forward)
    }

    override func insertBacktab(_ sender: Any?) {
        onTab?(.backward)
    }
}

private final class ActiveScrollOnlyScrollView: NSScrollView {
    private var hideScrollerWorkItem: DispatchWorkItem?

    override var hasVerticalScroller: Bool {
        didSet {
            hideScrollerImmediately()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        showScrollerWhileScrolling()
        super.scrollWheel(with: event)
        scheduleScrollerHide()
    }

    func hideScrollerImmediately() {
        hideScrollerWorkItem?.cancel()
        verticalScroller?.alphaValue = 0
    }

    private func showScrollerWhileScrolling() {
        hideScrollerWorkItem?.cancel()
        verticalScroller?.animator().alphaValue = 1
    }

    private func scheduleScrollerHide() {
        let workItem = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                self?.verticalScroller?.animator().alphaValue = 0
            }
        }

        hideScrollerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }
}
