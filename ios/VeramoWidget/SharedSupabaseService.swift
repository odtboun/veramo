import Foundation
import Supabase

class SharedSupabaseService {
    static let shared = SharedSupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        // Use the same Supabase configuration as the main app
        let supabaseURL = URL(string: "https://nywdksjdepnyjdnshrhf.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55d2Rrc2pkZXBueWpkbnNocmhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5NzQ4NzQsImV4cCI6MjA1MTU1MDg3NH0.8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q8Q"
        
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    // Get the current user session (shared with main app)
    func getCurrentUser() async -> UUID? {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            print("❌ Widget: No user session found")
            return nil
        }
    }
    
    func getSignedImageURL(storagePath: String) async throws -> String {
        let url = try await client.storage.from("user-uploads").getPublicURL(path: storagePath)
        return url.absoluteString
    }
    
    func fetchCouple() async -> Couple? {
        do {
            let session = try await client.auth.session
            let userId = session.user.id
            
            let couples: [Couple] = try await client
                .from("couples")
                .select("id, user1_id, user2_id, is_active")
                .or("user1_id.eq.\(userId),user2_id.eq.\(userId)")
                .eq("is_active", value: true)
                .execute().value
            
            return couples.first
        } catch {
            print("❌ Failed to fetch couple: \(error)")
            return nil
        }
    }
}

struct Couple: Decodable {
    let id: UUID
    let user1_id: UUID
    let user2_id: UUID
    let is_active: Bool
}
