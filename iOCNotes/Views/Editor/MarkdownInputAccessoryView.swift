// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// Markdown formatting actions a user can trigger from the keyboard accessory.
///
enum MarkdownAction: Hashable {
    case bold
    case italic
    case heading
    case bulletList
    case checkbox
    case link
    case inlineCode
    case undo
    case redo
    case dismissKeyboard
}

///
/// `UIToolbar` shown above the keyboard while editing a note.
///
/// Attached to the ``MarkdownTextView`` via `inputAccessoryView` so iOS handles
/// show / hide automatically with the keyboard. This avoids the SwiftUI focus
/// dance that caused the keyboard to disappear after every keystroke in an
/// earlier iteration.
///
final class MarkdownInputAccessoryView: UIInputView {
    private let toolbar = UIToolbar()
    private weak var undoItem: UIBarButtonItem?
    private weak var redoItem: UIBarButtonItem?

    let onAction: (MarkdownAction) -> Void

    init(onAction: @escaping (MarkdownAction) -> Void) {
        self.onAction = onAction
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 44), inputViewStyle: .keyboard)
        allowsSelfSizing = true

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        configureItems()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownInputAccessoryView")
    }

    func update(canUndo: Bool, canRedo: Bool) {
        undoItem?.isEnabled = canUndo
        redoItem?.isEnabled = canRedo
    }

    // MARK: - Setup

    private func configureItems() {
        let flexible = UIBarButtonItem.flexibleSpace()
        let fixed: () -> UIBarButtonItem = {
            let item = UIBarButtonItem.fixedSpace(2)
            return item
        }

        let heading = item(systemName: "textformat.size", action: .heading, label: "Heading")
        let bold = item(systemName: "bold", action: .bold, label: "Bold")
        let italic = item(systemName: "italic", action: .italic, label: "Italic")
        let bullet = item(systemName: "list.bullet", action: .bulletList, label: "Bullet list")
        let checkbox = item(systemName: "checklist", action: .checkbox, label: "Checkbox")
        let link = item(systemName: "link", action: .link, label: "Link")
        let code = item(systemName: "chevron.left.forwardslash.chevron.right", action: .inlineCode, label: "Inline code")

        let undo = item(systemName: "arrow.uturn.backward", action: .undo, label: "Undo")
        undo.isEnabled = false
        undoItem = undo

        let redo = item(systemName: "arrow.uturn.forward", action: .redo, label: "Redo")
        redo.isEnabled = false
        redoItem = redo

        let dismiss = item(systemName: "keyboard.chevron.compact.down", action: .dismissKeyboard, label: "Hide keyboard")

        toolbar.items = [
            heading, fixed(),
            bold, fixed(),
            italic, fixed(),
            bullet, fixed(),
            checkbox, fixed(),
            link, fixed(),
            code,
            flexible,
            undo, fixed(),
            redo, fixed(),
            dismiss
        ]
    }

    private func item(systemName: String, action: MarkdownAction, label: String) -> UIBarButtonItem {
        let image = UIImage(systemName: systemName)
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleTap(_:)))
        item.accessibilityLabel = NSLocalizedString(label, comment: "Markdown toolbar action label")
        item.tag = action.tag
        return item
    }

    @objc private func handleTap(_ sender: UIBarButtonItem) {
        guard let action = MarkdownAction(tag: sender.tag) else {
            return
        }
        onAction(action)
    }
}

// MARK: - Tag encoding

private extension MarkdownAction {
    var tag: Int {
        switch self {
        case .bold: return 1
        case .italic: return 2
        case .heading: return 3
        case .bulletList: return 4
        case .checkbox: return 5
        case .link: return 6
        case .inlineCode: return 7
        case .undo: return 8
        case .redo: return 9
        case .dismissKeyboard: return 10
        }
    }

    init?(tag: Int) {
        switch tag {
        case 1: self = .bold
        case 2: self = .italic
        case 3: self = .heading
        case 4: self = .bulletList
        case 5: self = .checkbox
        case 6: self = .link
        case 7: self = .inlineCode
        case 8: self = .undo
        case 9: self = .redo
        case 10: self = .dismissKeyboard
        default: return nil
        }
    }
}
