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
/// trailing overflow menu rendered as a popover.
///
/// Design notes:
///
/// * The input view is taller than the toolbar so there is a visible gap
///   between the buttons and the keyboard keys below.
/// * SF Symbols use `regular` weight — the default in a toolbar context is
///   semibold which the iOS 26 look made appear "bold".
/// * Menu items (heading, overflow) are backed by `UIButton` with
///   `showsMenuAsPrimaryAction = true` so the menu appears as a popover from
///   the button instead of replacing the toolbar inline.
///
final class MarkdownInputAccessoryView: UIInputView {

    // Layout constants.
    private let toolbarHeight: CGFloat = 44
    private let bottomGap: CGFloat = 10
    private let horizontalInset: CGFloat = 6

    private let toolbar = UIToolbar()

    // Buttons whose state we may want to refresh after construction.
    private var headingButton: UIButton!
    private var overflowButton: UIButton!

    // Overflow actions whose enabled state we reflect in the menu.
    private var canUndo = false
    private var canRedo = false

    let onAction: (MarkdownAction) -> Void

    init(onAction: @escaping (MarkdownAction) -> Void) {
        self.onAction = onAction
        super.init(
            frame: CGRect(x: 0, y: 0, width: 320, height: 44 + 10),
            inputViewStyle: .keyboard
        )
        allowsSelfSizing = true

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.isTranslucent = true
        addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight)
        ])

        configureItems()
        refreshOverflowMenu()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownInputAccessoryView")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: toolbarHeight + bottomGap)
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
        let headingBtn = menuButton(systemName: "textformat.size", accessibilityLabel: "Heading", menu: headingMenu())
        self.headingButton = headingBtn
        let heading = UIBarButtonItem(customView: headingBtn)

        let bold = item(systemName: "bold", action: .bold, label: "Bold")
        let italic = item(systemName: "italic", action: .italic, label: "Italic")
        let bullet = item(systemName: "list.bullet", action: .bulletList, label: "Bullet list")
        let checkbox = item(systemName: "checklist", action: .checkbox, label: "Checkbox")

        let overflowBtn = menuButton(systemName: "ellipsis.circle", accessibilityLabel: "More", menu: UIMenu())
        self.overflowButton = overflowBtn
        let overflow = UIBarButtonItem(customView: overflowBtn)

        let spacing: CGFloat = 8
        toolbar.items = [
            .fixedSpace(horizontalInset),
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
            overflow,
            .fixedSpace(horizontalInset)
        ]
    }

    // MARK: - Buttons

    private func item(systemName: String, action: MarkdownAction, label: String) -> UIBarButtonItem {
        let image = symbolImage(named: systemName)
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

    ///
    /// Backed by a `UIButton` so the menu pops up as a popover anchored to the
    /// button rather than expanding inline and hiding the rest of the toolbar.
    ///
    private func menuButton(systemName: String, accessibilityLabel: String, menu: UIMenu) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(symbolImage(named: systemName), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = NSLocalizedString(accessibilityLabel, comment: "Markdown toolbar action label")
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        return button
    }

    private func symbolImage(named name: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        return UIImage(systemName: name, withConfiguration: configuration)
    }

    // MARK: - Heading menu

    private func headingMenu() -> UIMenu {
        UIMenu(title: NSLocalizedString("Heading", comment: "Markdown toolbar action label"), children: [
            headingItem(level: 1),
            headingItem(level: 2),
            headingItem(level: 3)
        ])
    }

    private func headingItem(level: Int) -> UIAction {
        let action: MarkdownAction
        let title: String
        let image: String
        switch level {
        case 1:
            action = .heading1
            title = NSLocalizedString("Heading 1", comment: "Heading level menu item")
            image = "1.square"
        case 2:
            action = .heading2
            title = NSLocalizedString("Heading 2", comment: "Heading level menu item")
            image = "2.square"
        default:
            action = .heading3
            title = NSLocalizedString("Heading 3", comment: "Heading level menu item")
            image = "3.square"
        }
        return UIAction(title: title, image: UIImage(systemName: image)) { [weak self] _ in
            self?.onAction(action)
        }
    }

    // MARK: - Overflow menu

    private func refreshOverflowMenu() {
        let menu = UIMenu(title: "", children: [
            menuAction(title: "Link", systemImage: "link", action: .link),
            menuAction(title: "Inline code", systemImage: "chevron.left.forwardslash.chevron.right", action: .inlineCode),
            menuAction(title: "Undo", systemImage: "arrow.uturn.backward", action: .undo, enabled: canUndo),
            menuAction(title: "Redo", systemImage: "arrow.uturn.forward", action: .redo, enabled: canRedo),
            menuAction(title: "Hide keyboard", systemImage: "keyboard.chevron.compact.down", action: .dismissKeyboard)
        ])
        overflowButton?.menu = menu
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
