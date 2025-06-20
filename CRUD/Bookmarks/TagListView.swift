import SwiftUI

struct TagListView: View {
    @Environment(BookmarkRepository.self) private var repo
    @State private var searchText = ""
    @State private var searchTokens = [Token]()
    
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
        VStack(spacing: 0) {
            // Top section with search bar
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search tags...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.regularMaterial)
            
            // List takes up remaining space
            ZStack(alignment: .bottom) {
                List(filtered, id: \.self) { tag in
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        Text(tag)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .font(.body)
                }
                .animation(.default, value: tags.count)
                
                // Count display at bottom
                Text("Count: \(tags.count)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.bottom, 20)
                    .animation(.easeInOut(duration: 0.3), value: tags.count)
            }
        }
        .navigationTitle("Tags")
    }
}

#Preview {
    NavigationSplitView {
        TagListView()
    } detail: {
        Text("Detail")
    }
    .environment(BookmarkRepository.mock())
}
