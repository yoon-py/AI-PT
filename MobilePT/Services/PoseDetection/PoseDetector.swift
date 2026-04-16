import AVFoundation
import MediaPipeTasksVision
import UIKit

final class PoseDetector: NSObject, @unchecked Sendable {
    private var poseLandmarker: PoseLandmarker?
    private var latestResult: BodyPose?
    private let lock = NSLock()

    /// Errors visible to UI for debugging
    private var _lastError: String?
    var lastError: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastError
    }

    private var _delegateCalled = false
    var delegateCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _delegateCalled
    }

    override init() {
        super.init()
        setupLandmarker()
    }

    private func setupLandmarker() {
        guard let modelPath = Bundle.main.path(
            forResource: "pose_landmarker_heavy",
            ofType: "task"
        ) else {
            _lastError = "Model file not found in bundle"
            print("[PoseDetector] \(_lastError!)")
            return
        }
        print("[PoseDetector] Model path: \(modelPath)")

        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.baseOptions.delegate = .CPU
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.poseLandmarkerLiveStreamDelegate = self

        do {
            poseLandmarker = try PoseLandmarker(options: options)
            print("[PoseDetector] PoseLandmarker created successfully")
        } catch {
            _lastError = "Init failed: \(error.localizedDescription)"
            print("[PoseDetector] \(_lastError!)")
        }
    }

    var isReady: Bool { poseLandmarker != nil }

    func detectAsync(sampleBuffer: CMSampleBuffer, timestampMs: Int) {
        guard let poseLandmarker else { return }

        let image: MPImage
        do {
            image = try MPImage(sampleBuffer: sampleBuffer)
        } catch {
            lock.lock()
            _lastError = "MPImage failed: \(error.localizedDescription)"
            lock.unlock()
            return
        }

        do {
            try poseLandmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            lock.lock()
            _lastError = "detectAsync: \(error.localizedDescription)"
            lock.unlock()
        }
    }

    func getLatestPose() -> BodyPose? {
        lock.lock()
        defer { lock.unlock() }
        return latestResult
    }
}

extension PoseDetector: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        lock.lock()
        _delegateCalled = true

        if let error {
            _lastError = "delegate error: \(error.localizedDescription)"
            latestResult = nil
            lock.unlock()
            return
        }

        guard let result, let firstPose = result.landmarks.first, !firstPose.isEmpty else {
            _lastError = "no pose in result (landmarks count: \(result?.landmarks.count ?? -1))"
            latestResult = nil
            lock.unlock()
            return
        }

        _lastError = nil

        var lms: [(x: Float, y: Float, z: Float)] = []
        var vis: [Float] = []

        for landmark in firstPose {
            lms.append((x: landmark.x, y: landmark.y, z: landmark.z))
            vis.append(landmark.visibility?.floatValue ?? 0)
        }

        let pose = BodyPose(
            landmarks: lms,
            visibility: vis,
            timestamp: Double(timestampInMilliseconds) / 1000.0
        )

        latestResult = pose
        lock.unlock()
    }
}
