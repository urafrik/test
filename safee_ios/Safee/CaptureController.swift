import AVFoundation
import Combine
import UIKit

final class CaptureController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, AVAudioRecorderDelegate {
    @Published var recording = false
    @Published var transitioning = false
    @Published var cameraReady = false
    @Published var status = "文件仅保存在此设备，卸载 App 会删除文件" {
        didSet { DiagnosticLog.shared.record(status) }
    }
    var busy: Bool { recording || transitioning }
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "studio.capture")
    private let photo = AVCapturePhotoOutput()
    private let movie = AVCaptureMovieFileOutput()
    private var audio: AVAudioRecorder?
    private var position: AVCaptureDevice.Position = .back

    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static func newFile(_ ext: String) -> URL {
        directory.appendingPathComponent("记录-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).\(ext)")
    }
    private func publish(_ operation: @escaping () -> Void) {
        DispatchQueue.main.async(execute: operation)
    }
    private func message(_ text: String) { publish { self.status = text } }

    func prepareCamera() async {
        let cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
        let microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard cameraAllowed else { message("请在系统设置中允许访问相机"); return }
        queue.async {
            guard !self.session.isRunning else { return }
            do {
                try self.configureCamera(includeAudio: microphoneAllowed)
                self.session.startRunning()
                self.publish {
                    self.cameraReady = true
                    self.status = microphoneAllowed ? "相机已就绪" : "麦克风未授权，录像将没有声音"
                }
            } catch { self.message("相机启动失败：\(error.localizedDescription)") }
        }
    }

    private func configureCamera(includeAudio: Bool) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw NSError(domain: "Camera", code: 1, userInfo: [NSLocalizedDescriptionKey: "设备没有可用相机"])
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw NSError(domain: "Camera", code: 2) }
        session.addInput(input)
        if includeAudio, let microphone = AVCaptureDevice.default(for: .audio) {
            let input = try AVCaptureDeviceInput(device: microphone)
            if session.canAddInput(input) { session.addInput(input) }
        }
        guard session.canAddOutput(photo), session.canAddOutput(movie) else {
            throw NSError(domain: "Camera", code: 3, userInfo: [NSLocalizedDescriptionKey: "设备不支持当前拍摄配置"])
        }
        session.addOutput(photo)
        session.addOutput(movie)
        if let connection = movie.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if let connection = photo.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    func switchCamera() {
        guard !busy else { return }
        transitioning = true
        queue.async {
            self.position = self.position == .back ? .front : .back
            do { try self.configureCamera(includeAudio: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized) }
            catch { self.message("切换失败：\(error.localizedDescription)") }
            self.publish { self.transitioning = false }
        }
    }

    func takePhoto() {
        guard cameraReady, !busy else { return }
        transitioning = true
        queue.async { self.photo.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { publish { self.transitioning = false } }
        if let error { message("拍照失败：\(error.localizedDescription)"); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.95) else {
            message("照片编码失败"); return
        }
        do { try jpeg.write(to: Self.newFile("jpg"), options: [.atomic, .completeFileProtection]); message("照片已保存到本地文件") }
        catch { message("保存失败：\(error.localizedDescription)") }
    }

    func startVideo() {
        guard cameraReady, !busy else { return }
        transitioning = true
        queue.async { self.movie.startRecording(to: Self.newFile("mov"), recordingDelegate: self) }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        publish { self.recording = true; self.transitioning = false; self.status = "正在录像" }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let saved = error == nil || (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        publish {
            self.recording = false; self.transitioning = false
            self.status = saved ? "录像已保存到本地文件" : "录像失败：\(error?.localizedDescription ?? "未知错误")"
        }
    }

    @MainActor func startAudio() async {
        guard !busy else { return }
        transitioning = true
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard allowed, UIApplication.shared.applicationState == .active else {
            transitioning = false; status = "请允许麦克风权限并保持 App 在前台"; return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            audio = try AVAudioRecorder(url: Self.newFile("m4a"), settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            audio?.delegate = self
            guard audio?.record() == true else { throw NSError(domain: "Audio", code: 1) }
            recording = true; transitioning = false; status = "正在录制麦克风声音"
        } catch { transitioning = false; status = "录音失败：\(error.localizedDescription)" }
    }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        publish {
            self.recording = false; self.transitioning = false
            self.status = flag ? "录音已保存到本地文件" : "录音被中断，文件可能不完整"
        }
    }
    func stop() {
        if let audio, audio.isRecording {
            transitioning = true
            audio.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        queue.async { if self.movie.isRecording { self.movie.stopRecording() } }
    }
    func shutdown() {
        stop()
        cameraReady = false
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }
}
