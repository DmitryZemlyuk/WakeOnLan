import SwiftUI

struct DeviceRow: View {

    let device: Device
    let status: WakeState

    var body: some View {

        HStack {

            VStack(alignment: .leading) {

                Text(device.name)
                    .font(.headline)

                Text(device.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(status.caption)
                .font(.caption.bold())
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {

        switch status {
        case .idle:
            return .secondary
        case .waking:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        }
    }
}
