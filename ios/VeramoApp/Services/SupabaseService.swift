import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient
    let imagesBucket = "images"

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    // MARK: - Couples & Pairing
    struct Couple: Decodable { 
        let id: UUID
        let user1_id: UUID
        let user2_id: UUID
        let is_active: Bool
    }
    struct Profile: Decodable { let id: UUID }

    func currentUserId() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    func fetchCouple() async -> Couple? {
        do {
            let userId = try await currentUserId()
            print("🔍 Fetching couple for user: \(userId)")
            
            let couples: [Couple] = try await client
                .from("couples")
                .select("id, user1_id, user2_id, is_active")
                .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
                .eq("is_active", value: true)
                .execute().value
            
            print("📊 Found \(couples.count) couples")
            return couples.first
        } catch {
            print("❌ Error fetching couple: \(error)")
            return nil
        }
    }

    func generatePairingCode() async throws -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code: String
        var attempts = 0
        
        repeat {
            code = String((0..<6).map { _ in alphabet.randomElement()! })
            attempts += 1
            
            // Check if code already exists
            let existing: [String] = (try? await client
                .from("pairing_codes")
                .select("code")
                .eq("code", value: code)
                .execute().value) ?? []
            
            if existing.isEmpty { break }
        } while attempts < 10
        
        let userId = try await currentUserId()
        struct NewCode: Encodable { 
            let code: String
            let inviter_user_id: UUID
            let expires_at: String
        }
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        _ = try await client.from("pairing_codes").insert(NewCode(
            code: code, 
            inviter_user_id: userId,
            expires_at: expiresAt
        )).execute()
        return code
    }

    func joinWithCode(_ code: String) async throws {
        struct CodeRow: Decodable { 
            let inviter_user_id: UUID
        }
        let found: CodeRow = try await client
            .from("pairing_codes")
            .select("inviter_user_id")
            .eq("code", value: code)
            .single()
            .execute().value

        let myUserId = try await currentUserId()
        let partnerUserId = found.inviter_user_id
        
        // Check if trying to connect with yourself
        if myUserId == partnerUserId {
            throw NSError(domain: "SelfConnection", code: 1, userInfo: [NSLocalizedDescriptionKey: "It's nice to love yourself, but you can't connect with your own code! 😊"])
        }

        // Create new couple
        struct NewCouple: Encodable { 
            let user1_id: UUID
            let user2_id: UUID
            let is_active: Bool
        }
        _ = try await client.from("couples").insert(NewCouple(
            user1_id: partnerUserId,
            user2_id: myUserId,
            is_active: true
        )).execute()
        
        // Mark code as redeemed
        _ = try await client.from("pairing_codes")
            .update([
                "redeemed_by_user_id": myUserId.uuidString,
                "redeemed_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("code", value: code)
            .execute()
    }

    func removePartner() async throws {
        let userId = try await currentUserId()
        
        // Mark couple as inactive (soft delete)
        _ = try await client.from("couples")
            .update(["is_active": false])
            .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
            .eq("is_active", value: true)
            .execute()
    }
    
    // MARK: - Calendar Entries
    func addCalendarEntry(imageId: UUID, scheduledDate: Date) async throws {
        let userId = try await currentUserId()
        let couple = try await fetchCouple()
        
        guard let couple = couple else {
            throw NSError(domain: "NoCouple", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active couple found"])
        }
        
        struct NewEntry: Encodable {
            let couple_id: UUID
            let image_id: UUID
            let date: String
            let created_by_user_id: UUID
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        _ = try await client.from("calendar_entries").insert(NewEntry(
            couple_id: couple.id,
            image_id: imageId,
            date: dateFormatter.string(from: scheduledDate),
            created_by_user_id: userId
        )).execute()
    }
    
    func getCalendarEntries(for date: Date) async throws -> [CalendarEntry] {
        let userId = try await currentUserId()
        let couple = try await fetchCouple()
        
        guard let couple = couple else {
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        struct CalendarEntryRow: Decodable {
            let id: UUID
            let image_id: UUID
            let created_by_user_id: UUID
        }
        
        let entries: [CalendarEntryRow] = try await client
            .from("calendar_entries")
            .select("id, image_id, created_by_user_id")
            .eq("couple_id", value: couple.id)
            .eq("date", value: dateString)
            .execute().value
        
        return entries.map { entry in
            CalendarEntry(
                id: entry.id,
                imageId: entry.image_id,
                createdByUserId: entry.created_by_user_id,
                isFromPartner: entry.created_by_user_id != userId
            )
        }
    }
    
    // MARK: - Gallery Management
    func getSignedUploadURL(fileName: String, mimeType: String) async throws -> CustomSignedUploadURL {
        print("🔑 SupabaseService: Getting signed upload URL...")
        let userId = try await currentUserId()
        let filePath = "\(userId)/\(UUID().uuidString)_\(fileName)"
        print("📁 File path: \(filePath)")
        
        let response = try await client.storage
            .from("user-uploads")
            .createSignedUploadURL(path: filePath)
        
        print("✅ SupabaseService: Signed URL created successfully")
        return CustomSignedUploadURL(
            signedURL: response.signedURL.absoluteString,
            path: response.path,
            token: response.token
        )
    }
    
    func uploadImageToStorage(data: Data, signedURL: String) async throws {
        print("☁️ SupabaseService: Uploading to storage...")
        print("📊 Data size: \(data.count) bytes")
        print("🔗 Signed URL: \(signedURL)")
        
        var request = URLRequest(url: URL(string: signedURL)!)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ SupabaseService: Invalid response type")
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from storage"])
        }
        
        print("📡 SupabaseService: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ SupabaseService: Upload failed with status \(httpResponse.statusCode)")
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image - Status: \(httpResponse.statusCode)"])
        }
        
        print("✅ SupabaseService: Upload successful!")
    }
    
    func saveGalleryUpload(storagePath: String, fileName: String, fileSize: Int64, mimeType: String, width: Int?, height: Int?) async throws {
        print("💾 SupabaseService: Saving to database...")
        let userId = try await currentUserId()
        print("👤 User ID: \(userId)")
        
        struct NewUpload: Encodable {
            let user_id: UUID
            let storage_path: String
            let file_name: String
            let file_size: Int64
            let mime_type: String
            let width: Int?
            let height: Int?
        }
        
        let newUpload = NewUpload(
            user_id: userId,
            storage_path: storagePath,
            file_name: fileName,
            file_size: fileSize,
            mime_type: mimeType,
            width: width,
            height: height
        )
        
        print("📝 Upload data: \(newUpload)")
        
        _ = try await client.from("gallery_uploads").insert(newUpload).execute()
        print("✅ SupabaseService: Database save successful!")
    }
    
    func getGalleryUploads() async throws -> [GalleryUpload] {
        let userId = try await currentUserId()
        
        let uploads: [GalleryUpload] = try await client
            .from("gallery_uploads")
            .select("*")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute().value
        
        return uploads
    }
    
    func getSignedImageURL(storagePath: String) async throws -> String {
        let url = try await client.storage
            .from("user-uploads")
            .createSignedURL(path: storagePath, expiresIn: 3600)
        
        return url.absoluteString
    }
}

struct CalendarEntry {
    let id: UUID
    let imageId: UUID
    let createdByUserId: UUID
    let isFromPartner: Bool
}

// MARK: - Gallery Uploads
struct GalleryUpload: Decodable {
    let id: UUID
    let user_id: UUID
    let storage_path: String
    let file_name: String
    let file_size: Int64
    let mime_type: String
    let width: Int?
    let height: Int?
    let created_at: String
    let updated_at: String
}

struct CustomSignedUploadURL {
    let signedURL: String
    let path: String
    let token: String
}



