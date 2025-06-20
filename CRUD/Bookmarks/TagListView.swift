import SwiftUI

struct TagListView: View {
    @Binding var searchTokens: [Token]
    @Environment(BookmarkRepository.self) private var repo
    @State private var searchText = ""
    
    private var selectedTagNames: Set<String> {
        Set(searchTokens.map { $0.name })
    }
    private var tags: [String] {
        repo.tags
    }
    
    private var filtered: [String] {
        if searchText.isEmpty {
            return tags
        } else {
            return tags.filter { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // MARK: Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Filter tags...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .padding(.horizontal, 12)
            }
            // MARK: Tag List
            List {
                Section(header: header) {
                    ForEach(filtered, id: \.self) { tag in
                        // MARK: List Row
                        HStack {
                            Image(systemName: selectedTagNames.contains(tag) ? "checkmark.circle.fill" : "tag")
                                .foregroundStyle(selectedTagNames.contains(tag) ? .blue : .secondary)
                            Text(tag)
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if selectedTagNames.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .font(.body)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTagNames.contains(tag) {
                                searchTokens.removeAll { $0.name == tag }
                            } else {
                                searchTokens.append(Token(name: tag))
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .animation(.default, value: tags.count)
        }
        .navigationTitle("Tags")
    }
    
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS")
                .font(.headline)
            
            // MARK: Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Filter tags...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(.systemGray5))
            }
        }
    }
}

#Preview {
    NavigationSplitView {
        TagListView(searchTokens: .constant([Token(name: "swift"), Token(name: "ios")]))
    } detail: {
        Text("Detail")
    }
    .environment(BookmarkRepository.mock())
}


//// Count display at bottom
//Text("Count: \(tags.count)")
//    .font(.headline)
//    .foregroundStyle(.primary)
//    .padding(.horizontal, 16)
//    .padding(.vertical, 8)
//    .background {
//        RoundedRectangle(cornerRadius: 12)
//            .fill(.ultraThinMaterial)
//            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
//    }
//    .padding(.bottom, 20)
//    .animation(.easeInOut(duration: 0.3), value: tags.count)
