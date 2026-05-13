// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// Cleaned-up text view used by the new SwiftUI ``NoteEditorScreen``.
///
/// Reuses the mature ``MarkdownTextStorage`` and ``CheckBoxTapHandler`` engines
/// but drops the floating `headerLabel`, the iPad-only inset gymnastics and the
/// manual keyboard handling that lived in the legacy ``HeaderTextView``.
///
/// The markdown formatting toolbar is attached as `inputAccessoryView`, the
/// canonical iOS pattern: iOS handles showing / hiding it with the keyboard
/// automatically and the SwiftUI side does not need to track focus.
///
final class MarkdownTextView: UITextView {
    private let markdownStorage = MarkdownTextStorage()
    private let tapHandler = CheckBoxTapHandler()
    private let accessoryView: MarkdownInputAccessoryView

    init() {
        let layoutManager = LayoutManager()
        layoutManager.delegate = layoutManager

        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        markdownStorage.addLayoutManager(layoutManager)

        // Accessory view needs `self` to be available - we install it after `super.init`.
        var captured: ((MarkdownAction) -> Void)?
        self.accessoryView = MarkdownInputAccessoryView { action in
            captured?(action)
        }

        super.init(frame: .zero, textContainer: container)

        captured = { [weak self] action in
            guard let self else { return }
            MarkdownTextOperator.apply(action, on: self)
            self.refreshUndoButtons()
        }

        inputAccessoryView = accessoryView

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
        // Activate the iOS-native Find / Replace bar (iOS 16+). The system
        // presents its own search UI above the keyboard; the SwiftUI side
        // only needs to call `presentFindNavigator(...)` when the user picks
        // "Find in Note" from the action menu.
        isFindInteractionEnabled = true

        tapHandler.textView = self
        tapHandler.layoutManager = layoutManager
        addGestureRecognizer(tapHandler.tapGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownTextView")
    }

    ///
    /// Replace the entire text. Drops the undo stack to match the previous
    /// editor's behaviour when switching notes.
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
        refreshUndoButtons()
    }

    ///
    /// Refresh the undo / redo button states in the accessory toolbar. Call
    /// from the delegate after each text mutation.
    ///
    func refreshUndoButtons() {
        accessoryView.update(
            canUndo: undoManager?.canUndo ?? false,
            canRedo: undoManager?.canRedo ?? false
        )
    }
}
