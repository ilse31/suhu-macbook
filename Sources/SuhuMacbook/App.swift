import AppKit
import SwiftUI
import MonitorCore
import ServiceManagement

final class Monitor: ObservableObject {
    @Published var snapshot: Snapshot?
    let chipName: String
    var onUpdate: ((Snapshot) -> Void)?
    private let sampler = SystemSampler()
    private var timer: DispatchSourceTimer?

    init() { chipName = sampler.chipName }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "id.local.suhumac.sampling", qos: .utility))
        timer.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self, sampler] in
            let snapshot = sampler.sample()
            DispatchQueue.main.async { [weak self] in
                self?.snapshot = snapshot
                self?.onUpdate?(snapshot)
            }
        }
        self.timer = timer
        timer.resume()
    }

    deinit { timer?.cancel() }
}

struct MonitorPanel: View {
    @ObservedObject var monitor: Monitor
    @ObservedObject var loginItem: LoginItem
    private var snapshot: Snapshot? { monitor.snapshot }

    private var thermalColor: Color {
        switch snapshot?.thermalState {
        case "Normal": return .green
        case "Hangat": return .orange
        case "Panas", "Kritis": return .red
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suhu Mac").font(.system(size: 17, weight: .semibold))
                    Text(monitor.chipName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(snapshot?.thermalState ?? "Memuat", systemImage: "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(thermalColor)
                    .help("Status termal yang dilaporkan macOS")
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot?.cpuTemperature.map { String(format: "%.0f°C", $0) } ?? "—°C")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Suhu CPU")
                    Text(snapshot?.cpuTemperature == nil ? "Sensor suhu belum tersedia" : "Suhu CPU · sensor terpanas")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            }

            Divider()

            VStack(spacing: 18) {
                metricRow(title: "CPU", symbol: "cpu", value: snapshot?.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "—",
                          fraction: snapshot?.cpuPercent.map { $0 / 100 },
                          detail: "Beban seluruh core", color: .blue)

                metricRow(title: "RAM", symbol: "memorychip", value: snapshot?.memory.map { bytes($0.used) } ?? "—",
                          fraction: snapshot?.memory?.fraction,
                          detail: memoryDetail, color: memoryColor)

                metricRow(title: "Storage", symbol: "internaldrive", value: snapshot?.storage.map { bytes($0.available) + " kosong" } ?? "—",
                          fraction: snapshot?.storage?.fraction,
                          detail: snapshot?.storage.map { "\(bytes($0.used)) terpakai dari \(bytes($0.total))" } ?? "Volume belum terbaca",
                          color: .purple)
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Toggle("Jalankan saat login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .font(.system(size: 12))
                if let error = loginItem.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if loginItem.status == .requiresApproval {
                    Button("Izinkan di Pengaturan Sistem…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    .font(.caption)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pembaruan setiap 2 detik")
                    if let date = snapshot?.sampledAt {
                        Text(date, style: .time).monospacedDigit()
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("Keluar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(22)
        .frame(width: 350)
    }

    private var memoryDetail: String {
        guard let memory = snapshot?.memory else { return "RAM belum terbaca" }
        return "\(bytes(memory.available)) tersedia dari \(bytes(memory.total)) · \(snapshot?.memoryPressure ?? "Tekanan tidak tersedia")"
    }

    private var memoryColor: Color {
        switch snapshot?.memoryPressure {
        case "Tinggi": return .red
        case "Meningkat": return .orange
        default: return .teal
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .binary)
    }

    private func metricRow(title: String, symbol: String, value: String, fraction: Double?, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(value).font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            ProgressView(value: fraction ?? 0, total: 1)
                .tint(color)
                .opacity(fraction == nil ? 0.25 : 1)
                .accessibilityLabel("Penggunaan \(title)")
                .accessibilityValue(fraction.map { String(format: "%.0f persen", $0 * 100) } ?? "Belum tersedia")
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = Monitor()
    private let loginItem = LoginItem()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "Suhu Mac")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.title = " —°C"
            button.target = self
            button.action = #selector(togglePanel)
        }
        popover.behavior = .transient
        let controller = NSHostingController(rootView: MonitorPanel(monitor: monitor, loginItem: loginItem))
        popover.contentViewController = controller
        popover.contentSize = controller.view.fittingSize
        monitor.onUpdate = { [weak self] snapshot in
            guard let button = self?.statusItem.button else { return }
            button.title = snapshot.cpuTemperature.map { String(format: " %.0f°C", $0) } ?? " —°C"
            let cpu = snapshot.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "—"
            button.toolTip = "Suhu Mac · CPU \(cpu) · Termal \(snapshot.thermalState)"
        }
        monitor.start()
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            loginItem.refresh()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

@main
struct SuhuMacbookApp {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--enable-login") || arguments.contains("--disable-login") || arguments.contains("--login-status") {
            let loginItem = LoginItem()
            if !arguments.contains("--login-status") {
                loginItem.setEnabled(arguments.contains("--enable-login"))
            }
            print("Jalankan saat login: \(loginItem.statusDescription)")
            if let error = loginItem.errorMessage {
                fputs("\(error)\n", stderr)
                exit(1)
            }
            if loginItem.status == .requiresApproval { exit(2) }
        } else if arguments.contains("--diagnose") {
            let sampler = SystemSampler()
            _ = sampler.sample()
            Thread.sleep(forTimeInterval: 0.3)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(sampler.sample())
                print(String(decoding: data, as: UTF8.self))
            } catch {
                fputs("Diagnostik gagal: \(error)\n", stderr)
                exit(1)
            }
        } else {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let delegate = AppDelegate()
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}
