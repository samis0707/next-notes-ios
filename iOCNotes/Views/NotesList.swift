// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import SwiftUI

///
/// SwiftUI replacement for the legacy `NotesTableViewController`.
///
/// Phase 1 of the iPhone UX rewrite shipped this list as a pure SwiftUI
/// replacement for the legacy `NotesTableViewController`. Phase 2 wires it up
/// to the new native ``NoteEditorScreen`` instead of pushing into the old
/// UIKit editor.
///
/// * `@FetchRequest` over the existing `Note` Core Data entity
/// * `.searchable` with predicate updates instead of manual `performFetch`
/// * `.swipeActions` for delete / favorite / share / category
/// * `.refreshable` for pull-to-refresh
/// * `ContentUnavailableView` for empty / no-search-results states
/// * Inline sync indicator instead of full-screen `PKHUD` overlays
///
struct NotesList: View {
    @Environment(Store.self) private var store
    @Environment(\.managedObjectContext) private var managedObjectContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "favorite", ascending: false),
            NSSortDescriptor(key: "modified", ascending: false)
        ],
        predicate: NSPredicate(format: "deleteNeeded == NO"),
        animation: .default
    ) private var notes: FetchedResults<Note>

    @State private var searchText = ""
    @State private var categoryEditor: CategoryEditorContext?
    @State private var shareItem: ShareItem?
    @State private var pendingDelete: Note?
    @State private var errorMessage: ErrorBanner?
    @State private var newlyCreatedRoute: NoteRoute?

    // Sensory-feedback triggers. iOS 17's SwiftUI .sensoryFeedback API
    // replaces the previous UIImpactFeedbackGenerator dance and avoids
    // having to manually `prepare()` and `impactOccurred()`.
    @State private var addTrigger = 0
    @State private var openTrigger = 0
    @State private var deleteTrigger = 0
    @State private var favoriteTrigger = 0

    var body: some View {
        Group {
            if notes.isEmpty && searchText.isEmpty {
                EmptyNotesView {
                    createNote()
                }
            } else if notes.isEmpty {
                NoSearchResultsView(searchText: searchText)
            } else {
                listContent
            }
        }
        .navigationTitle(String(localized: "Notes", comment: "Title of the notes list screen"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .accessibilityLabel(Text("New note"))
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                if store.isSynchronizing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .onChange(of: searchText) {
            applyPredicate()
        }
        .refreshable {
            await refresh()
        }
        .confirmationDialog(
            Text("Delete this note?"),
            isPresented: deleteDialogBinding,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { note in
            Button(role: .destructive) {
                delete(note: note)
            } label: {
                Text("Delete")
            }
            Button(role: .cancel) {
                pendingDelete = nil
            } label: {
                Text("Cancel")
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
        .alert(
            errorMessage?.title ?? "",
            isPresented: alertBinding,
            presenting: errorMessage
        ) { _ in
            Button {
                errorMessage = nil
            } label: {
                Text("OK")
            }
        } message: { banner in
            Text(banner.message)
        }
        .sheet(item: $categoryEditor) { context in
            CategoryEditorSheet(note: context.note)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.items)
        }
        .navigationDestination(for: NoteRoute.self) { route in
            editorDestination(for: route)
        }
        .navigationDestination(item: $newlyCreatedRoute) { route in
            editorDestination(for: route)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: addTrigger)
        .sensoryFeedback(.selection, trigger: openTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: favoriteTrigger)
        .sensoryFeedback(.warning, trigger: deleteTrigger)
    }

    @ViewBuilder
    private func editorDestination(for route: NoteRoute) -> some View {
        if let resolved = try? managedObjectContext.existingObject(with: route.objectID) as? Note {
            NoteEditorScreen(note: resolved)
        } else {
            ContentUnavailableView {
                Label {
                    Text("Note unavailable")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text("This note could not be loaded.")
            }
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            ForEach(notes, id: \.objectID) { note in
                NavigationLink(value: NoteRoute(objectID: note.objectID)) {
                    NoteRow(note: note)
                }
                    // Fires a soft selection haptic the moment the user taps
                    // the row. SwiftUI's NavigationLink doesn't expose an
                    // onTap callback so a simultaneous tap gesture is used to
                    // attach the side effect without intercepting the
                    // navigation itself.
                    .simultaneousGesture(TapGesture().onEnded {
                        openTrigger &+= 1
                    })
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDelete = note
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            shareItem = ShareItem.from(note: note)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            toggleFavorite(note: note)
                        } label: {
                            Label(
                                note.favorite ? "Unfavorite" : "Favorite",
                                systemImage: note.favorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)

                        Button {
                            categoryEditor = CategoryEditorContext(note: note)
                        } label: {
                            Label("Category", systemImage: "folder")
                        }
                        .tint(.indigo)
                    }
                    .contextMenu {
                        NavigationLink(value: NoteRoute(objectID: note.objectID)) {
                            Label("Open", systemImage: "doc.text")
                        }
                        Button {
                            toggleFavorite(note: note)
                        } label: {
                            Label(
                                note.favorite ? "Unfavorite" : "Favorite",
                                systemImage: note.favorite ? "star.slash" : "star.fill"
                            )
                        }
                        Button {
                            categoryEditor = CategoryEditorContext(note: note)
                        } label: {
                            Label("Category…", systemImage: "folder")
                        }
                        Button {
                            shareItem = ShareItem.from(note: note)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            pendingDelete = note
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func createNote() {
        addTrigger &+= 1
        NoteSessionManager.shared.add(content: "", category: "") { newNote in
            if let newNote {
                Task { @MainActor in
                    newlyCreatedRoute = NoteRoute(objectID: newNote.objectID)
                }
            }
        }
    }

    private func toggleFavorite(note: Note) {
        favoriteTrigger &+= 1
        note.favorite.toggle()
        note.updateNeeded = true
        try? managedObjectContext.save()
        NoteSessionManager.shared.update(note: note)
    }

    private func delete(note: Note) {
        deleteTrigger &+= 1
        NoteSessionManager.shared.delete(note: note)
        pendingDelete = nil
    }

    private func refresh() async {
        guard NoteSessionManager.isOnline else {
            errorMessage = ErrorBanner(
                title: String(localized: "Offline", comment: "Title of offline error"),
                message: String(localized: "Connect to the internet to sync notes.", comment: "Body of offline error")
            )
            return
        }

        await withCheckedContinuation { continuation in
            NoteSessionManager.shared.sync {
                continuation.resume()
            }
        }
    }

    private func applyPredicate() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.nsPredicate = NSPredicate(format: "deleteNeeded == NO")
        } else {
            let base = NSPredicate(format: "deleteNeeded == NO")
            let match = NSPredicate(format: "(title CONTAINS[cd] %@) OR (content CONTAINS[cd] %@)", trimmed, trimmed)
            notes.nsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [base, match])
        }
    }

    // MARK: - Helpers

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { newValue in
                if newValue == false {
                    pendingDelete = nil
                }
            }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if newValue == false {
                    errorMessage = nil
                }
            }
        )
    }
}

// MARK: - Supporting Types

private struct CategoryEditorContext: Identifiable {
    let note: Note
    var id: NSManagedObjectID { note.objectID }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]

    static func from(note: Note) -> ShareItem {
        let header = note.title.isEmpty ? String(localized: "Untitled", comment: "Default share subject") : note.title
        let body = note.content
        return ShareItem(items: ["\(header)\n\n\(body)"])
    }
}

private struct ErrorBanner: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

///
/// Hashable + Identifiable navigation token wrapping a `Note`'s managed object
/// ID. SwiftUI's NavigationStack needs `Hashable` for value-based pushes and a
/// stable `Identifiable` conformance for programmatic pushes via
/// `.navigationDestination(item:)`. Note itself isn't usable directly because
/// equality + hashing of NSManagedObject is identity-based and changes if the
/// object is refaulted.
///
struct NoteRoute: Hashable, Identifiable {
    let objectID: NSManagedObjectID
    var id: NSManagedObjectID { objectID }
}

// MARK: - Category Editor Sheet

private struct CategoryEditorSheet: View {
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
                                    Text(category)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if draftCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
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
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                    }
                }
            }
            .onAppear {
                draftCategory = note.category
            }
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

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Haptics
