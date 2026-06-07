import SwiftUI

struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: song.coverArtUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Theme.spiderDarkGrey
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .shadow(color: isPlaying ? Theme.spiderNeonRed.opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(isPlaying ? Theme.spiderNeonRed : .white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
            
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(Theme.spiderNeonRed)
            } else {
                Text(formatTime(song.durationMs))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Download button
            if downloadManager.isDownloaded(songId: song.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.spiderNeonRed)
            } else if let progress = downloadManager.activeDownloads[song.id] {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.spiderNeonRed))
                    .frame(width: 20, height: 20)
            } else {
                Button(action: {
                    downloadManager.download(song: song)
                }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Theme.spiderNeonRed.opacity(0.5) : Theme.spiderDarkGrey, lineWidth: 1)
        )
    }
    
    private func formatTime(_ ms: Int?) -> String {
        guard let ms = ms else { return "--:--" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
