import SwiftUI

struct ContentView: View {

    @StateObject private var store = DeviceStore()

    @State private var showAddDevice = false
    @State private var editDevice: Device?

    var body: some View {

        NavigationStack {

            List {

                ForEach(store.devices) { device in

                    NavigationLink {

                        DeviceDetailView(device: device)
                            .environmentObject(store)

                    } label: {

                        DeviceRow(
                            device: device,
                            status: store.statuses[device.id] ?? .idle
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                        Button {

                            editDevice = device

                        } label: {

                            VStack {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                            .frame(width: 70)
                        }
                        .tint(.blue)

                        Button(role: .destructive) {

                            if let index = store.devices.firstIndex(where: { $0.id == device.id }) {
                                store.delete(at: IndexSet(integer: index))
                            }

                        } label: {

                            VStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .frame(width: 70)
                        }
                    }
                }
                .onDelete(perform: store.delete)
            }
            .navigationTitle("Wlan")
            .toolbar {

                Button {
                    showAddDevice = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddDevice) {

                DeviceFormView(mode: .add) {
                    store.add($0)
                }
            }
            .sheet(item: $editDevice) { device in

                DeviceFormView(mode: .edit(device)) {
                    store.update($0)
                }
            }
            .refreshable {
                await store.refreshAllStatuses()
            }
            .task {
                await store.refreshAllStatuses()
            }
        }
    }
}
