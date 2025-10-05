import Foundation
import UIKit

class ImageGenerationService {
    static let shared = ImageGenerationService()
    
    private let baseURL = "https://veramo-backend-20729573701.us-east1.run.app"
    
    private init() {}
    
    func generateImage(
        description: String,
        styleLabel: String? = nil,
        referenceImages: [UIImage] = []
    ) async throws -> UIImage {
        
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
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageGenerationError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
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
