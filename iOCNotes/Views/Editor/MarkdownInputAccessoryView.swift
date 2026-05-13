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
    case heading1
    case heading2
    case heading3
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
/// Five primary formatting buttons stay visible on every iPhone width (down to
/// iPhone SE / 4-inch screens). The less frequently used actions live in a
/// trailing overflow menu so the bar never spills off-screen. Attached to the
/// ``MarkdownTextView`` via `inputAccessoryView` so iOS handles show / hide
/// automatically with the keyboard.
///
final class MarkdownInputAccessoryView: UIInputView {
    private let toolbar = UIToolbar()
    private let overflowItem = UIBarButtonItem()

    // Overflow actions whose enabled state we want to reflect in the menu.
    private var canUndo = false
    private var canRedo = false

    let onAction: (MarkdownAction) -> Void

    init(onAction: @escaping (MarkdownAction) -> Void) {
        self.onAction = onAction
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 48), inputViewStyle: .keyboard)
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
        refreshOverflowMenu()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownInputAccessoryView")
    }

    func update(canUndo: Bool, canRedo: Bool) {
        guard self.canUndo != canUndo || self.canRedo != canRedo else {
            return
        }
        self.canUndo = canUndo
        self.canRedo = canRedo
        refreshOverflowMenu()
    }

    // MARK: - Primary toolbar

    private func configureItems() {
        // Heading button opens a sub-menu for H1 / H2 / H3 — picking a fixed
        // size on tap would force the user to remember which level the icon
        // maps to. A menu is more discoverable on iPhone.
        let heading = UIBarButtonItem(
            image: UIImage(systemName: "textformat.size"),
            menu: headingMenu()
        )
        heading.accessibilityLabel = NSLocalizedString("Heading", comment: "Markdown toolbar action label")

        let bold = item(systemName: "bold", action: .bold, label: "Bold")
        let italic = item(systemName: "italic", action: .italic, label: "Italic")
        let bullet = item(systemName: "list.bullet", action: .bulletList, label: "Bullet list")
        let checkbox = item(systemName: "checklist", action: .checkbox, label: "Checkbox")

        overflowItem.image = UIImage(systemName: "ellipsis.circle")
        overflowItem.accessibilityLabel = NSLocalizedString("More", comment: "Overflow menu in markdown toolbar")

        let spacing: CGFloat = 8
        toolbar.items = [
            .fixedSpace(4),
            heading,
            .fixedSpace(spacing),
            bold,
            .fixedSpace(spacing),
            italic,
            .fixedSpace(spacing),
            bullet,
            .fixedSpace(spacing),
            checkbox,
            .flexibleSpace(),
            overflowItem,
            .fixedSpace(4)
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

    // MARK: - Heading menu

    private func headingMenu() -> UIMenu {
        let h1 = headingItem(level: 1, systemImage: "1.square")
        let h2 = headingItem(level: 2, systemImage: "2.square")
        let h3 = headingItem(level: 3, systemImage: "3.square")
        return UIMenu(title: "", children: [h1, h2, h3])
    }

    private func headingItem(level: Int, systemImage: String) -> UIAction {
        let action: MarkdownAction
        let title: String
        switch level {
        case 1:
            action = .heading1
            title = NSLocalizedString("Heading 1", comment: "Heading level menu item")
        case 2:
            action = .heading2
            title = NSLocalizedString("Heading 2", comment: "Heading level menu item")
        default:
            action = .heading3
            title = NSLocalizedString("Heading 3", comment: "Heading level menu item")
        }
        return UIAction(title: title, image: UIImage(systemName: systemImage)) { [weak self] _ in
            self?.onAction(action)
        }
    }

    // MARK: - Overflow menu

    private func refreshOverflowMenu() {
        let link = menuAction(
            title: "Link",
            systemImage: "link",
            action: .link
        )
        let code = menuAction(
            title: "Inline code",
            systemImage: "chevron.left.forwardslash.chevron.right",
            action: .inlineCode
        )
        let undo = menuAction(
            title: "Undo",
            systemImage: "arrow.uturn.backward",
            action: .undo,
            enabled: canUndo
        )
        let redo = menuAction(
            title: "Redo",
            systemImage: "arrow.uturn.forward",
            action: .redo,
            enabled: canRedo
        )
        let dismiss = menuAction(
            title: "Hide keyboard",
            systemImage: "keyboard.chevron.compact.down",
            action: .dismissKeyboard
        )

        overflowItem.menu = UIMenu(title: "", children: [link, code, undo, redo, dismiss])
    }

    private func menuAction(
        title: String,
        systemImage: String,
        action: MarkdownAction,
        enabled: Bool = true
    ) -> UIAction {
        let localized = NSLocalizedString(title, comment: "Markdown toolbar overflow menu item")
        return UIAction(
            title: localized,
            image: UIImage(systemName: systemImage),
            attributes: enabled ? [] : .disabled
        ) { [weak self] _ in
            self?.onAction(action)
        }
    }
}

// MARK: - Tag encoding

private extension MarkdownAction {
    var tag: Int {
        switch self {
        case .bold: return 1
        case .italic: return 2
        case .heading1: return 3
        case .heading2: return 4
        case .heading3: return 5
        case .bulletList: return 6
        case .checkbox: return 7
        case .link: return 8
        case .inlineCode: return 9
        case .undo: return 10
        case .redo: return 11
        case .dismissKeyboard: return 12
        }
    }

    init?(tag: Int) {
        switch tag {
        case 1: self = .bold
        case 2: self = .italic
        case 3: self = .heading1
        case 4: self = .heading2
        case 5: self = .heading3
        case 6: self = .bulletList
        case 7: self = .checkbox
        case 8: self = .link
        case 9: self = .inlineCode
        case 10: self = .undo
        case 11: self = .redo
        case 12: self = .dismissKeyboard
        default: return nil
        }
    }
}
