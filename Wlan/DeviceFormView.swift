import SwiftUI

enum FormMode {
    case add
    case edit(Device)
}

struct DeviceFormView: View {

    let mode: FormMode
    let onSave: (Device) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var mac = ""
    @State private var checkPort = "3389"
    @State private var port = "9"
    @State private var broadcast = "255.255.255.255"

    var body: some View {

        NavigationStack {

            Form {

                TextField("Name", text: $name)
                TextField("Host/IP", text: $host)
                TextField("MAC", text: $mac)
                TextField("Port", text: $port)
                TextField("Check Port", text: $checkPort)
                TextField("Broadcast", text: $broadcast)
            }
            .navigationTitle("Device")
            .toolbar {

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") {

                        let device = buildDevice()

                        onSave(device)

                        dismiss()
                    }
                }
            }
            .onAppear {

                if case .edit(let device) = mode {

                    name = device.name
                    host = device.host
                    mac = device.mac
                    port = device.port
                    checkPort = device.checkPort
                    broadcast = device.broadcast
                }
            }
        }
    }

    private func buildDevice() -> Device {

        switch mode {

        case .add:

            return Device(
                name: name,
                host: host,
                mac: mac,
                port: port,
                checkPort: checkPort,
                broadcast: broadcast
            )

        case .edit(let old):

            return Device(
                id: old.id,
                name: name,
                host: host,
                mac: mac,
                port: port,
                checkPort: checkPort,
                broadcast: broadcast
            )
        }
    }
}
