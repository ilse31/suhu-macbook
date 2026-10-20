import Combine
import Foundation
import ServiceManagement

final class LoginItem: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        refresh()
        do {
            guard Bundle.main.bundleURL.pathExtension == "app" else {
                throw NSError(domain: "SuhuMac", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Jalankan pengaturan ini dari Suhu Mac.app."
                ])
            }
            if enabled && !isEnabled {
                try SMAppService.mainApp.register()
            } else if !enabled && isEnabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    var statusDescription: String {
        switch status {
        case .enabled: return "Aktif"
        case .notRegistered: return "Nonaktif"
        case .requiresApproval: return "Perlu izin di Pengaturan Sistem"
        case .notFound: return "Aplikasi tidak ditemukan"
        @unknown default: return "Status tidak diketahui"
        }
    }
}
