// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Inline markdown formatting actions a user can trigger.
///
/// These are translated into text mutations by ``MarkdownTextOperator``.
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
/// Markdown formatting bar shown above the keyboard.
///
/// Compact, scrollable on small devices, with SF Symbols for consistency with
/// the rest of iOS 17+. Replaces the legacy approach of swapping the
/// navigation bar's right items between editing and idle states.
///
struct MarkdownToolbar: View {
    let canUndo: Bool
    let canRedo: Bool
    let perform: (MarkdownAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    button(.heading, systemImage: "textformat.size")
                    button(.bold, systemImage: "bold")
                    button(.italic, systemImage: "italic")
                    Divider().frame(height: 20)
                    button(.bulletList, systemImage: "list.bullet")
                    button(.checkbox, systemImage: "checklist")
                    Divider().frame(height: 20)
                    button(.link, systemImage: "link")
                    button(.inlineCode, systemImage: "chevron.left.forwardslash.chevron.right")
                    Divider().frame(height: 20)
                    button(.undo, systemImage: "arrow.uturn.backward", enabled: canUndo)
                    button(.redo, systemImage: "arrow.uturn.forward", enabled: canRedo)
                }
                .padding(.horizontal, 8)
            }

            Divider().frame(height: 20)

            Button {
                perform(.dismissKeyboard)
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .imageScale(.large)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .accessibilityLabel(Text("Hide keyboard"))
        }
        .frame(height: 44)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private func button(_ action: MarkdownAction, systemImage: String, enabled: Bool = true) -> some View {
        Button {
            perform(action)
        } label: {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .frame(width: 36, height: 36)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(label(for: action)))
    }

    private func label(for action: MarkdownAction) -> String {
        switch action {
        case .bold: return String(localized: "Bold", comment: "Markdown toolbar action")
        case .italic: return String(localized: "Italic", comment: "Markdown toolbar action")
        case .heading: return String(localized: "Heading", comment: "Markdown toolbar action")
        case .bulletList: return String(localized: "Bullet list", comment: "Markdown toolbar action")
        case .checkbox: return String(localized: "Checkbox", comment: "Markdown toolbar action")
        case .link: return String(localized: "Link", comment: "Markdown toolbar action")
        case .inlineCode: return String(localized: "Inline code", comment: "Markdown toolbar action")
        case .undo: return String(localized: "Undo", comment: "Markdown toolbar action")
        case .redo: return String(localized: "Redo", comment: "Markdown toolbar action")
        case .dismissKeyboard: return String(localized: "Hide keyboard", comment: "Markdown toolbar action")
        }
    }
}
