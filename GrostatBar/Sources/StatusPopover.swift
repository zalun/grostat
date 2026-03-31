import SwiftUI

struct StatusPopover: View {
    let reading: InverterReading?
    let config: BarConfig
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let r = reading {
                header(r)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        dcSection(r)
                        acSection(r)
                        tempSection(r)
                        energySection(r)
                        diagSection(r)
                    }
                    .padding(12)
                }
            } else {
                noData
            }
            Divider()
            footer
        }
        .frame(width: 300, height: 460)
    }

    // MARK: - Header

    private func header(_ r: InverterReading) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(config.deviceSn.isEmpty ? "Growatt" : config.deviceSn)
                    .font(.headline)
                Text(r.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            statusBadge(r)
        }
        .padding(12)
    }

    private func statusBadge(_ r: InverterReading) -> some View {
        let state = InverterState.from(reading: r, config: config)
        let label: String
        let color: Color
        switch state {
        case .sleep: label = "SLEEP"; color = .gray
        case .cloudy: label = "CLOUDY"; color = .blue
        case .producing: label = "OK"; color = .green
        case .onFire: label = "ON FIRE"; color = .orange
        case .fault: label = "FAULT"; color = .red
        case .offline: label = "OFFLINE"; color = .gray
        }
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    // MARK: - Sections

    private func dcSection(_ r: InverterReading) -> some View {
        Section("DC Input") {
            row("PPV", f1(r.ppv), "W")
            row("String 1", "\(f1(r.vpv1))V  \(f1(r.ipv1))A  \(f1(r.ppv1))W")
            row("String 2", "\(f1(r.vpv2))V  \(f1(r.ipv2))A  \(f1(r.ppv2))W")
            row("Today", "\(f1(r.epv1Today)) + \(f1(r.epv2Today))", "kWh")
        }
    }

    private func acSection(_ r: InverterReading) -> some View {
        Section("AC Grid") {
            row("PAC", f1(r.pac), "W")
            row("Phase R", "\(f1(r.vacrPhase))V  \(f1(r.iacr))A  \(f1(r.pacr))W")
            row("Phase S", "\(f1(r.vacsPhase))V  \(f1(r.iacs))A  \(f1(r.pacs))W")
            row("Phase T", "\(f1(r.vactPhase))V  \(f1(r.iact))A  \(f1(r.pact))W")
            row("Vmax", f1(r.vmaxPhase), "V")
            row("PF", f2(r.pf), "")
            row("Freq", f2(r.fac), "Hz")
        }
    }

    private func tempSection(_ r: InverterReading) -> some View {
        Section("Temperature") {
            row("Inverter", f1(r.temperature), "°C")
            row("IPM", f1(r.ipmTemperature), "°C")
        }
    }

    private func energySection(_ r: InverterReading) -> some View {
        Section("Energy") {
            row("Today", f1(r.powerToday), "kWh")
            row("Total", f1(r.powerTotal), "kWh")
            row("Hours", f0(r.timeTotal), "h")
        }
    }

    private func diagSection(_ r: InverterReading) -> some View {
        Section("Diagnostics") {
            row("Status", "\(r.status)", "")
            row("Fault", "\(r.faultType)", "")
            row("Warn", "\(r.warnCode)", "")
            row("DC Bus +/-", "\(f1(r.pBusVoltage))/\(f1(r.nBusVoltage))", "V")
            row("Power limit", f1(r.realOpPercent), "%")
        }
    }

    // MARK: - No data

    private var noData: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No data")
                .font(.headline)
            Text("Is 'grostat collect' running?")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { onQuit() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(8)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String, _ unit: String = "") -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(unit.isEmpty ? value : "\(value) \(unit)")
                .font(.system(.body, design: .monospaced))
        }
        .font(.caption)
    }

    private func f0(_ v: Double) -> String { String(format: "%.0f", v) }
    private func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    private func f2(_ v: Double) -> String { String(format: "%.2f", v) }
}

// MARK: - Section helper

private struct Section<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content
        }
    }
}
