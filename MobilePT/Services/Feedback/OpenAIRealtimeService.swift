import AVFoundation
import Foundation

final class OpenAIRealtimeService: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isConnected = false
    @Published var isSpeaking = false

    private let apiKey: String
    private let model = "gpt-4o-mini-realtime-preview"
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Audio capture
    private let audioEngine = AVAudioEngine()

    // Audio playback
    private let playerNode = AVAudioPlayerNode()
    private let playbackEngine = AVAudioEngine()
    private var playbackFormat: AVAudioFormat?

    // Pose context
    private var lastPoseContext: String = ""
    private var lastContextSendTime: Date = .distantPast

    private let lock = NSLock()

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    // MARK: - Connection

    func connect(exerciseType: String) {
        let urlString = "wss://api.openai.com/v1/realtime?model=\(model)"
        guard let url = URL(string: urlString) else { return }

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "OpenAI-Beta": "realtime=v1"
        ]

        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()

        // Wait for session.created, then send session.update
        startReceiving()

        let sessionUpdate: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": """
                    너는 전문 헬스 트레이너야. 한국어로만 대화해.
                    지금 사용자가 \(exerciseType) 운동을 하고 있어.

                    규칙:
                    - 짧고 힘차게 코칭해. 한 문장으로.
                    - 사용자가 말하면 대답해줘.
                    - 주기적으로 전달되는 포즈 데이터를 보고 자세 교정해줘.
                    - 격려도 해주고, 잘못된 자세는 바로 지적해.
                    - "무릎 더 벌려!", "등 펴!", "좋아 그렇지!" 이런 식으로.
                    - 너무 길게 말하지 마. 운동 중이니까.
                    - 처음 연결되면 카메라 위치 안내를 해줘:
                      - 스쿼트: "폰을 허리 높이에 세워두고, 측면 45도 각도로 전신이 보이게 해주세요"
                      - 푸쉬업: "폰을 바닥에 측면으로 세워서 전신이 나오게 해주세요"
                      - 플랭크: "폰을 바닥에 측면으로 세워서 전신이 나오게 해주세요"
                    - 카메라 각도가 안 좋아 보이면 (포즈 데이터가 부정확하면) 카메라 위치 조정을 권해줘.
                    - 푸쉬업할 때는 센서로 못 잡는 부분도 코칭해줘:
                      - "손가락 펴고 바닥을 단단히 잡으세요"
                      - "손목이 꺾이지 않게 주의하세요"
                      - "손바닥 전체로 바닥을 밀어주세요"
                      같은 팁을 적절한 타이밍에 알려줘.
                    """,
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "gpt-4o-mini-transcription"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ]
            ]
        ]

        sendJSON(sessionUpdate)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupAudio()
            self.isConnected = true
        }
    }

    func disconnect() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        playbackEngine.stop()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.isSpeaking = false
        }
    }

    // MARK: - Audio Setup

    private func setupAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        setupMicrophone()
        setupPlayback()
    }

    private func setupMicrophone() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // OpenAI Realtime API: 24kHz mono PCM 16-bit
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true) else { return }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("[OpenAIRealtime] Failed to create audio converter")
            return
        }

        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processInputBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            try audioEngine.start()
        } catch {
            print("[OpenAIRealtime] Failed to start audio engine: \(error)")
        }
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * 24000.0 / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, convertedBuffer.frameLength > 0 else { return }

        let audioData = Data(bytes: convertedBuffer.int16ChannelData![0],
                           count: Int(convertedBuffer.frameLength) * 2)
        let base64 = audioData.base64EncodedString()

        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64
        ]
        sendJSON(message)
    }

    private func setupPlayback() {
        // OpenAI outputs 24kHz PCM16
        playbackFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)
        guard let playbackFormat else { return }

        playbackEngine.attach(playerNode)
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)

        do {
            try playbackEngine.start()
            playerNode.play()
        } catch {
            print("[OpenAIRealtime] Failed to start playback engine: \(error)")
        }
    }

    // MARK: - Pose Context

    func updatePoseContext(_ context: String) {
        let now = Date()
        guard now.timeIntervalSince(lastContextSendTime) > 2.0 else { return }
        guard context != lastPoseContext else { return }

        lastPoseContext = context
        lastContextSendTime = now

        // Send pose data as a conversation item, then trigger a response
        let item: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [[
                    "type": "input_text",
                    "text": "[포즈 데이터] \(context)"
                ]]
            ]
        ]
        sendJSON(item)

        let respond: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["audio", "text"]
            ]
        ]
        sendJSON(respond)
    }

    // MARK: - WebSocket

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(string)) { error in
            if let error {
                print("[OpenAIRealtime] Send error: \(error.localizedDescription)")
            }
        }
    }

    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleResponse(text)
                default:
                    break
                }
                self?.startReceiving()

            case .failure(let error):
                print("[OpenAIRealtime] Receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }

    private func handleResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "response.audio.delta":
            if let delta = json["delta"] as? String {
                playAudio(base64: delta)
            }
            DispatchQueue.main.async {
                self.isSpeaking = true
            }

        case "response.audio.done":
            DispatchQueue.main.async {
                self.isSpeaking = false
            }

        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("[OpenAIRealtime] Error: \(message)")
            }

        case "session.created", "session.updated":
            print("[OpenAIRealtime] \(type)")

        default:
            break
        }
    }

    private func playAudio(base64: String) {
        guard let audioData = Data(base64Encoded: base64),
              let format = playbackFormat else { return }

        let frameCount = AVAudioFrameCount(audioData.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        audioData.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData![0], baseAddress, audioData.count)
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }
}
