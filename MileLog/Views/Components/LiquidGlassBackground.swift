//
//  LiquidGlassBackground.swift
//  MileLog
//
//  Created by Xing Di on 1/23/26.
//

import SwiftUI

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Floating orbs for liquid effect
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.purple.opacity(0.4))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 100)

            Circle()
                .fill(Color.pink.opacity(0.3))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: -50, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

#Preview {
    LiquidGlassBackground()
}
