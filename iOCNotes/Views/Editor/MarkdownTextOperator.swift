// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// Applies ``MarkdownAction`` events to a `UITextView` by inserting or wrapping
/// markdown syntax around the user's current selection.
///
/// The legacy editor offered no equivalent — users had to type every asterisk
/// and pound sign manually. This is the bulk of the Phase 2 quality-of-life
/// improvement for thumbs.
///
enum MarkdownTextOperator {
    static func apply(_ action: MarkdownAction, on textView: UITextView) {
        switch action {
        case .bold: wrap(textView, with: "**", placeholder: "bold")
        case .italic: wrap(textView, with: "*", placeholder: "italic")
        case .heading: toggleLinePrefix(textView, prefix: "# ")
        case .bulletList: toggleLinePrefix(textView, prefix: "- ")
        case .checkbox: toggleLinePrefix(textView, prefix: "- [ ] ")
        case .link: insertLink(textView)
        case .inlineCode: wrap(textView, with: "`", placeholder: "code")
        case .undo: textView.undoManager?.undo()
        case .redo: textView.undoManager?.redo()
        case .dismissKeyboard: textView.resignFirstResponder()
        }
    }

    // MARK: - Wrap

    private static func wrap(_ textView: UITextView, with token: String, placeholder: String) {
        let selectedRange = textView.selectedRange
        let nsText = textView.text as NSString

        let selectedText = nsText.substring(with: selectedRange)
        let inner = selectedText.isEmpty ? placeholder : selectedText
        let wrapped = "\(token)\(inner)\(token)"

        textView.replaceText(in: selectedRange, with: wrapped)

        let tokenLength = (token as NSString).length
        let innerLength = (inner as NSString).length
        if selectedText.isEmpty {
            // Place caret inside the tokens and select the placeholder so the
            // user can overtype it directly.
            textView.selectedRange = NSRange(location: selectedRange.location + tokenLength, length: innerLength)
        } else {
            textView.selectedRange = NSRange(location: selectedRange.location + tokenLength + innerLength + tokenLength, length: 0)
        }
    }

    // MARK: - Line prefix

    private static func toggleLinePrefix(_ textView: UITextView, prefix: String) {
        let nsText = textView.text as NSString
        let selection = textView.selectedRange
        let lineRange = nsText.lineRange(for: selection)
        let line = nsText.substring(with: lineRange)
        let trimmedLine = line.hasSuffix("\n") ? String(line.dropLast()) : line

        let newLine: String
        let delta: Int
        if trimmedLine.hasPrefix(prefix) {
            newLine = String(trimmedLine.dropFirst(prefix.count))
            delta = -(prefix as NSString).length
        } else {
            newLine = prefix + trimmedLine
            delta = (prefix as NSString).length
        }

        let replacement = line.hasSuffix("\n") ? newLine + "\n" : newLine
        textView.replaceText(in: lineRange, with: replacement)
        textView.selectedRange = NSRange(
            location: max(lineRange.location, selection.location + delta),
            length: selection.length
        )
    }

    // MARK: - Link

    private static func insertLink(_ textView: UITextView) {
        let selectedRange = textView.selectedRange
        let nsText = textView.text as NSString
        let selectedText = nsText.substring(with: selectedRange)

        let title = selectedText.isEmpty ? "title" : selectedText
        let snippet = "[\(title)](url)"

        textView.replaceText(in: selectedRange, with: snippet)

        // Select "url" so the user can paste / type the link target.
        let urlStart = selectedRange.location + (title as NSString).length + 3 // "[" + title + "]("
        textView.selectedRange = NSRange(location: urlStart, length: 3)
    }
}

// MARK: - UITextView convenience

private extension UITextView {
    ///
    /// Replace characters in the receiver while preserving the undo manager.
    ///
    /// Direct mutation of `text` blows away the undo stack on UIKit, so we
    /// route through the input system which records the change.
    ///
    func replaceText(in range: NSRange, with replacement: String) {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else {
            return
        }
        replace(textRange, withText: replacement)
    }
}
