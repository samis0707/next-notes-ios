// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

///
/// SwiftUI wrapper around ``MarkdownTextView``.
///
/// Exposes the markdown text via a two-way binding, forwards undo / redo state
/// changes so the toolbar can disable buttons appropriately, and offers a
/// handle that lets ancestor SwiftUI views push edit actions (toolbar taps,
/// programmatic insertions) into the underlying `UITextView`.
///
struct MarkdownTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    let isFocused: Bool
    let handle: MarkdownTextViewHandle
    let onTextChange: () -> Void

    func makeUIView(context: Context) -> MarkdownTextView {
        let view = MarkdownTextView()
        view.delegate = context.coordinator
        view.setMarkdownText(text)
        handle.bind(view: view)
        Task { @MainActor in
            context.coordinator.refreshUndoState()
        }
        return view
    }

    func updateUIView(_ uiView: MarkdownTextView, context: Context) {
        // SwiftUI hands us a fresh `Representable` struct on every update —
        // make sure the coordinator's closures and bindings are not stale.
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.setMarkdownText(text)
        }

        // Keep first-responder state in sync with SwiftUI's focus model.
        if isFocused, uiView.window != nil, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextViewRepresentable
        weak var textView: MarkdownTextView?

        init(parent: MarkdownTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView as? MarkdownTextView
            parent.text = textView.text
            parent.onTextChange()
            refreshUndoState()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView as? MarkdownTextView
            refreshUndoState()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            self.textView = textView as? MarkdownTextView
            return MarkdownListContinuation.handle(textView: textView, range: range, replacementText: text)
        }

        func refreshUndoState() {
            guard let manager = (textView ?? parent.handle.view)?.undoManager else {
                return
            }
            let canUndo = manager.canUndo
            let canRedo = manager.canRedo
            if parent.canUndo != canUndo {
                parent.canUndo = canUndo
            }
            if parent.canRedo != canRedo {
                parent.canRedo = canRedo
            }
        }
    }
}

///
/// Bridge object that lets ancestor SwiftUI views send commands directly to
/// the underlying ``MarkdownTextView`` (e.g. apply toolbar formatting). The
/// reference is held weakly so the text view's lifecycle is unaffected.
///
final class MarkdownTextViewHandle {
    private(set) weak var view: MarkdownTextView?

    @MainActor
    func bind(view: MarkdownTextView) {
        self.view = view
    }

    @MainActor
    func apply(_ action: MarkdownAction) {
        guard let view else {
            return
        }
        if !view.isFirstResponder {
            view.becomeFirstResponder()
        }
        MarkdownTextOperator.apply(action, on: view)
    }
}
