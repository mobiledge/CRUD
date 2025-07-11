import SwiftUI

struct ListRowDemo: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Simple Rows")) {
                    ListRow(title: "Plain Text Label")
                    ListRow(title: "Title Here", subtitle: "This is the subtitle text.")
                }
                
                Section(header: Text("Rows with Thumbnails")) {
                    ListRow(title: "Label & System Image", image: .system(name: "swift"))
                    
                    if let imageUrl = URL(string: "https://picsum.photos/id/12/200") {
                        ListRow(title: "Label & Remote Image", image: .remote(url: imageUrl))
                    }
                }
                
                Section(header: Text("Composite Rows")) {
                    ListRow(
                        title: "Title",
                        subtitle: "Subtitle with a system image",
                        image: .system(name: "flame.fill")
                    )
                    
                    if let imageUrl = URL(string: "https://picsum.photos/id/24/200") {
                        ListRow(
                            title: "Title",
                            subtitle: "Subtitle with a remote image",
                            image: .remote(url: imageUrl)
                        )
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("ListRow")
        }
    }
}

struct ListRow: View {
    // MARK: Internal Types
    
    enum ImageType {
        case system(name: String)
        case remote(url: URL)
    }
    
    // MARK: Properties
    
    var title: String
    var subtitle: String?
    var image: ImageType?
    
    // Use @ScaledMetric to create a size that adapts to Dynamic Type.
    // It's linked to the .headline style to match the title's font.
    @ScaledMetric(relativeTo: .headline) private var imageSize: CGFloat = 32
    
    init(title: String, subtitle: String? = nil, image: ImageType? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
    }
    
    // MARK: Body
    
    var body: some View {
        HStack(spacing: 16) {
            imageView
            textContentView
        }
        .padding(.vertical, 4)
    }
    
    // MARK: Private Subviews
    
    @ViewBuilder
    private var imageView: some View {
        if let image = image {
            Group {
                switch image {
                case .system(let name):
                    Image(systemName: name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: imageSize, height: imageSize)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                    
                case .remote(let url):
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "photo")
                        default:
                            ProgressView()
                        }
                    }
                    // Use the dynamic imageSize for the frame
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private var textContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
#Preview {
    ListRowDemo()
}
