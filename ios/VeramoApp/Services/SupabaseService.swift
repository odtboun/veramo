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
    struct CoupleMember: Decodable { let couple_id: UUID }
    struct Profile: Decodable { let id: UUID }

    func currentProfileId() async throws -> UUID {
        let profile: Profile = try await client
            .from("profiles")
            .select("id")
            .eq("email", value: try await client.auth.session.user.email ?? "")
            .single()
            .execute().value
        return profile.id
    }

    func fetchCoupleId() async -> UUID? {
        do {
            let profileId = try await currentProfileId()
            let row: CoupleMember? = try await client
                .from("couple_members")
                .select("couple_id")
                .eq("profile_id", value: profileId)
                .single()
                .execute().value
            return row?.couple_id
        } catch { return nil }
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
        
        let profileId = try await currentProfileId()
        struct NewCode: Encodable { 
            let code: String
            let inviter_profile_id: UUID
            let expires_at: String
        }
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        _ = try await client.from("pairing_codes").insert(NewCode(
            code: code, 
            inviter_profile_id: profileId,
            expires_at: expiresAt
        )).execute()
        return code
    }

    func joinWithCode(_ code: String) async throws {
        struct CodeRow: Decodable { 
            let inviter_profile_id: UUID
            let couple_id: UUID?
        }
        let found: CodeRow = try await client
            .from("pairing_codes")
            .select("inviter_profile_id, couple_id")
            .eq("code", value: code)
            .single()
            .execute().value

        let myProfileId = try await currentProfileId()
        let partnerProfileId = found.inviter_profile_id

        let coupleId: UUID
        if let existingCoupleId = found.couple_id {
            coupleId = existingCoupleId
        } else {
            // Create new couple
            let newCoupleId = UUID()
            struct NewCouple: Encodable { let id: UUID }
            _ = try await client
                .from("couples")
                .insert(NewCouple(id: newCoupleId))
                .execute()
            coupleId = newCoupleId
            
            // Add partner to couple
            struct NewMember: Encodable { let couple_id: UUID; let profile_id: UUID }
            _ = try await client.from("couple_members").insert(NewMember(
                couple_id: coupleId, 
                profile_id: partnerProfileId
            )).execute()
        }

        // Add myself to couple
        struct NewMember: Encodable { let couple_id: UUID; let profile_id: UUID }
        _ = try await client.from("couple_members").insert(NewMember(
            couple_id: coupleId, 
            profile_id: myProfileId
        )).execute()
        
        // Mark code as redeemed
        _ = try await client.from("pairing_codes")
            .update([
                "redeemed_by_profile_id": myProfileId.uuidString,
                "redeemed_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("code", value: code)
            .execute()
    }

    func removePartner() async throws {
        let profileId = try await currentProfileId()
        let coupleId = try await fetchCoupleId()
        
        guard let coupleId = coupleId else { return }
        
        // Remove from couple_members (soft delete by removing the relationship)
        _ = try await client.from("couple_members")
            .delete()
            .eq("profile_id", value: profileId)
            .eq("couple_id", value: coupleId)
            .execute()
    }
}



