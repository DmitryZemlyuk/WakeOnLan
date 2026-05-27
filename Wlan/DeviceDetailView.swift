import SwiftUI

struct DeviceDetailView: View {
    let device: Device
    
    @EnvironmentObject var store: DeviceStore
    
    private var wakeState: WakeState {
        store.statuses[device.id] ?? .idle
    }
    @State private var logEntries: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id = UUID()
        let time: String
        let message: String
        let isSuccess: Bool
    }

    var body: some View {
        List {
            // Device info
            Section {
                LabeledContent(String(localized: "form.field.name")) {
                    Text(device.name).foregroundStyle(.secondary)
                }
                LabeledContent("MAC") {
                    Text(device.mac.uppercased()).foregroundStyle(.secondary).monospaced()
                }
                LabeledContent(String(localized: "device.port.label")) {
                    Text("\(device.port)").foregroundStyle(.secondary).monospaced()
                }
                LabeledContent(String(localized: "device.broadcast.label")) {
                    Text(device.broadcast).foregroundStyle(.secondary).monospaced()
                }
            }

            // Wake button
            Section {
                Button {
                    Task { await wake() }
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            wakeState == .waking
                                ? String(localized: "device.wake.button.waking")
                                : String(localized: "device.wake.button"),
                            systemImage: wakeState == .waking ? "arrow.trianglehead.clockwise" : "power"
                        )
                        .foregroundStyle(.white)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(wakeState == .waking)
                .tint(wakeTint)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Status
            Section {
                HStack {
                    Text(String(localized: "device.status.title"))
                    Spacer()
                    statusBadge
                }
            }

            // Log
            if !logEntries.isEmpty {
                Section(String(localized: "device.log.title")) {
                    ForEach(logEntries.suffix(6)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(entry.time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospaced()
                                .frame(width: 42, alignment: .leading)
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(entry.isSuccess ? .green : .secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch wakeState {
        case .idle:
            Label(String(localized: "device.status.idle"), systemImage: "circle")
                .foregroundStyle(.secondary)
        case .waking:
            Label(String(localized: "device.status.waking"), systemImage: "arrow.trianglehead.clockwise")
                .foregroundStyle(.orange)
                .symbolEffect(.rotate)
        case .success:
            Label(String(localized: "device.status.success"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label(
                String(localized: "device.status.failed"),
                systemImage: "xmark.circle.fill"
            )
        }
    }

    private var wakeTint: Color {
        switch wakeState {
        case .idle:    return .accentColor
        case .waking: return .orange
        case .success: return .green
        case .failed: return .red
        }
    }

    private func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func wake() async {
        await MainActor.run {
            withAnimation {
                store.statuses[device.id] = .waking
            }
        }
        logEntries.append(LogEntry(time: timeString(),
            message: String(localized: "device.log.waking"), isSuccess: false))

        if let b = WakeOnLANSender.detectBroadcast() {
            logEntries.append(LogEntry(time: timeString(),
                message: "Broadcast: \(b)", isSuccess: true))
        }

        do {
            try await WakeOnLANSender.send(mac: device.mac, port: UInt16(Int(device.port) ?? 9), broadcast: device.broadcast)
            await MainActor.run {
                withAnimation {
                    store.statuses[device.id] = .success
                    logEntries.append(LogEntry(
                        time: timeString(),
                        message: String(format: String(localized: "device.log.success"), "\(device.port)"),
                        isSuccess: true))
                }
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { withAnimation { store.statuses[device.id] = .idle } }
        } catch {
            await MainActor.run {
                withAnimation {
                    store.statuses[device.id] = .failed(error.localizedDescription)
                    logEntries.append(LogEntry(time: timeString(),
                        message: error.localizedDescription, isSuccess: false))
                }
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { withAnimation { store.statuses[device.id] = .idle } }
        }
    }
}
