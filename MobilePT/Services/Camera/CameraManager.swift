import AVFoundation
import Foundation
import UIKit

final class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.mobilept.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()

    @Published var cameraError: String?
    @Published var isAuthorized = false

    var onFrameCaptured: ((CMSampleBuffer, Int) -> Void)?
    var onConfigured: (() -> Void)?

    private var firstTimestampMs: Int?
    private var isConfigured = false
    private var orientationObserver: NSObjectProtocol?

    override init() {
        super.init()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.configure()
                    } else {
                        self?.cameraError = "카메라 접근이 거부되었습니다."
                    }
                }
            }
        default:
            cameraError = "카메라 접근이 거부되었습니다. 설정에서 허용해주세요."
        }
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setupSession()
            self.isConfigured = true
            DispatchQueue.main.async {
                self.onConfigured?()
            }
        }
    }

    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            DispatchQueue.main.async {
                self.cameraError = "전면 카메라를 사용할 수 없습니다."
            }
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard captureSession.canAddOutput(videoOutput) else {
            DispatchQueue.main.async {
                self.cameraError = "비디오 출력을 설정할 수 없습니다."
            }
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(videoOutput)

        updateVideoOrientation()

        captureSession.commitConfiguration()

        // Listen for orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.sessionQueue.async {
                self?.updateVideoOrientation()
            }
        }
    }

    func updateVideoOrientation() {
        guard let connection = videoOutput.connection(with: .video) else { return }

        let orientation = DispatchQueue.main.sync {
            UIDevice.current.orientation
        }

        if #available(iOS 17.0, *) {
            let angle: CGFloat
            switch orientation {
            case .landscapeLeft: angle = 0
            case .landscapeRight: angle = 180
            case .portraitUpsideDown: angle = 270
            default: angle = 90  // portrait
            }
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else {
            if connection.isVideoOrientationSupported {
                switch orientation {
                case .landscapeLeft: connection.videoOrientation = .landscapeRight
                case .landscapeRight: connection.videoOrientation = .landscapeLeft
                case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                default: connection.videoOrientation = .portrait
                }
            }
        }

        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.firstTimestampMs = nil
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let rawMs = Int(CMTimeGetSeconds(timestamp) * 1000)
        if firstTimestampMs == nil {
            firstTimestampMs = rawMs
        }
        let relativeMs = rawMs - (firstTimestampMs ?? 0)
        onFrameCaptured?(sampleBuffer, relativeMs)
    }
}
