import Foundation
import UIKit

final class LocalImageCache {
    static let shared = LocalImageCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Cache Management
    
    func cacheImage(_ image: UIImage, for storagePath: String) {
        let fileName = sanitizeFileName(storagePath)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: fileURL)
            print("💾 Cached image: \(fileName)")
        }
    }
    
    func getCachedImage(for storagePath: String) -> UIImage? {
        let fileName = sanitizeFileName(storagePath)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            if let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                print("📱 Loaded from cache: \(fileName)")
                return image
            }
        }
        
        return nil
    }
    
    func clearOldCache() {
        // Clear cache older than 2 months to keep current month + previous month
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < twoMonthsAgo {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Cleared old cache: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Failed to clear old cache: \(error)")
        }
    }
    
    func clearAllCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("🗑️ Cleared all cache")
        } catch {
            print("❌ Failed to clear all cache: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func sanitizeFileName(_ path: String) -> String {
        // Replace path separators and special characters with safe characters
        return path.replacingOccurrences(of: "/", with: "_")
                  .replacingOccurrences(of: ":", with: "_")
                  .replacingOccurrences(of: " ", with: "_")
    }
    
    func getCacheSize() -> Int64 {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            
            for file in files {
                if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
}
