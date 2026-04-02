import SwiftUI

struct ServerPickerView: View {
    let servers: [DiscoveredServer]
    let onSelect: (DiscoveredServer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Server")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(servers) { server in
                Button(action: { onSelect(server) }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.hostname)
                                .font(.body)
                            if !server.deviceSn.isEmpty {
                                Text(server.deviceSn)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 260)
    }
}
