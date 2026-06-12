import AVFoundation
import Foundation

/// One-way voice coaching: takes coaching text, asks OpenAI TTS to synthesize
/// natural Korean speech, and plays it back. No microphone, no WebSocket.
final class OpenAITTSService: NSObject, @unchecked Sendable {
    private let apiKey: String
    private let model = "gpt-4o-mini-tts"
    /// 목소리. gpt-4o-mini-tts 지원: alloy, ash, ballad, coral, echo, fable,
    /// nova, onyx, sage, shimmer, verse, marin, cedar. (OpenAI 권장: marin / cedar)
    private let voice = "marin"

    private var player: AVAudioPlayer?
    private let urlSession = URLSession(configuration: .default)
    private var currentTask: URLSessionDataTask?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        configureAudioSession()
    }

    /// Whether a key is available — used to surface a warning in the UI.
    var isConfigured: Bool { !apiKey.isEmpty }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
    }

    func speak(_ text: String) {
        guard !apiKey.isEmpty,
              let url = URL(string: "https://api.openai.com/v1/audio/speech") else { return }

        // Latest coaching wins — cancel any in-flight synthesis.
        currentTask?.cancel()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "voice": voice,
            "input": text,
            "response_format": "mp3",
            "speed": 1.1,
            "instructions": "힘차고 활기찬 헬스 트레이너 말투로, 짧고 명확하게 말해줘."
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = urlSession.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            if let error = error as NSError?, error.code == NSURLErrorCancelled { return }
            guard let data, error == nil else {
                print("[OpenAITTS] request failed: \(error?.localizedDescription ?? "no data")")
                return
            }
            DispatchQueue.main.async { self.play(data) }
        }
        currentTask = task
        task.resume()
    }

    private func play(_ data: Data) {
        do {
            player?.stop()
            player = try AVAudioPlayer(data: data)
            player?.play()
        } catch {
            print("[OpenAITTS] playback failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        currentTask?.cancel()
        player?.stop()
    }
}
