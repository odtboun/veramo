import SwiftUI
import AVFoundation

struct CouplePodcastView: View {
    @State private var informationText: String = ""
    @State private var isGenerating: Bool = false
    @State private var resultAudioURL: URL? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Couple Podcast")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        Text("Generate personalized audio conversations about your relationship")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2), lineWidth: 1))
                                .frame(minHeight: 100)
                            if informationText.isEmpty {
                                Text("Share details about your relationship, recent experiences, or topics you'd like to discuss...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            TextField("", text: $informationText, axis: .vertical)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.clear)
                                .focused($isTextFieldFocused)
                        }
                    }
                    
                    Button(action: { generatePodcast() }) {
                        HStack {
                            if isGenerating {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                            } else {
                                Image(systemName: "waveform").font(.title2)
                            }
                            Text(isGenerating ? "Generating Podcast..." : "Generate Podcast").font(.headline.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                    }
                    .disabled(isGenerating || informationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity((isGenerating || informationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1.0)
                    
                    if let audioURL = resultAudioURL {
                        AudioPlayerView(
                            audioURL: audioURL,
                            audioPlayer: $audioPlayer,
                            isPlaying: $isPlaying,
                            currentTime: $currentTime,
                            duration: $duration,
                            timer: $timer
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .onTapGesture { isTextFieldFocused = false }
    }
    
    private func generatePodcast() {
        isGenerating = true
        isTextFieldFocused = false
        
        struct AudioInfo: Decodable { let url: String? }
        struct PodcastResponse: Decodable { let audio: AudioInfo?; let duration: Double?; let error: String? }
        
        guard let requestURL = URL(string: "https://veramo-podcast-228424037435.us-east1.run.app/generate-podcast") else {
            isGenerating = false; return
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["prompt": informationText]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                defer { self.isGenerating = false }
                guard error == nil, let data = data else { return }
                let decoder = JSONDecoder()
                guard let parsed = try? decoder.decode(PodcastResponse.self, from: data),
                      let audioURLString = parsed.audio?.url,
                      let remoteURL = URL(string: audioURLString) else { return }
                
                URLSession.shared.downloadTask(with: remoteURL) { tempURL, _, _ in
                    guard let tempURL = tempURL else { return }
                    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("couple_podcast.mp3")
                    try? FileManager.default.removeItem(at: destination)
                    do {
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                        DispatchQueue.main.async {
                            self.resultAudioURL = destination
                            do {
                                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                                try AVAudioSession.sharedInstance().setActive(true)
                                self.audioPlayer = try AVAudioPlayer(contentsOf: destination)
                                self.audioPlayer?.prepareToPlay()
                                self.duration = self.audioPlayer?.duration ?? (parsed.duration ?? 0)
                                self.currentTime = 0
                                self.isPlaying = false
                            } catch { }
                        }
                    } catch { }
                }.resume()
            }
        }.resume()
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    @Binding var timer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle.fill").font(.title2).foregroundColor(.pink)
                Text("Your Couple Podcast").font(.headline.bold()).foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Slider(value: $currentTime, in: 0...max(0.1, duration), onEditingChanged: { editing in
                        if !editing { audioPlayer?.currentTime = currentTime }
                    })
                    .accentColor(.pink)
                    HStack {
                        Text(formatTime(currentTime)).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(duration)).font(.caption).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 20) {
                    Button(action: { print("Download audio") }) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 30)).foregroundColor(.secondary)
                    }
                    Button(action: { playAudio() }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 50)).foregroundColor(.pink)
                    }
                    Button(action: { print("Share audio") }) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 30)).foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear { setupAudioPlayer() }
        .onDisappear { stopAudio() }
    }
    
    private func setupAudioPlayer() {
        if audioPlayer == nil {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.prepareToPlay()
            } catch { }
        }
        duration = audioPlayer?.duration ?? duration
        currentTime = audioPlayer?.currentTime ?? 0
    }
    
    private func playAudio() {
        guard let player = audioPlayer else { return }
        if currentTime > 0, abs(player.currentTime - currentTime) > 0.05 { player.currentTime = currentTime }
        if isPlaying { player.pause(); isPlaying = false; timer?.invalidate(); timer = nil; return }
        player.play()
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let p = audioPlayer else { return }
            currentTime = p.currentTime
            duration = p.duration
            if !p.isPlaying && currentTime >= duration - 0.05 { stopAudio() }
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate(); timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview { CouplePodcastView() }


