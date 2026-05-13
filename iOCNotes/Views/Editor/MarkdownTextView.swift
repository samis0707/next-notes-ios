// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// Cleaned-up text view used by the new SwiftUI ``NoteEditorScreen``.
///
/// Reuses the mature ``MarkdownTextStorage`` and ``CheckBoxTapHandler`` engines
/// but drops the floating `headerLabel`, the iPad-only inset gymnastics and the
/// manual keyboard handling that lived in the legacy ``HeaderTextView``. The
/// SwiftUI side controls the layout via `keyboardLayoutGuide` instead.
///
final class MarkdownTextView: UITextView {
    private let markdownStorage = MarkdownTextStorage()
    private let tapHandler = CheckBoxTapHandler()

    init() {
        let layoutManager = LayoutManager()
        layoutManager.delegate = layoutManager

        let container = NSTextContainer(size: CGSize(width: 0, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        markdownStorage.addLayoutManager(layoutManager)

        super.init(frame: .zero, textContainer: container)

        // Native keyboard, accessory bar handled by the view controller / SwiftUI side.
        autocorrectionType = .default
        autocapitalizationType = .sentences
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        keyboardDismissMode = .interactive
        alwaysBounceVertical = true
        textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 24, right: 12)
        backgroundColor = .systemBackground
        tintColor = .tintColor
        font = .preferredFont(forTextStyle: .body)
        adjustsFontForContentSizeCategory = true
        translatesAutoresizingMaskIntoConstraints = false

        // Tappable checkboxes — same UX as the legacy editor.
        tapHandler.textView = self
        tapHandler.layoutManager = layoutManager
        addGestureRecognizer(tapHandler.tapGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownTextView")
    }

    ///
    /// Replace the entire text without disturbing the undo manager beyond the
    /// implicit reset (we drop history on note switch).
    ///
    func setMarkdownText(_ string: String) {
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        )
        markdownStorage.beginEditing()
        markdownStorage.setAttributedString(attributed)
        markdownStorage.endEditing()
        undoManager?.removeAllActions()
    }
}
