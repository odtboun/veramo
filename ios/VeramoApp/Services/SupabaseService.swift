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
            let couple: Couple? = try await client
                .from("couples")
                .select("id, user1_id, user2_id, is_active")
                .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
                .eq("is_active", value: true)
                .single()
                .execute().value
            return couple
        } catch { 
            print("Error fetching couple: \(error)")
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
}

struct CalendarEntry {
    let id: UUID
    let imageId: UUID
    let createdByUserId: UUID
    let isFromPartner: Bool
}



