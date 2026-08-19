import SwiftUI
import Charts

struct MLAnalyticsView: View {
    @State private var runs: [MLJobRun] = []
    @State private var isTriggering = false
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            ThemeManager.shared.currentTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // ── Trigger Button — always visible ──────────────────────
                    Button(action: triggerJob) {
                        HStack(spacing: 10) {
                            if isTriggering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isTriggering ? "Running Pipeline..." : "Run AI Analysis Now")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                .opacity(isTriggering ? 0.6 : 1.0)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                        .animation(.easeInOut(duration: 0.2), value: isTriggering)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .disabled(isTriggering || runs.first?.status == "Running")
                    
                    // ── Content ───────────────────────────────────────────────
                    if isLoading {
                        ProgressView("Loading Analytics...")
                            .padding(.top, 40)
                            .foregroundColor(.white)
                    } else if runs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 50))
                                .foregroundColor(.purple.opacity(0.5))
                            Text("No ML Jobs Run Yet")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("Tap the button above to run the AI pipeline\nand generate personalised recommendations.")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal)
                    } else {
                        // Top Stats Row
                        HStack(spacing: 16) {
                            let lastRun = runs.first!
                            StatCard(
                                title: "Status",
                                value: lastRun.status,
                                icon: lastRun.status == "Success" ? "checkmark.circle.fill" : (lastRun.status == "Running" ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill"),
                                color: lastRun.status == "Success" ? .green : (lastRun.status == "Running" ? .blue : .red)
                            )
                            
                            StatCard(
                                title: "Total Generated",
                                value: "\(runs.reduce(0) { $0 + $1.recommendations_generated })",
                                icon: "wand.and.stars",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                        
                        // Chart: Recommendations Over Time
                        VStack(alignment: .leading) {
                            Text("Recommendations Generated")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            Chart {
                                ForEach(Array(runs.suffix(10))) { run in
                                    BarMark(
                                        x: .value("Time", Date(timeIntervalSince1970: run.started_at), unit: .hour),
                                        y: .value("Count", run.recommendations_generated)
                                    )
                                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(4)
                                }
                            }
                            .frame(height: 200)
                            .padding()
                        }
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // History List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Runs")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(runs) { run in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formatDate(run.started_at))
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        if let completed = run.completed_at {
                                            Text(String(format: "Duration: %.1fs", completed - run.started_at))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(run.status)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                run.status == "Success" ? Color.green.opacity(0.2) :
                                                    (run.status == "Running" ? Color.blue.opacity(0.2) : Color.red.opacity(0.2))
                                            )
                                            .foregroundColor(
                                                run.status == "Success" ? .green :
                                                    (run.status == "Running" ? .blue : .red)
                                            )
                                            .cornerRadius(8)
                                        
                                        Text("\(run.recommendations_generated) recs")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("ML Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }
    
    private func loadData() {
        NetworkManager.shared.fetchMLMetrics { fetchedRuns in
            self.runs = fetchedRuns
            self.isLoading = false
        }
    }
    
    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func triggerJob() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        isTriggering = true
        NetworkManager.shared.triggerMLJob { success in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isTriggering = false
                self.loadData() // Reload to show it running
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
