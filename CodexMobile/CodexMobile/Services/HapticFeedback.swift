// FILE: HapticFeedback.swift
// 用途：统一封装常见按钮交互的触觉反馈工具。
// Layer: Service
// Exports: HapticFeedback
// Depends on: UIKit

import UIKit

class HapticFeedback {
    static let shared = HapticFeedback()

    private init() {}

    // Uses the system notification generator for stateful success/failure cues.
    func triggerNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func triggerImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
