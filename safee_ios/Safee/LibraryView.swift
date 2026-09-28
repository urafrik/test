import SwiftUI
import AVKit

struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var files: [URL] = []
    @State private var deleteTarget: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if files.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "folder").font(.largeTitle)
                        Text("还没有记录").font(.headline)
                        Text("拍摄或录音后，文件会显示在这里。")
                    }.padding(.vertical, 30)
                }
                ForEach(files, id: \.self) { file in
                    NavigationLink {
                        FilePreview(file: file)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: file.pathExtension == "jpg" ? "photo" : file.pathExtension == "mov" ? "video" : "waveform")
                                .foregroundStyle(.mint)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(file.lastPathComponent).lineLimit(1)
                                Text(file.pathExtension.uppercased()).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 7)
                    }
                    .swipeActions { Button("删除", role: .destructive) { deleteTarget = file } }
                }
            }
            .navigationTitle("本地文件")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onAppear(perform: reload)
            .refreshable { reload() }
            .alert("永久删除这个文件？", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
                Button("删除", role: .destructive) {
                    if let file = deleteTarget {
                        do { try FileManager.default.removeItem(at: file); reload() }
                        catch { self.error = error.localizedDescription }
                    }
                    deleteTarget = nil
                }
                Button("取消", role: .cancel) { deleteTarget = nil }
            }
            .alert("文件操作失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func reload() {
        do {
            files = try FileManager.default.contentsOfDirectory(at: CaptureController.directory, includingPropertiesForKeys: nil)
                .filter { ["jpg", "mov", "m4a"].contains($0.pathExtension) }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch { self.error = error.localizedDescription }
    }
}

struct FilePreview: View {
    let file: URL
    @State private var player: AVPlayer?
    var body: some View {
        Group {
            if file.pathExtension == "jpg", let image = UIImage(contentsOfFile: file.path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                VideoPlayer(player: player)
                    .onAppear { player = AVPlayer(url: file) }
                    .onDisappear { player?.pause(); player = nil }
            }
        }
        .navigationTitle("预览").navigationBarTitleDisplayMode(.inline)
        .toolbar { ShareLink(item: file) { Label("导出", systemImage: "square.and.arrow.up") } }
    }
}
