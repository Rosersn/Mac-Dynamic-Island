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

import AISDKProvider
import AISDKProviderUtils
import Foundation
import SwiftAISDK

@MainActor
final class MuseAgentRunner: ObservableObject {
    @Published private(set) var isRunning = false

    private var runTask: Task<Void, Never>?

    func run(
        messages: [ModelMessage],
        model: any LanguageModelV3,
        tools: ToolSet? = nil,
        systemPrompt: String?,
        maxSteps: Int = 10,
        onEvent: @escaping @MainActor (AgentEvent) -> Void
    ) {
        stop()
        isRunning = true

        runTask = Task {
            var usage: MuseAgentUsage?
            var startedToolCallIDs = Set<String>()

            do {
                let stream = try streamText(
                    model: model,
                    system: normalizedSystemPrompt(systemPrompt),
                    messages: messages,
                    tools: tools,
                    stopWhen: [stepCountIs(max(1, maxSteps))]
                )

                for try await part in stream.fullStream {
                    guard !Task.isCancelled else { break }

                    switch part {
                    case .reasoningDelta(_, let text, _):
                        await onEvent(.thinking(text))

                    case .textDelta(_, let text, _):
                        await onEvent(.text(text))

                    case .toolInputStart(let id, let toolName, _, _, _, _):
                        startedToolCallIDs.insert(id)
                        await onEvent(.toolCallStart(id: id, name: toolName))

                    case .toolInputDelta(let id, let delta, _):
                        await onEvent(.toolCallArguments(id: id, arguments: delta))

                    case .toolInputEnd(let id, _):
                        await onEvent(.toolCallFinished(id: id))

                    case .toolCall(let call):
                        if !startedToolCallIDs.contains(call.toolCallId) {
                            startedToolCallIDs.insert(call.toolCallId)
                            await onEvent(.toolCallStart(id: call.toolCallId, name: call.toolName))
                        }

                    case .toolResult(let result):
                        await onEvent(
                            .toolResult(
                                id: result.toolCallId,
                                name: result.toolName,
                                content: stringify(jsonValue: result.output),
                                isError: false
                            )
                        )

                    case .toolError(let error):
                        await onEvent(
                            .toolResult(
                                id: error.toolCallId,
                                name: error.toolName,
                                content: error.error.localizedDescription,
                                isError: true
                            )
                        )

                    case .finishStep:
                        await onEvent(.stepFinished)

                    case .finish(_, _, let totalUsage):
                        usage = MuseAgentUsage(
                            inputTokens: totalUsage.inputTokens,
                            outputTokens: totalUsage.outputTokens,
                            totalTokens: totalUsage.totalTokens
                        )

                    case .error(let error):
                        await onEvent(.error(error.localizedDescription))

                    default:
                        break
                    }
                }

                if !Task.isCancelled {
                    await onEvent(.done(usage))
                }
            } catch is CancellationError {
                // Ignore cancellation.
            } catch {
                await onEvent(.error(error.localizedDescription))
            }

            await MainActor.run {
                self.isRunning = false
                self.runTask = nil
            }
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    private func normalizedSystemPrompt(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stringify(jsonValue: JSONValue) -> String {
        switch jsonValue {
        case .string(let value):
            return value
        default:
            guard let data = try? JSONEncoder().encode(jsonValue),
                  let string = String(data: data, encoding: .utf8) else {
                return "\(jsonValue)"
            }
            return string
        }
    }
}

