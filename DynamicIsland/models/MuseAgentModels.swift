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

struct MuseAgentUsage: Sendable, Hashable {
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
}

enum AgentEvent: Sendable {
    case thinking(String)
    case text(String)
    case toolCallStart(id: String, name: String)
    case toolCallArguments(id: String, arguments: String)
    case toolCallFinished(id: String)
    case toolResult(id: String, name: String, content: String, isError: Bool)
    case stepFinished
    case done(MuseAgentUsage?)
    case error(String)
}

