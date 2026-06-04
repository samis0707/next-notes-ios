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
    case strikethrough
    case heading1
    case heading2
    case heading3
    case bulletList
    case numberedList
    case checkbox
    case blockquote
    case link
    case inlineCode
    case codeBlock
    case undo
    case redo
    case dismissKeyboard
}

///
/// Bar shown above the keyboard while editing a note.
///
/// Modelled on the iOS 26 Apple Notes formatting bar: a single floating,
/// capsule-rounded glass pill whose contents *scroll horizontally* so every
/// formatting action is reachable with a swipe instead of being hidden behind
/// an overflow menu.
///
/// Design notes:
///
/// * The actions live on a *single* glass/material surface (Liquid Glass on
///   iOS 26) shaped as a floating pill — the "Tahoe" look. We deliberately
///   avoid `UIToolbar` / `UIBarButtonItem`: on iOS 26 those render every item
///   in its own floating glass capsule, which reads as a row of separate
///   buttons rather than one bar. Plain `UIButton`s inside a `UIScrollView` on
///   a shared rounded `UIVisualEffectView` give us the scrolling pill.
/// * The keyboard-dismiss button is pinned at the trailing edge, outside the
///   scroll area, so it is always reachable without scrolling.
/// * SF Symbols use `semibold` weight to match the bolder glass button styling
///   used elsewhere in the app.
/// * The heading button presents H1 / H2 / H3 as a popover menu.
///
final class MarkdownInputAccessoryView: UIInputView {

    // Layout constants.
    private let barHeight: CGFloat = 44
    private let topGap: CGFloat = 6
    private let bottomGap: CGFloat = 10
    private let sideInset: CGFloat = 10
    private let horizontalInset: CGFloat = 14
    private let itemSpacing: CGFloat = 16

    // Buttons whose enabled state we refresh after text mutations.
    private var undoButton: UIButton!
    private var redoButton: UIButton!

    private var canUndo = false
    private var canRedo = false

    let onAction: (MarkdownAction) -> Void

    init(onAction: @escaping (MarkdownAction) -> Void) {
        self.onAction = onAction
        super.init(
            frame: CGRect(x: 0, y: 0, width: 320, height: 6 + 44 + 10),
            inputViewStyle: .default
        )
        allowsSelfSizing = true
        // Transparent surround so the capsule reads as a floating pill rather
        // than a bar sitting on a keyboard-coloured strip.
        backgroundColor = .clear
        configureBar()
        refreshUndoRedoState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for MarkdownInputAccessoryView")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: topGap + barHeight + bottomGap)
    }

    func update(canUndo: Bool, canRedo: Bool) {
        guard self.canUndo != canUndo || self.canRedo != canRedo else {
            return
        }
        self.canUndo = canUndo
        self.canRedo = canRedo
        refreshUndoRedoState()
    }

    // MARK: - Bar construction

    private func configureBar() {
        let bar = makeBarSurface()
        bar.translatesAutoresizingMaskIntoConstraints = false
        // Shape the glass surface as a capsule pill so it floats above the
        // keyboard rather than spanning the full width as a flush bar.
        bar.layer.cornerRadius = barHeight / 2
        bar.layer.cornerCurve = .continuous
        bar.clipsToBounds = true
        addSubview(bar)

        let undo = actionButton(systemName: "arrow.uturn.backward", action: .undo, label: "Undo")
        let redo = actionButton(systemName: "arrow.uturn.forward", action: .redo, label: "Redo")
        self.undoButton = undo
        self.redoButton = redo

        // The full, scrollable list of formatting actions, in logical groups:
        // structure, inline emphasis, code, lists, quote, link, history.
        let buttons: [UIButton] = [
            menuButton(systemName: "textformat.size", accessibilityLabel: "Heading", menu: headingMenu()),
            actionButton(systemName: "bold", action: .bold, label: "Bold"),
            actionButton(systemName: "italic", action: .italic, label: "Italic"),
            actionButton(systemName: "strikethrough", action: .strikethrough, label: "Strikethrough"),
            actionButton(systemName: "list.bullet", action: .bulletList, label: "Bullet list"),
            actionButton(systemName: "list.number", action: .numberedList, label: "Numbered list"),
            actionButton(systemName: "checklist", action: .checkbox, label: "Checkbox"),
            actionButton(systemName: "text.quote", action: .blockquote, label: "Quote"),
            actionButton(systemName: "link", action: .link, label: "Link"),
            actionButton(systemName: "chevron.left.forwardslash.chevron.right", action: .inlineCode, label: "Inline code"),
            actionButton(systemName: "curlybraces", action: .codeBlock, label: "Code block"),
            undo,
            redo
        ]

        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = itemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // Pinned dismiss button — always reachable, never scrolls away.
        let dismiss = actionButton(systemName: "keyboard.chevron.compact.down", action: .dismissKeyboard, label: "Hide keyboard")

        bar.contentView.addSubview(scroll)
        bar.contentView.addSubview(dismiss)

        let content = bar.contentView
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sideInset),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sideInset),
            bar.topAnchor.constraint(equalTo: topAnchor, constant: topGap),
            bar.heightAnchor.constraint(equalToConstant: barHeight),

            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: horizontalInset),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: dismiss.leadingAnchor, constant: -itemSpacing),

            dismiss.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -horizontalInset),
            dismiss.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            // The stack defines the scroll view's content size; pin to the
            // content layout guide and match the visible height so buttons
            // fill the bar vertically (giving 44pt tap targets).
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
    }

    ///
    /// A single bar surface: real Liquid Glass on iOS 26, a system-material
    /// blur on iOS 17–25 where `UIGlassEffect` does not exist.
    ///
    private func makeBarSurface() -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            return UIVisualEffectView(effect: UIGlassEffect())
        } else {
            return UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
    }

    // MARK: - Buttons

    private func actionButton(systemName: String, action: MarkdownAction, label: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(symbolImage(named: systemName), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = NSLocalizedString(label, comment: "Markdown toolbar action label")
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addAction(UIAction { [weak self] _ in
            self?.onAction(action)
        }, for: .touchUpInside)
        return button
    }

    ///
    /// A `UIButton` whose menu pops up as a popover anchored to the button.
    ///
    private func menuButton(systemName: String, accessibilityLabel: String, menu: UIMenu) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(symbolImage(named: systemName), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = NSLocalizedString(accessibilityLabel, comment: "Markdown toolbar action label")
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func symbolImage(named name: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: configuration)
    }

    private func refreshUndoRedoState() {
        undoButton?.isEnabled = canUndo
        redoButton?.isEnabled = canRedo
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
}
