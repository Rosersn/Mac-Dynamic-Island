/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
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

import Foundation
import SwiftAISDK

private enum MuseToolsError: LocalizedError {
    case unsupportedScreenshotMode

    var errorDescription: String? {
        switch self {
        case .unsupportedScreenshotMode:
            return String(localized: "Unsupported screenshot mode. Use area/window/full.")
        }
    }
}

struct MuseScreenshotInput: Codable, Sendable {
    let mode: String
}

struct MuseScreenshotResult: Codable, Sendable {
    let filePath: String
    let fileName: String
}

struct MuseTimeInput: Codable, Sendable {}

struct MuseTimeResult: Codable, Sendable {
    let iso8601: String
    let local: String
}

enum MuseTools {
    static var all: [String: Tool] {
        [
            "take_screenshot": screenshotTool.tool,
            "current_time": timeTool.tool
        ]
    }

    static let screenshotTool: TypedTool<MuseScreenshotInput, MuseScreenshotResult> = tool(
        description: "Capture a screenshot. mode must be one of: area, window, full.",
        inputSchema: .auto(MuseScreenshotInput.self)
    ) { input, _ in
        let type: ScreenshotSnippingTool.ScreenshotType
        switch input.mode.lowercased() {
        case "area":
            type = .area
        case "window":
            type = .window
        case "full":
            type = .full
        default:
            throw MuseToolsError.unsupportedScreenshotMode
        }

        let url = try await withCheckedThrowingContinuation { continuation in
            ScreenshotSnippingTool.shared.startSnipping(type: type) { outputURL in
                continuation.resume(returning: outputURL)
            }
        }

        return MuseScreenshotResult(
            filePath: url.path,
            fileName: url.lastPathComponent
        )
    }

    static let timeTool: TypedTool<MuseTimeInput, MuseTimeResult> = tool(
        description: "Return current local time in ISO8601 and localized format.",
        inputSchema: .auto(MuseTimeInput.self)
    ) { _, _ in
        let now = Date()
        let iso = ISO8601DateFormatter().string(from: now)
        let localFormatter = DateFormatter()
        localFormatter.dateStyle = .medium
        localFormatter.timeStyle = .medium
        return MuseTimeResult(
            iso8601: iso,
            local: localFormatter.string(from: now)
        )
    }
}

