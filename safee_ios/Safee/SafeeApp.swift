import SwiftUI
import AVKit
import Combine

@main
struct SafeeApp: App {
    var body: some Scene { WindowGroup { HomeView() } }
}

struct HomeView: View {
    @StateObject private var capture = CaptureController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode = 0
    @State private var black = false
    @State private var showLibrary = false
    @State private var showDiagnostics = false
    @State private var elapsed = 0
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.065, blue: 0.11).ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Safee Studio").font(.title.bold())
                        Text("本地记录 · 由你掌控").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showDiagnostics = true } label: {
                        Image(systemName: "stethoscope").font(.title2)
                    }.accessibilityLabel("诊断和日志")
                    Button { showLibrary = true } label: {
                        Image(systemName: "folder").font(.title2)
                    }.accessibilityLabel("本地文件").disabled(capture.busy)
                }
                Picker("记录方式", selection: $mode) {
                    Text("录音").tag(0)
                    Text("拍照").tag(1)
                    Text("录像").tag(2)
                }.pickerStyle(.segmented).disabled(capture.busy)

                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.05))
                    if mode == 0 {
                        VStack(spacing: 24) {
                            Image(systemName: capture.recording ? "waveform" : "mic")
                                .font(.system(size: 70)).foregroundStyle(.mint)
                            Text(capture.recording ? "正在录音" : "准备记录声音").font(.title3)
                            Text(duration).font(.system(size: 40, weight: .light, design: .monospaced))
                            Text("此版本录制麦克风声音").font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        CameraPreview(session: capture.session).clipShape(RoundedRectangle(cornerRadius: 28))
                        VStack {
                            HStack {
                                Label(capture.recording ? "录制中  \(duration)" : "相机预览", systemImage: capture.recording ? "record.circle" : "camera")
                                    .padding(10).background(.black.opacity(0.6), in: Capsule())
                                Spacer()
                            }
                            Spacer()
                        }.padding()
                    }
                }.frame(maxHeight: .infinity)

                Text(capture.status).font(.footnote).foregroundStyle(.secondary)
                    .frame(minHeight: 36).multilineTextAlignment(.center)
                HStack(spacing: 32) {
                    Button { capture.switchCamera() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title2)
                    }.disabled(mode == 0 || capture.busy || !capture.cameraReady)
                    Button {
                        if capture.recording { capture.stop() }
                        else if mode == 0 { elapsed = 0; Task { await capture.startAudio() } }
                        else if mode == 1 { capture.takePhoto() }
                        else { elapsed = 0; capture.startVideo() }
                    } label: {
                        Image(systemName: capture.recording ? "stop.fill" : (mode == 1 ? "camera.fill" : "record.circle"))
                            .font(.system(size: 32)).foregroundStyle(.black)
                            .frame(width: 82, height: 82).background(.mint, in: Circle())
                    }.disabled(capture.transitioning || (mode != 0 && !capture.cameraReady))
                    Button { black = true } label: {
                        Image(systemName: "moon.fill").font(.title2)
                    }.accessibilityLabel("黑色界面，双击恢复")
                }
                Text("黑色界面：双击恢复；拍照模式单击拍照\n请在获得参与者同意后录制")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(24)
            if black {
                Color.black.ignoresSafeArea()
                    .onTapGesture(count: 2) { black = false }
                    .onTapGesture(count: 1) { if mode == 1 { capture.takePhoto() } }
                    .accessibilityLabel("黑色界面")
                    .accessibilityAction(named: Text("恢复界面")) { black = false }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(black)
        .sheet(isPresented: $showLibrary) { LibraryView() }
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        .onChange(of: mode) { value in
            capture.shutdown()
            if value != 0 { Task { await capture.prepareCamera() } }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { capture.shutdown(); black = false }
            else if mode != 0 { Task { await capture.prepareCamera() } }
        }
        .onChange(of: capture.recording) { active in UIApplication.shared.isIdleTimerDisabled = active }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               value == AVAudioSession.InterruptionType.began.rawValue {
                capture.shutdown(); black = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification)) { _ in
            capture.shutdown(); black = false
        }
        .onReceive(clock) { _ in if capture.recording { elapsed += 1 } }
    }

    private var duration: String { String(format: "%02d:%02d", elapsed / 60, elapsed % 60) }
}

final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        let layer = view.layer as! AVCaptureVideoPreviewLayer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {}
}
