import SwiftUI
import AVFoundation

final class DiagnosticLog {
    static let shared = DiagnosticLog()
    private let queue = DispatchQueue(label: "studio.diagnostics")
    private let location: URL
    private var events: [[String: String]] = []

    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        location = folder.appendingPathComponent("events.json")
        if let data = try? Data(contentsOf: location),
           let existing = try? JSONDecoder().decode([[String: String]].self, from: data) {
            events = Array(existing.suffix(200))
        }
        record("诊断初始化")
    }

    func record(_ message: String) {
        queue.async {
            self.events.append(["time": ISO8601DateFormatter().string(from: Date()), "message": message])
            self.events = Array(self.events.suffix(200))
            if let data = try? JSONEncoder().encode(self.events) {
                try? data.write(to: self.location, options: [.atomic, .completeFileProtection])
            }
        }
    }

    func export() throws -> URL {
        let snapshot = queue.sync { events }
        let report: [String: Any] = [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "ios_version": UIDevice.current.systemVersion,
            "camera_permission": AVCaptureDevice.authorizationStatus(for: .video).rawValue,
            "microphone_permission": AVCaptureDevice.authorizationStatus(for: .audio).rawValue,
            "events": snapshot,
            "note": "No media, phone numbers or contact data are included."
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("safee-diagnostics-\(UUID().uuidString.prefix(8)).json")
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }
}

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var file: URL?
    @State private var message = "正在生成诊断信息…"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("反馈问题时请附上操作步骤、iPhone 型号和诊断文件。文件只包含版本、权限与事件日志。")
                    if let file {
                        ShareLink(item: file) { Label("导出诊断 JSON", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.borderedProminent)
                    }
                    Text(message).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }.padding()
            }
            .navigationTitle("诊断和日志")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task {
                do {
                    let result = try DiagnosticLog.shared.export()
                    message = try String(contentsOf: result, encoding: .utf8)
                    file = result
                } catch { message = "导出失败：\(error.localizedDescription)" }
            }
        }
    }
}
