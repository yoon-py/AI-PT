# MobilePT (AI-PT)

iOS 기반 AI 퍼스널 트레이너 앱. 카메라로 운동 자세를 실시간 분석하고 AI 코치가 음성으로 피드백을 제공합니다.

## 주요 기능

- **실시간 자세 인식**: MediaPipe Pose Landmarker로 신체 관절 추적
- **운동 분석**: 스쿼트, 푸쉬업, 플랭크 자세 분석 및 카운팅
- **AI 음성 코칭**: OpenAI Realtime API 기반 실시간 음성 피드백
- **각도 기반 폼 체크**: 관절 각도 계산으로 자세 교정 가이드

## 기술 스택

- Swift / SwiftUI (iOS 16.0+)
- MediaPipe Tasks Vision (pose_landmarker_heavy)
- AVFoundation (카메라 캡처)
- OpenAI Realtime API (음성 피드백)

## 프로젝트 구조

```
MobilePT/
├── Models/          # BodyPose, ExerciseState, FeedbackMessage
├── Views/           # SwiftUI 뷰 (세션, 오버레이)
├── ViewModels/      # ExerciseViewModel
└── Services/
    ├── PoseDetection/   # MediaPipe 포즈 검출
    ├── Camera/          # 카메라 매니저/프리뷰
    ├── Analysis/        # 운동별 분석기 (스쿼트/푸쉬업/플랭크)
    └── Feedback/        # 음성 피드백 / OpenAI Realtime
```

## 빌드

XcodeGen으로 프로젝트 파일을 생성합니다.

```bash
xcodegen generate
open MobilePT.xcodeproj
```

`MobilePT/Resources/pose_landmarker_heavy.task` 모델 파일과 `Frameworks/` 하위 MediaPipe xcframework가 필요합니다.
