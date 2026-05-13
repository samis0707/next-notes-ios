// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import SwiftUI

///
/// One row in the new SwiftUI ``NotesList``.
///
/// Renders title, a snippet of the body, the modification date and optional
/// category / favorite chips. Uses semantic colors and Dynamic Type throughout
/// instead of the legacy `.ph_*` palette overrides.
///
struct NoteRow: View {
    @ObservedObject var note: Note

    private var snippet: String {
        let body = note.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .dropFirst()
            .joined(separator: " ")
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "No additional text", comment: "Snippet placeholder for empty notes")
        }
        return trimmed
    }

    private var displayTitle: String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "New note", comment: "Fallback title for untitled notes")
        }
        return trimmed
    }

    private var modifiedDate: Date {
        Date(timeIntervalSince1970: note.modified)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.favorite {
                        Image(systemName: "star.fill")
                            .font(.footnote)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel(Text("Favorite"))
                    }

                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(modifiedDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if note.category.isEmpty == false {
                        CategoryChip(name: note.category)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct CategoryChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(Text("Category: \(name)"))
    }
}
