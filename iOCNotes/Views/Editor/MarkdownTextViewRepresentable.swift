// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

///
/// SwiftUI wrapper around ``MarkdownTextView``.
///
/// Intentionally minimal: it exposes the text as a two-way binding and lets
/// the underlying `UITextView` own focus and toolbar lifetime. An earlier
/// iteration mediated SwiftUI's `@FocusState` into `becomeFirstResponder` /
/// `resignFirstResponder` calls inside `updateUIView`, which produced an
/// `AttributeGraph` cycle — every keystroke triggered a re-render, the
/// re-render saw `isFocused == false` (because SwiftUI never set it) and
/// dismissed the keyboard. Letting UIKit own focus avoids all of that.
///
struct MarkdownTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    let onTextChange: () -> Void

    func makeUIView(context: Context) -> MarkdownTextView {
        let view = MarkdownTextView()
        view.delegate = context.coordinator
        view.setMarkdownText(text)
        return view
    }

    func updateUIView(_ uiView: MarkdownTextView, context: Context) {
        context.coordinator.parent = self

        // While the user is editing, the UITextView is authoritative. SwiftUI
        // @State updates can lag a keystroke or two behind, so a naive sync
        // here would race against fast typing: SwiftUI would see a stale
        // `text` value, decide it differs from `uiView.text`, call
        // `setMarkdownText`, and snap the cursor back to position 0 — losing
        // any characters typed in between. We only sync from binding to
        // text view when the field is not the first responder, which is the
        // only case where an external value (server fetch, undo from outside)
        // should overwrite the local content.
        guard !uiView.isFirstResponder else {
            return
        }
        if uiView.text != text {
            uiView.setMarkdownText(text)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextViewRepresentable

        init(parent: MarkdownTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange()
            (textView as? MarkdownTextView)?.refreshUndoButtons()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            (textView as? MarkdownTextView)?.refreshUndoButtons()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            MarkdownListContinuation.handle(textView: textView, range: range, replacementText: text)
        }
    }
}
