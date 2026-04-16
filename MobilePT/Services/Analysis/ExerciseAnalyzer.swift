import Foundation

protocol ExerciseAnalyzer {
    var exerciseName: String { get }
    var state: ExerciseState { get }

    mutating func analyze(pose: BodyPose) -> [FeedbackMessage]
    mutating func reset()
}
