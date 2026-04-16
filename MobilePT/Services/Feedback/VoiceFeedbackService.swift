import AVFoundation

final class VoiceFeedbackService: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "ko-KR")

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
    }

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
}
