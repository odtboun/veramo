import SwiftUI

struct TodayView: View {
    @State private var todaysImage: String? = nil
    @State private var streakCount = 7
    @State private var hasMemory = false
    @State private var showingAddMemory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with streak
                    VStack(spacing: 16) {
                        
                        // Streak counter with liquid glass
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(streakCount) day streak")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.top)
                    
                    // Today's memory
                    VStack(spacing: 16) {
                        Text("Today's Memory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if hasMemory, let imageUrl = todaysImage {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    }
                            }
                            .frame(maxWidth: 300)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        } else {
                            // Empty state - Cute and inviting
                            VStack(spacing: 24) {
                                // Cute heart icon with sparkles
                                ZStack {
                                    Circle()
                                        .fill(.pink.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.pink)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16))
                                            .foregroundColor(.yellow)
                                            .offset(x: 20, y: -10)
                                    }
                                }
                                
                                VStack(spacing: 12) {
                                    Text("No Memory Today")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Capture a special moment and create your first memory together! 💕")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                }
                                
                                // Cute decorative elements
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.blue.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.pink.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(.purple.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: 320)
                            .background {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.pink.opacity(0.3), .blue.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: .pink.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingAddMemory = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Today's Memory")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
                Task { await loadTodaysMemory() }
            }
            .sheet(isPresented: $showingAddMemory) {
                AddMemoryView()
            }
        }
    }
    
    private func loadTodaysMemory() async {
        do {
            print("🏠 TodayView: Loading today's memory...")
            
            // Priority system for Today view:
            // 1. Partner's upload for today
            // 2. Partner's latest upload (any date)
            // 3. Your latest upload
            // 4. No memory
            
            let today = Date()
            let userId = try await SupabaseService.shared.currentUserId()
            print("👤 User ID: \(userId)")
            
            // Get today's entries
            let todaysEntries = try await SupabaseService.shared.getCalendarEntries(for: today)
            let partnerTodaysEntries = todaysEntries.filter { $0.isFromPartner }
            print("📅 Today's entries: \(todaysEntries.count), Partner entries: \(partnerTodaysEntries.count)")
            
            if let partnerTodayEntry = partnerTodaysEntries.first {
                // Priority 1: Partner's upload for today
                print("🎯 Found partner's today entry: \(partnerTodayEntry.imageData)")
                if let storagePath = partnerTodayEntry.imageData["storage_path"] as? String {
                    let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: storagePath)
                    print("✅ Partner's today image URL: \(imageUrl)")
                    await MainActor.run {
                        self.todaysImage = imageUrl
                        self.hasMemory = true
                    }
                    return
                }
            }
            
            // Priority 2: Partner's latest upload (any date)
            let couple = await SupabaseService.shared.fetchCouple()
            print("💑 Couple: \(couple?.id ?? UUID())")
            if let couple = couple {
                // Get all partner entries
                struct CalendarEntryRow: Decodable {
                    let id: UUID
                    let image_data: [String: String]
                    let created_by_user_id: UUID
                    let date: String
                }
                
                let allEntries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date")
                    .eq("couple_id", value: couple.id)
                    .neq("created_by_user_id", value: userId)
                    .order("date", ascending: false)
                    .execute().value
                
                print("📊 Partner entries found: \(allEntries.count)")
                if let latestPartnerEntry = allEntries.first {
                    print("🎯 Latest partner entry: \(latestPartnerEntry.image_data)")
                    if let path = latestPartnerEntry.image_data["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: path)
                        print("✅ Partner's latest image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        return
                    }
                }
            }
            
            // Priority 3: Your latest upload
            if let couple = couple {
                struct CalendarEntryRow: Decodable {
                    let id: UUID
                    let image_data: [String: String]
                    let created_by_user_id: UUID
                    let date: String
                }
                
                let myEntries: [CalendarEntryRow] = try await SupabaseService.shared.client
                    .from("calendar_entries")
                    .select("id, image_data, created_by_user_id, date")
                    .eq("couple_id", value: couple.id)
                    .eq("created_by_user_id", value: userId)
                    .order("date", ascending: false)
                    .execute().value
                
                print("📊 My entries found: \(myEntries.count)")
                if let myLatestEntry = myEntries.first {
                    print("🎯 My latest entry: \(myLatestEntry.image_data)")
                    if let path = myLatestEntry.image_data["storage_path"] {
                        let imageUrl = try await SupabaseService.shared.getSignedImageURL(storagePath: path)
                        print("✅ My latest image URL: \(imageUrl)")
                        await MainActor.run {
                            self.todaysImage = imageUrl
                            self.hasMemory = true
                        }
                        return
                    }
                }
            }
            
            // Priority 4: No memory
            print("❌ No memory found - showing empty state")
            await MainActor.run {
                self.hasMemory = false
                self.todaysImage = nil
            }
            
        } catch {
            print("❌ Failed to load today's memory: \(error)")
            await MainActor.run {
                self.hasMemory = false
                self.todaysImage = nil
            }
        }
    }
}

#Preview {
    TodayView()
}
