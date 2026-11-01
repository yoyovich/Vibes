import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            SearchScreen()
                .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
            LibraryScreen()
                .tabItem { Label("Медиатека", systemImage: "music.note.list") }
        }
        .tint(.orange)
        .preferredColorScheme(.dark)
    }
}

struct SearchScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var source: MusicSource = .soundCloud
    @State private var query = ""
    @State private var pastedLink = ""
    @State private var browserDestination: BrowserDestination?
    @State private var isImporting = false
    @State private var errorText: String?
    @State private var messageText: String?
    private let importer = OEmbedClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Два источника. Одна библиотека.")
                            .font(.title2.bold())
                        Text("SoundCloud — основной. Spotify — второй источник для поиска и ссылок.")
                            .foregroundStyle(.secondary)
                    }
                    Picker("Источник", selection: $source) {
                        ForEach(MusicSource.allCases) { service in
                            Text(service.title).tag(service)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Поиск в каталоге").font(.headline)
                        TextField("Название или исполнитель", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit(openSearch)
                            .padding(13)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        Button(action: openSearch) {
                            Label("Найти в \(source.title)", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Text("На первом этапе результаты показываются на сайте сервиса внутри приложения. На странице трека нажми «Сохранить».")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Добавить по ссылке").font(.headline)
                        TextField("Ссылка SoundCloud или Spotify", text: $pastedLink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding(13)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            Task { await importLink(pastedLink) }
                        } label: {
                            if isImporting { ProgressView().frame(maxWidth: .infinity) }
                            else { Label("Сохранить в медиатеку", systemImage: "plus").frame(maxWidth: .infinity) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isImporting || pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let messageText {
                        Label(messageText, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Vibes")
            .sheet(item: $browserDestination) { destination in
                BrowserScreen(initialURL: destination.url, source: destination.source)
                    .environmentObject(library)
            }
            .alert("Ошибка", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) { Button("OK", role: .cancel) { errorText = nil } } message: {
                Text(errorText ?? "Неизвестная ошибка")
            }
        }
    }

    private func openSearch() {
        guard let url = source.searchURL(for: query) else { return }
        browserDestination = BrowserDestination(url: url, source: source)
    }

    @MainActor
    private func importLink(_ raw: String) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        messageText = nil
        do {
            let item = try await importer.importLink(raw)
            let wasAdded = library.add(item)
            messageText = wasAdded ? "Сохранено: \(item.title)" : "Уже есть в медиатеке"
            if wasAdded { pastedLink = "" }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct BrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
    let source: MusicSource
}

struct BrowserScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryStore
    let initialURL: URL
    let source: MusicSource
    @State private var currentURL: URL?
    @State private var failure: String?
    @State private var busy = false
    @State private var message: String?
    private let importer = OEmbedClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let failure {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(10)
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .padding(8)
                }
                BrowserWebView(initialURL: initialURL, currentURL: $currentURL, failure: $failure)
            }
            .navigationTitle(source.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if busy { ProgressView() }
                    Button {
                        guard let url = currentURL else { return }
                        Task { await importCurrentURL(url) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Сохранить открытую страницу")
                    .disabled(busy || currentURL == nil)
                    if let currentURL {
                        ShareLink(item: currentURL) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Открой трек и нажми ⊕, чтобы сохранить его")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(9)
                    .background(.ultraThinMaterial)
            }
        }
    }

    @MainActor
    private func importCurrentURL(_ url: URL) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let item = try await importer.importLink(url.absoluteString)
            message = library.add(item) ? "Добавлено в медиатеку" : "Уже сохранено"
        } catch {
            failure = error.localizedDescription
        }
    }
}

struct LibraryScreen: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedItem: MusicItem?

    var body: some View {
        NavigationStack {
            Group {
                if library.items.isEmpty {
                    ContentUnavailableView(
                        "Медиатека пуста",
                        systemImage: "music.note.list",
                        description: Text("Найди трек в SoundCloud или Spotify или добавь его ссылку на вкладке «Поиск».")
                    )
                } else {
                    List {
                        ForEach(library.items) { item in
                            Button { selectedItem = item } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(urlString: item.artworkURL)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(2)
                                        Text(item.source.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "play.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Удалить", role: .destructive) { library.remove(item) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Медиатека")
            .sheet(item: $selectedItem) { item in
                PlayerScreen(item: item)
            }
        }
    }
}

struct ArtworkView: View {
    let urlString: String?
    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(.gray.opacity(0.2))
                .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    let item: MusicItem
    @State private var currentURL: URL?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        ArtworkView(urlString: item.artworkURL)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(item.source.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let link = item.mediaLink,
                       let embedURL = item.embedURL.flatMap(URL.init(string:)) ?? link.embedURL {
                        BrowserWebView(initialURL: embedURL, currentURL: $currentURL, failure: $failure)
                            .frame(height: item.source == .spotify ? 370 : 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let failure {
                            Text(failure).foregroundStyle(.red).font(.footnote)
                        }
                        Text(item.source == .soundCloud
                             ? "Воспроизведение через официальный виджет SoundCloud. Некоторые треки могут быть недоступны."
                             : "Spotify сам определяет, доступно ли полное воспроизведение или только превью.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        Link("Открыть на \(item.source.title)", destination: link.url)
                            .font(.subheadline)
                    } else {
                        ContentUnavailableView("Некорректная ссылка", systemImage: "exclamationmark.triangle")
                    }
                }
                .padding()
            }
            .navigationTitle("Проигрыватель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}
