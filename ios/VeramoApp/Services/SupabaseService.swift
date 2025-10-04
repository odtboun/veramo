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
        func addCalendarEntry(imageData: [String: String], scheduledDate: Date) async throws {
            print("🗓️ SupabaseService: Adding calendar entry...")
            let userId = try await currentUserId()
            print("👤 User ID: \(userId)")
            
            let couple = await fetchCouple()
            print("💑 Couple: \(couple?.id ?? UUID())")

            guard let couple = couple else {
                print("❌ No active couple found")
                throw NSError(domain: "NoCouple", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active couple found"])
            }

            struct NewEntry: Encodable {
                let couple_id: UUID
                let image_data: [String: String]
                let date: String
                let created_by_user_id: UUID
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: scheduledDate)
            
            print("📅 Date: \(dateString)")
            print("🖼️ Image Data: \(imageData)")
            print("💑 Couple ID: \(couple.id)")

            let newEntry = NewEntry(
                couple_id: couple.id,
                image_data: imageData,
                date: dateString,
                created_by_user_id: userId
            )
            
            print("📝 Entry data: \(newEntry)")

            _ = try await client.from("calendar_entries").insert(newEntry).execute()
            print("✅ Calendar entry created successfully!")
        }
    
        func getCalendarEntries(for date: Date) async throws -> [CalendarEntry] {
            let userId = try await currentUserId()
            let couple = await fetchCouple()

            guard let couple = couple else {
                return []
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)

            struct CalendarEntryRow: Decodable {
                let id: UUID
                let image_data: JSONValue
                let created_by_user_id: UUID
                let date: String
            }
            
            enum JSONValue: Decodable {
                case string(String)
                case number(Double)
                case bool(Bool)
                case null
                case object([String: JSONValue])
                case array([JSONValue])
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let string = try? container.decode(String.self) {
                        self = .string(string)
                    } else if let number = try? container.decode(Double.self) {
                        self = .number(number)
                    } else if let bool = try? container.decode(Bool.self) {
                        self = .bool(bool)
                    } else if container.decodeNil() {
                        self = .null
                    } else if let object = try? container.decode([String: JSONValue].self) {
                        self = .object(object)
                    } else if let array = try? container.decode([JSONValue].self) {
                        self = .array(array)
                    } else {
                        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
                    }
                }
                
                var stringValue: String {
                    switch self {
                    case .string(let value): return value
                    case .number(let value): return String(value)
                    case .bool(let value): return String(value)
                    case .null: return ""
                    case .object(_), .array(_): return ""
                    }
                }
            }

            let entries: [CalendarEntryRow] = try await client
                .from("calendar_entries")
                .select("id, image_data, created_by_user_id, date")
                .eq("couple_id", value: couple.id)
                .eq("date", value: dateString)
                .execute().value

            return entries.map { entry in
                // Convert image_data to [String: String] format
                let imageData: [String: String]
                switch entry.image_data {
                case .object(let dict):
                    imageData = dict.mapValues { $0.stringValue }
                default:
                    imageData = [:]
                }
                
                return CalendarEntry(
                    id: entry.id,
                    imageData: imageData,
                    createdByUserId: entry.created_by_user_id,
                    isFromPartner: entry.created_by_user_id != userId,
                    date: entry.date
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
        print("🔗 Getting signed URL for: \(storagePath)")
        
        // Try to get a public URL first
        let publicURL = try client.storage
            .from("user-uploads")
            .getPublicURL(path: storagePath)
        
        print("🌐 Public URL: \(publicURL.absoluteString)")
        return publicURL.absoluteString
    }
}

    struct CalendarEntry {
        let id: UUID
        let imageData: [String: String]
        let createdByUserId: UUID
        let isFromPartner: Bool
        let date: String
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



