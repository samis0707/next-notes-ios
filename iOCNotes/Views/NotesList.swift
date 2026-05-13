// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import SwiftUI

///
/// SwiftUI replacement for the legacy `NotesTableViewController`.
///
/// The iOS-26 UI rewrite changed the navigation shell:
///
/// * No bottom tab bar — Settings now lives behind a gear button in the top
///   right of the navigation bar and presents as a sheet.
/// * The trailing "+" button moved out of the navigation bar to a floating
///   action pill at the bottom of the screen, next to a search field (as a
///   wide capsule) and a category filter button.
///
struct NotesList: View {
    @Environment(Store.self) private var store
    @Environment(\.managedObjectContext) private var managedObjectContext

    @Binding var showSettings: Bool

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "favorite", ascending: false),
            NSSortDescriptor(key: "modified", ascending: false)
        ],
        predicate: NSPredicate(format: "deleteNeeded == NO"),
        animation: .default
    ) private var notes: FetchedResults<Note>

    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var showCategoryFilter = false
    @State private var categoryEditor: CategoryEditorContext?
    @State private var shareItem: ShareItem?
    @State private var pendingDelete: Note?
    @State private var errorMessage: ErrorBanner?
    @State private var newlyCreatedRoute: NoteRoute?

    // Sensory-feedback triggers. The open-note haptic fires inside
    // ``NoteEditorScreen`` itself once the editor appears, so it isn't
    // declared here.
    @State private var addTrigger = 0
    @State private var deleteTrigger = 0
    @State private var favoriteTrigger = 0

    var body: some View {
        Group {
            if notes.isEmpty && searchText.isEmpty && selectedCategory == nil {
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
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel(Text("Settings"))
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                if store.isSynchronizing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .onChange(of: searchText) {
            applyPredicate()
        }
        .onChange(of: selectedCategory) {
            applyPredicate()
        }
        .refreshable {
            await refresh()
        }
        .safeAreaInset(edge: .bottom) {
            floatingBottomBar
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
        .sheet(isPresented: $showCategoryFilter) {
            CategoryFilterSheet(selectedCategory: $selectedCategory)
        }
        .navigationDestination(for: NoteRoute.self) { route in
            editorDestination(for: route)
        }
        .navigationDestination(item: $newlyCreatedRoute) { route in
            editorDestination(for: route)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: addTrigger)
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

    // MARK: - Floating bottom bar

    private var floatingBottomBar: some View {
        HStack(spacing: 8) {
            searchPill
            categoryFilterButton
            newNoteButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var searchPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "Search", comment: "Placeholder for the search field in the notes list"),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.separator, lineWidth: 0.5))
    }

    private var categoryFilterButton: some View {
        Button {
            showCategoryFilter = true
        } label: {
            Image(systemName: selectedCategory == nil ? "folder" : "folder.fill")
                .font(.system(size: 18))
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(.separator, lineWidth: 0.5))
                .foregroundStyle(selectedCategory == nil ? Color.primary : Color.accentColor)
        }
        .accessibilityLabel(Text("Filter by category"))
    }

    private var newNoteButton: some View {
        Button {
            createNote()
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18))
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(Text("New note"))
    }

    // MARK: - Actions

    private func createNote() {
        addTrigger &+= 1
        // Apply the active category filter to the freshly created note so it
        // remains visible in the currently filtered list.
        let initialCategory = selectedCategory ?? ""
        NoteSessionManager.shared.add(content: "", category: initialCategory) { newNote in
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
        var subpredicates: [NSPredicate] = [NSPredicate(format: "deleteNeeded == NO")]

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            subpredicates.append(
                NSPredicate(
                    format: "(title CONTAINS[cd] %@) OR (content CONTAINS[cd] %@)",
                    trimmed,
                    trimmed
                )
            )
        }

        if let selectedCategory {
            subpredicates.append(NSPredicate(format: "category == %@", selectedCategory))
        }

        notes.nsPredicate = subpredicates.count > 1
            ? NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
            : subpredicates[0]
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

// MARK: - Category Filter Sheet

private struct CategoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext

    @Binding var selectedCategory: String?

    private var existingCategories: [String] {
        let request = Note.fetchRequest()
        request.predicate = NSPredicate(format: "deleteNeeded == NO AND category != ''")
        let categories = (try? managedObjectContext.fetch(request))?.map(\.category) ?? []
        return Array(Set(categories)).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedCategory = nil
                    dismiss()
                } label: {
                    HStack {
                        Label {
                            Text("All Notes")
                        } icon: {
                            Image(systemName: "tray.full")
                        }
                        .foregroundStyle(.primary)
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                if existingCategories.isEmpty == false {
                    Section(String(localized: "Categories", comment: "Section header in the category filter sheet")) {
                        ForEach(existingCategories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                dismiss()
                            } label: {
                                HStack {
                                    Label {
                                        Text(category)
                                    } icon: {
                                        Image(systemName: "folder")
                                    }
                                    .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
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
