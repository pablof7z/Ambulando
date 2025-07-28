import SwiftUI
import Combine

struct AmbulandoAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    init(url: URL?, 
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                content(image)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(url: url)
        }
        .onChange(of: url) { _, newURL in
            loader.load(url: newURL)
        }
    }
}

// MARK: - Image Loader
private class ImageLoader: ObservableObject {
    @Published var image: Image?
    
    private var cancellable: AnyCancellable?
    private static let imageCache = ImageCache.shared
    
    func load(url: URL?) {
        guard let url = url else {
            self.image = nil
            return
        }
        
        // Check memory cache first
        if let cachedImage = Self.imageCache.getFromMemory(url: url) {
            print("🎯 [AmbulandoAsyncImage] Memory cache HIT: \(url.lastPathComponent)")
            self.image = Image(uiImage: cachedImage)
            return
        }
        
        // Check disk cache
        Task {
            if let diskImage = await Self.imageCache.getFromDisk(url: url) {
                print("💾 [AmbulandoAsyncImage] Disk cache HIT: \(url.lastPathComponent)")
                await MainActor.run {
                    self.image = Image(uiImage: diskImage)
                }
                return
            }
            
            print("🌐 [AmbulandoAsyncImage] Cache MISS, downloading: \(url.lastPathComponent)")
            
            // Download if not cached
            await downloadImage(from: url)
        }
    }
    
    private func downloadImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.ambulando.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            
            // Cache the image
            await Self.imageCache.store(image: uiImage, for: url)
            print("✅ [AmbulandoAsyncImage] Downloaded and cached: \(url.lastPathComponent)")
            
            await MainActor.run {
                self.image = Image(uiImage: uiImage)
            }
        } catch {
            print("❌ [AmbulandoAsyncImage] Failed to download \(url.lastPathComponent): \(error)")
        }
    }
}

// MARK: - Image Cache
private class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Set up cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("Ambulando/Images")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.countLimit = 100 // Max 100 images in memory
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // Max 100MB
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func getFromMemory(url: URL) -> UIImage? {
        return memoryCache.object(forKey: url.absoluteString as NSString)
    }
    
    func getFromDisk(url: URL) async -> UIImage? {
        let filePath = cacheFilePath(for: url)
        
        guard fileManager.fileExists(atPath: filePath.path) else { return nil }
        
        // Check if cache is expired (7 days)
        if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > 7 * 24 * 60 * 60 {
            try? fileManager.removeItem(at: filePath)
            return nil
        }
        
        guard let data = try? Data(contentsOf: filePath),
              let image = UIImage(data: data) else { return nil }
        
        // Also store in memory cache
        memoryCache.setObject(image, forKey: url.absoluteString as NSString, cost: data.count)
        
        return image
    }
    
    func store(image: UIImage, for url: URL) async {
        // Store in memory
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        memoryCache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
        
        // Store on disk
        let filePath = cacheFilePath(for: url)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: filePath)
        }
    }
    
    private func cacheFilePath(for url: URL) -> URL {
        let fileName = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? "unknown"
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    func clearAll() {
        clearMemoryCache()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// Convenience initializer for simple use cases
extension AmbulandoAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}