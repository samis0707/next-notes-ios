// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import SwiftUI
import UIKit

///
/// Native SwiftUI replacement for the legacy ``EditorViewController``.
///
/// What's new compared to Phase 1's modal UIKit editor:
///
/// * Separate title field at the top — users no longer rely on the first body
///   line for the title.
/// * Markdown formatting toolbar above the keyboard with B / I / heading /
///   bullet / checkbox / link / code / undo / redo (the biggest single
///   thumb-friendliness win from the audit).
/// * Compact navigation bar: a single `⋯` menu groups Preview / Share /
///   Category / Delete instead of seven crammed bar buttons.
/// * Inline save indicator (dot + status text) so the user knows a save is in
///   flight or has just completed.
/// * Preview is presented as a sheet instead of a separate screen.
///
struct NoteEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext

    @ObservedObject var note: Note

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var initialized = false
    // Set to true the first time the user mutates the editor so the async
    // server fetch from `bootstrapIfNeeded` no longer overwrites their typing.
    @State private var userHasEdited = false

    @State private var saveState: SaveState = .saved
    @State private var pendingSaveWork: Task<Void, Never>?

    @State private var showPreview = false
    @State private var showCategory = false
    @State private var showShare = false
    @State private var showDeleteConfirm = false
    @State private var showRename = false
    @State private var renameDraft = ""

    // Sensory-feedback triggers — see NotesList for the pattern.
    @State private var favoriteTrigger = 0
    @State private var deleteTrigger = 0

    private enum SaveState: Equatable {
        case saved
        case dirty
        case saving
    }

    var body: some View {
        MarkdownTextViewRepresentable(
            text: $content,
            onTextChange: handleTextChange
        )
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        // The iOS 26 nav bar otherwise paints a "Liquid Glass" material strip
        // behind the back button, title and action menu which the user reads
        // as a chrome box bolted onto the editor. Hidden = the markdown body
        // shows through and the chrome is just the buttons themselves.
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: title) {
            handleTitleChange()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                titleAndSubtitle
            }
            ToolbarItem(placement: .topBarTrailing) {
                actionMenu
            }
        }
        .alert(
            String(localized: "Rename note", comment: "Title of rename alert"),
            isPresented: $showRename
        ) {
            TextField(
                String(localized: "Title", comment: "Placeholder for title text field"),
                text: $renameDraft
            )
            Button(role: .cancel) {
                showRename = false
            } label: {
                Text("Cancel")
            }
            Button {
                title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                showRename = false
            } label: {
                Text("Save")
            }
        }
        .sheet(isPresented: $showPreview) {
            MarkdownPreviewSheet(
                title: title,
                date: formattedDate,
                content: content
            )
        }
        .sheet(isPresented: $showCategory) {
            NoteCategorySheet(note: note)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog(
            Text("Delete this note?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteNote()
            } label: {
                Text("Delete")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear(perform: bootstrapIfNeeded)
        .onDisappear(perform: persistImmediately)
        .sensoryFeedback(.impact(weight: .light), trigger: favoriteTrigger)
        .sensoryFeedback(.warning, trigger: deleteTrigger)
    }

    // MARK: - Title + subtitle (principal toolbar slot)

    /// Centered title with date · category subtitle directly underneath, all
    /// inside the navigation bar's principal slot. Tapping opens a rename
    /// alert. This is the iOS-26 style "compact two-line nav title".
    private var titleAndSubtitle: some View {
        Button {
            renameDraft = title
            showRename = true
        } label: {
            VStack(spacing: 0) {
                Text(title.isEmpty ? String(localized: "Untitled", comment: "Placeholder title for a note without a name") : title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: 220)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Rename"))
    }

    /// Untertitel-Text. Während einer Bearbeitung oder eines Saves verdrängt
    /// der Status das normale Datum · Kategorie — so taucht der Save-Status
    /// genau dort auf, wo der Nutzer den Titel ohnehin liest, ohne ein
    /// weiteres UI-Element in der Navi-Leiste.
    private var subtitleText: String? {
        switch saveState {
        case .saving:
            return String(localized: "Saving…", comment: "Subtitle shown while autosave is in flight")
        case .dirty:
            return String(localized: "Edited", comment: "Subtitle shown while there are unsaved changes")
        case .saved:
            let datePart = formattedDate
            let categoryPart = note.category.isEmpty ? nil : note.category
            switch (datePart, categoryPart) {
            case (nil, nil):
                return nil
            case (let d?, nil):
                return d
            case (nil, let c?):
                return c
            case (let d?, let c?):
                return "\(d) · \(c)"
            }
        }
    }

    // MARK: - Action menu

    private var actionMenu: some View {
        Menu {
            Button {
                renameDraft = title
                showRename = true
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
            Button {
                showPreview = true
            } label: {
                Label("Preview", systemImage: "text.page.badge.magnifyingglass")
            }
            Button {
                showShare = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                showCategory = true
            } label: {
                Label("Category…", systemImage: "folder")
            }
            Button {
                toggleFavorite()
            } label: {
                Label(
                    note.favorite ? "Unfavorite" : "Favorite",
                    systemImage: note.favorite ? "star.slash" : "star.fill"
                )
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel(Text("Actions"))
        }
    }

    // MARK: - State

    private var formattedDate: String? {
        guard note.modified > 0 else {
            return nil
        }
        let date = Date(timeIntervalSince1970: note.modified)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private var shareItems: [Any] {
        let header = title.isEmpty ? String(localized: "Untitled", comment: "Default share subject") : title
        return ["\(header)\n\n\(content)"]
    }

    private func bootstrapIfNeeded() {
        guard !initialized else {
            return
        }
        title = note.title
        content = note.content
        initialized = true

        // Fetch the latest server-side content asynchronously while showing the
        // local cached copy. Mirrors the legacy editor's behaviour without HUD.
        // Crucially, the response is only applied if the user has not yet
        // started typing — otherwise a slow server response would overwrite
        // freshly-typed characters and snap the cursor back to the start of
        // the document.
        if !note.addNeeded {
            NoteSessionManager.shared.get(note: note) {
                Task { @MainActor in
                    guard initialized, !userHasEdited else { return }
                    if note.content != content {
                        content = note.content
                    }
                    if note.title != title {
                        title = note.title
                    }
                }
            }
        }

        // The text view's first responder state is owned by UIKit. For brand
        // new empty notes we don't auto-focus here — the user can tap into the
        // body when ready. (An auto-focus delivered through SwiftUI to a
        // UIViewRepresentable in iOS 17 fights the keyboard show animation.)
    }

    // MARK: - Persistence

    private func handleTitleChange() {
        guard initialized else { return }
        if note.title == title { return }
        userHasEdited = true
        scheduleSave()
    }

    private func handleTextChange() {
        guard initialized else { return }
        if note.content == content { return }
        userHasEdited = true
        scheduleSave()
    }

    private func scheduleSave() {
        saveState = .dirty
        pendingSaveWork?.cancel()
        pendingSaveWork = Task { [content, title] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                performSave(content: content, title: title)
            }
        }
    }

    private func performSave(content: String, title: String) {
        if note.content == content && note.title == title {
            saveState = .saved
            return
        }

        note.content = content
        note.title = title.isEmpty ? deriveTitle(from: content) : title
        note.updateNeeded = true
        try? managedObjectContext.save()

        saveState = .saving
        NoteSessionManager.shared.update(note: note) {
            Task { @MainActor in
                saveState = .saved
            }
        }
    }

    private func persistImmediately() {
        pendingSaveWork?.cancel()
        if note.content != content || note.title != title {
            performSave(content: content, title: title)
        }
    }

    private func deriveTitle(from body: String) -> String {
        let firstLine = body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine, !firstLine.isEmpty else {
            return String(localized: "New note", comment: "Default title for new notes")
        }
        return String(firstLine.prefix(60))
    }

    // MARK: - Actions

    private func toggleFavorite() {
        favoriteTrigger &+= 1
        note.favorite.toggle()
        note.updateNeeded = true
        try? managedObjectContext.save()
        NoteSessionManager.shared.update(note: note)
    }

    private func deleteNote() {
        pendingSaveWork?.cancel()
        deleteTrigger &+= 1
        NoteSessionManager.shared.delete(note: note)
        dismiss()
    }
}

// MARK: - Helpers reused from NotesList

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct NoteCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext

    @ObservedObject var note: Note
    @State private var draftCategory: String = ""

    private var existingCategories: [String] {
        let request = Note.fetchRequest()
        request.predicate = NSPredicate(format: "deleteNeeded == NO AND category != ''")
        let categories = (try? managedObjectContext.fetch(request))?.map(\.category) ?? []
        return Array(Set(categories)).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "Category", comment: "Placeholder for category text field"),
                        text: $draftCategory
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                }

                if existingCategories.isEmpty == false {
                    Section(String(localized: "Existing", comment: "Section header for existing categories")) {
                        ForEach(existingCategories, id: \.self) { category in
                            Button {
                                draftCategory = category
                            } label: {
                                HStack {
                                    Text(category).foregroundStyle(.primary)
                                    Spacer()
                                    if draftCategory == category {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text("Category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Save") }
                }
            }
            .onAppear { draftCategory = note.category }
        }
    }

    private func save() {
        let trimmed = draftCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.category != trimmed {
            note.category = trimmed
            note.updateNeeded = true
            try? managedObjectContext.save()
            NoteSessionManager.shared.update(note: note)
        }
        dismiss()
    }
}
