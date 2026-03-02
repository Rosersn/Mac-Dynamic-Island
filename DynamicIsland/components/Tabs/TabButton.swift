/*
 * Notchi (DynamicIsland)
 * Copyright (C) 2024-2026 Notchi Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Notchi (DynamicIsland)
 * See NOTICE for details.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AppKit
import Defaults
import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let horizontalPadding: CGFloat
    let onClick: () -> Void
    @Default(.enableHaptics) private var enableHaptics
    @State private var isHovering = false
    @State private var lastHoverHapticTime = Date.distantPast

    init(label: String, icon: String, selected: Bool, horizontalPadding: CGFloat = 15, onClick: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.selected = selected
        self.horizontalPadding = horizontalPadding
        self.onClick = onClick
    }
    
    var body: some View {
        let hoverFillOpacity: Double = {
            guard isHovering else { return 0 }
            return selected ? 0.08 : 0.16
        }()
        let hoverStrokeOpacity: Double = {
            guard isHovering else { return 0 }
            return selected ? 0.18 : 0.26
        }()

        Button(action: onClick) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isHovering ? .semibold : .regular))
                .scaleEffect(isHovering ? 1.04 : 1.0)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(hoverFillOpacity))
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(hoverStrokeOpacity), lineWidth: 1)
                        }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .help(label)
        .onHover { hovering in
            isHovering = hovering
            triggerHoverHapticIfNeeded(hovering)
        }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private func triggerHoverHapticIfNeeded(_ hovering: Bool) {
        guard hovering, enableHaptics else { return }
        let now = Date()
        guard now.timeIntervalSince(lastHoverHapticTime) > 0.22 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        lastHoverHapticTime = now
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        print("Tapped")
    }
}
