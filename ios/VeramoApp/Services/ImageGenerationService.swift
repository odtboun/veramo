import Foundation
import UIKit

class ImageGenerationService {
    static let shared = ImageGenerationService()
    
    private let baseURL = "https://veramo-backend-20729573701.us-east1.run.app"
    
    // Temporary workaround - use a test endpoint
    private let testMode = true
    
    private init() {}
    
    func generateImage(
        description: String,
        styleLabel: String? = nil,
        referenceImages: [UIImage] = []
    ) async throws -> UIImage {
        
        // Temporary workaround for testing
        if testMode {
            print("🧪 Test mode: Creating local placeholder image")
            return createLocalPlaceholderImage(description: description, styleLabel: styleLabel, referenceImages: referenceImages)
        }
        
        guard let url = URL(string: "\(baseURL)/generate-image") else {
            throw ImageGenerationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add description
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        body.append(description.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add style label (or "none" if not provided)
        let style = styleLabel ?? "none"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"style_label\"\r\n\r\n".data(using: .utf8)!)
        body.append(style.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add reference images
        for (index, image) in referenceImages.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image_\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🚀 Making API request to: \(url)")
        print("🚀 Request method: \(request.httpMethod ?? "unknown")")
        print("🚀 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("🚀 Request body size: \(body.count) bytes")
        print("🚀 Description: '\(description)'")
        print("🚀 Style: '\(styleLabel ?? "none")'")
        print("🚀 Images count: \(referenceImages.count)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw ImageGenerationError.invalidResponse
            }
            
            print("🌐 API Response: Status \(httpResponse.statusCode)")
            print("🌐 API Response Headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ API Error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ API Error Response: \(responseString)")
                }
                throw ImageGenerationError.serverError(httpResponse.statusCode)
            }
            
            guard let image = UIImage(data: data) else {
                throw ImageGenerationError.invalidImageData
            }
            
            return image
            
        } catch {
            if error is ImageGenerationError {
                throw error
            } else {
                throw ImageGenerationError.networkError(error)
            }
        }
    }
    
    private func createLocalPlaceholderImage(description: String, styleLabel: String?, referenceImages: [UIImage]) -> UIImage {
        // Create a simple placeholder image that simulates the backend behavior
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background color based on style
            let backgroundColor: UIColor
            switch styleLabel?.lowercased() {
            case "warm":
                backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
            case "cool":
                backgroundColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
            case "vibrant":
                backgroundColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            case "muted":
                backgroundColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
            default:
                backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
            }
            
            context.cgContext.setFillColor(backgroundColor.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            
            // If we have reference images, simulate the rotation and cropping
            if let firstImage = referenceImages.first {
                // Simulate 90-degree rotation and square cropping
                let imageSize = min(firstImage.size.width, firstImage.size.height)
                let croppedRect = CGRect(
                    x: (firstImage.size.width - imageSize) / 2,
                    y: (firstImage.size.height - imageSize) / 2,
                    width: imageSize,
                    height: imageSize
                )
                
                if let croppedImage = firstImage.cgImage?.cropping(to: croppedRect) {
                    // Create a UIImage from the cropped CGImage
                    let croppedUIImage = UIImage(cgImage: croppedImage, scale: firstImage.scale, orientation: firstImage.imageOrientation)
                    
                    // Actually rotate the image 90 degrees using Core Graphics
                    let rotatedSize = CGSize(width: croppedUIImage.size.height, height: croppedUIImage.size.width)
                    let rotatedRenderer = UIGraphicsImageRenderer(size: rotatedSize)
                    let rotatedImage = rotatedRenderer.image { context in
                        context.cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
                        context.cgContext.rotate(by: .pi / 2) // 90 degrees
                        context.cgContext.translateBy(x: -croppedUIImage.size.width / 2, y: -croppedUIImage.size.height / 2)
                        croppedUIImage.draw(in: CGRect(origin: .zero, size: croppedUIImage.size))
                    }
                    
                    // Scale to final size and draw
                    let scaledImage = rotatedImage.resized(to: size)
                    scaledImage.draw(in: CGRect(origin: .zero, size: size))
                }
            } else {
                // Add text overlay for no images case
                let text = "Test Mode\n\(description.prefix(20))..."
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum ImageGenerationError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case invalidImageData
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidImageData:
            return "Invalid image data received"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
