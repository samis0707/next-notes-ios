// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// Continues markdown lists (bullets, ordered numbers, checkboxes) when the
/// user presses Return.
///
/// This is the cleaned-up version of the regex logic that used to live in
/// ``EditorViewController.textView(_:shouldChangeTextIn:replacementText:)``.
/// The legacy implementation interleaved the matching with debug `print`
/// statements and four near-duplicate branches — the new one is the same
/// functionality but split into pure helpers and free of side effects beyond
/// the text view mutation.
///
enum MarkdownListContinuation {
    ///
    /// Inspect the text view's pending edit and, if appropriate, mutate the
    /// text view directly to extend the surrounding list. Returns `true` when
    /// the caller should let the regular text input proceed, `false` when the
    /// continuation already applied the edit.
    ///
    /// Intentionally bails out for empty input and non-newline replacements so
    /// other text view delegate logic remains in charge of the normal path.
    ///
    static func handle(
        textView: UITextView,
        range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard text == "\n" else {
            return true
        }

        let fullText = textView.text as NSString
        let precedingText = fullText.substring(to: range.upperBound)
        let precedingLines = precedingText.components(separatedBy: .newlines)

        guard let precedingLine = precedingLines.last else {
            return true
        }

        let precedingLineRange = NSRange(location: 0, length: (precedingLine as NSString).length)

        if continueCheckbox(
            textView: textView,
            fullText: fullText,
            range: range,
            precedingLine: precedingLine,
            precedingLineRange: precedingLineRange,
            text: text
        ) {
            return false
        }

        if continueUnorderedBullet(
            textView: textView,
            fullText: fullText,
            range: range,
            precedingLine: precedingLine,
            precedingLineRange: precedingLineRange,
            text: text
        ) {
            return false
        }

        if continueOrderedItem(
            textView: textView,
            fullText: fullText,
            range: range,
            precedingLine: precedingLine,
            precedingLineRange: precedingLineRange,
            text: text
        ) {
            return false
        }

        if removeEmptyListItem(
            textView: textView,
            fullText: fullText,
            precedingText: precedingText,
            precedingLine: precedingLine,
            precedingLineRange: precedingLineRange
        ) {
            return false
        }

        return true
    }

    // MARK: - Checkbox

    private static func continueCheckbox(
        textView: UITextView,
        fullText: NSString,
        range: NSRange,
        precedingLine: String,
        precedingLineRange: NSRange,
        text: String
    ) -> Bool {
        let precedingLineNS = precedingLine as NSString

        if let match = regex(Element.checkBoxUnchecked)?.firstMatch(in: precedingLine, options: [], range: precedingLineRange) {
            let prefix = precedingLineNS.substring(with: match.range(at: 0))
            apply(textView: textView, fullText: fullText, range: range, with: "\(text)\(prefix) ")
            return true
        }

        if let match = regex(Element.checkBoxChecked)?.firstMatch(in: precedingLine, options: [], range: precedingLineRange) {
            let prefix = precedingLineNS
                .substring(with: match.range(at: 0))
                .replacingOccurrences(of: "X", with: " ")
                .replacingOccurrences(of: "x", with: " ")
            apply(textView: textView, fullText: fullText, range: range, with: "\(text)\(prefix) ")
            return true
        }

        return false
    }

    // MARK: - Unordered

    private static func continueUnorderedBullet(
        textView: UITextView,
        fullText: NSString,
        range: NSRange,
        precedingLine: String,
        precedingLineRange: NSRange,
        text: String
    ) -> Bool {
        guard let match = regex(Element.listItemUnordered)?.firstMatch(in: precedingLine, options: [], range: precedingLineRange) else {
            return false
        }

        let fullMatchRange = match.range(at: 0)
        let contentRange = match.range(at: 3)
        let bulletRange = NSRange(
            location: fullMatchRange.location,
            length: fullMatchRange.length - contentRange.length - 1
        )
        let bullet = (precedingLine as NSString).substring(with: bulletRange)
        apply(textView: textView, fullText: fullText, range: range, with: "\(text)\(bullet) ")
        return true
    }

    // MARK: - Ordered

    private static func continueOrderedItem(
        textView: UITextView,
        fullText: NSString,
        range: NSRange,
        precedingLine: String,
        precedingLineRange: NSRange,
        text: String
    ) -> Bool {
        guard let regex = regex(Element.listItemOrdered),
              let match = regex.firstMatch(in: precedingLine, options: [], range: precedingLineRange) else {
            return false
        }

        let digitMatchRange = match.range(at: 2)
        guard digitMatchRange.location != NSNotFound,
              let dotIndex = precedingLine.firstIndex(of: ".") else {
            return false
        }

        let digitStart = precedingLine.index(precedingLine.startIndex, offsetBy: digitMatchRange.location)
        let digitString = String(precedingLine[digitStart..<dotIndex])

        guard let currentNumber = Int(digitString) else {
            return false
        }

        let indent = String(precedingLine[precedingLine.startIndex..<digitStart])
        let nextLine = "\(text)\(indent)\(currentNumber + 1). "
        let newFullText = fullText.replacingCharacters(in: range, with: nextLine)

        textView.text = newFullText
        textView.selectedRange = NSRange(location: range.location + (nextLine as NSString).length, length: 0)
        return true
    }

    // MARK: - Empty list item removal

    private static func removeEmptyListItem(
        textView: UITextView,
        fullText: NSString,
        precedingText: String,
        precedingLine: String,
        precedingLineRange: NSRange
    ) -> Bool {
        let emptyPattern = "^((\\d+\\.)|[-+*])\\s+(\\[ ?\\]\\s*)?$"
        guard let regex = try? NSRegularExpression(pattern: emptyPattern, options: [.anchorsMatchLines]),
              regex.firstMatch(in: precedingLine, options: [], range: precedingLineRange) != nil else {
            return false
        }

        let updatingRange = (precedingText as NSString).range(of: precedingLine, options: .backwards)
        guard updatingRange.location != NSNotFound else {
            return false
        }

        let newFullText = fullText.replacingCharacters(in: updatingRange, with: "")
        textView.text = newFullText
        textView.selectedRange = NSRange(location: updatingRange.location, length: 0)
        return true
    }

    // MARK: - Helpers

    private static func regex(_ element: Element) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: element.rawValue, options: .anchorsMatchLines)
    }

    private static func apply(textView: UITextView, fullText: NSString, range: NSRange, with replacement: String) {
        let newFullText = fullText.replacingCharacters(in: range, with: replacement)
        textView.text = newFullText
        textView.selectedRange = NSRange(
            location: range.location + (replacement as NSString).length,
            length: 0
        )
    }
}
