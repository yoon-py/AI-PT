import SwiftUI
import UIKit

/// 짧게 터지는 컨페티 (운동 완료 축하용). 1.2초 분사 후 자연스럽게 멈춘다.
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterCells = makeCells()
        view.layer.addSublayer(emitter)
        context.coordinator.emitter = emitter
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let emitter = context.coordinator.emitter, !context.coordinator.started else { return }
        context.coordinator.started = true
        DispatchQueue.main.async {
            let w = uiView.bounds.width
            emitter.emitterPosition = CGPoint(x: w / 2, y: -12)
            emitter.emitterSize = CGSize(width: w, height: 1)
        }
        // 분사 멈춤 (이미 떨어진 조각은 계속 낙하)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            emitter.birthRate = 0
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        var emitter: CAEmitterLayer?
        var started = false
    }

    private func makeCells() -> [CAEmitterCell] {
        let colors: [UIColor] = [
            UIColor(Theme.accent), .systemPink, .systemYellow, .systemTeal, .white
        ]
        return colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 7
            cell.lifetime = 6
            cell.velocity = 190
            cell.velocityRange = 90
            cell.emissionLongitude = .pi          // 아래 방향
            cell.emissionRange = .pi / 5
            cell.spin = 3.5
            cell.spinRange = 4
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.contents = piece(color: color).cgImage
            return cell
        }
    }

    private func piece(color: UIColor) -> UIImage {
        let size = CGSize(width: 9, height: 14)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
