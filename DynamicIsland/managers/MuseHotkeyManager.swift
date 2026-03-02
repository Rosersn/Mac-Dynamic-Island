/*
 * Notchi (DynamicIsland)
 * Copyright (C) 2024-2026 Notchi Contributors
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
import Foundation

@MainActor
final class MuseHotkeyManager: ObservableObject {
    static let shared = MuseHotkeyManager()

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var isOptionPressed = false
    private var lastOptionReleaseAt: Date?

    private init() {}

    func startMonitoring() {
        stopMonitoring()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
    }

    func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard Defaults[.enableDoubleOptionForMuse] else { return }

        let optionActive = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.option)

        if optionActive && !isOptionPressed {
            if let lastRelease = lastOptionReleaseAt {
                let interval = Date().timeIntervalSince(lastRelease)
                if interval <= Defaults[.museDoubleOptionInterval] {
                    MuseFloatingPanelManager.shared.togglePanel()
                    lastOptionReleaseAt = nil
                }
            }
        }

        if !optionActive && isOptionPressed {
            lastOptionReleaseAt = Date()
        }

        isOptionPressed = optionActive
    }
}

