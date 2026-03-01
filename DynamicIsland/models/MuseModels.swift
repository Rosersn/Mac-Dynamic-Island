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

enum MuseMessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

enum MuseMessageState: String, Codable, Sendable {
    case sending
    case thinking
    case streaming
    case toolCalling
    case complete
    case error
    case stopped
}

enum MuseToolCallState: String, Codable, Sendable {
    case calling
    case success
    case error
}

struct MuseToolCall: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    var arguments: String
    var result: String?
    var state: MuseToolCallState
}

struct MuseAttachment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let type: AttachmentType
    let timestamp: Date
    let fileURL: String?
    let audioFileName: String?

    enum AttachmentType: String, CaseIterable, Codable, Sendable {
        case document
        case image
        case audio
        case video
        case other

        var iconName: String {
            switch self {
            case .document: return "doc.text"
            case .image: return "photo"
            case .audio: return "waveform"
            case .video: return "video"
            case .other: return "doc"
            }
        }

        var displayName: String {
            switch self {
            case .document: return String(localized: "Document")
            case .image: return String(localized: "Image")
            case .audio: return String(localized: "Audio")
            case .video: return String(localized: "Video")
            case .other: return String(localized: "File")
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AttachmentType,
        timestamp: Date = Date(),
        fileURL: String? = nil,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.timestamp = timestamp
        self.fileURL = fileURL
        self.audioFileName = audioFileName
    }

    init(fileURL: URL) {
        self.id = UUID()
        self.name = fileURL.lastPathComponent
        self.timestamp = Date()
        self.fileURL = fileURL.absoluteString
        self.audioFileName = nil

        let fileExtension = fileURL.pathExtension.lowercased()
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic":
            self.type = .image
        case "mp3", "wav", "m4a", "aac", "flac":
            self.type = .audio
        case "mp4", "mov", "avi", "mkv", "webm":
            self.type = .video
        case "txt", "md", "pdf", "doc", "docx", "rtf":
            self.type = .document
        default:
            self.type = .other
        }
    }

    init(audioFileName: String, name: String) {
        self.id = UUID()
        self.name = name
        self.type = .audio
        self.timestamp = Date()
        self.fileURL = nil
        self.audioFileName = audioFileName
    }
}

struct MuseMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var role: MuseMessageRole
    var content: String
    var thinkingContent: String?
    var toolCalls: [MuseToolCall]?
    var state: MuseMessageState
    var errorMessage: String?
    let timestamp: Date
    var modelId: String?
    var providerId: String?
    var toolCallId: String?
    var attachments: [MuseAttachment]?

    // This is transient in-memory streaming state; excluded from persistence.
    var streamingBuffer: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case thinkingContent
        case toolCalls
        case state
        case errorMessage
        case timestamp
        case modelId
        case providerId
        case toolCallId
        case attachments
    }

    init(
        id: UUID = UUID(),
        role: MuseMessageRole,
        content: String,
        thinkingContent: String? = nil,
        toolCalls: [MuseToolCall]? = nil,
        state: MuseMessageState = .complete,
        errorMessage: String? = nil,
        timestamp: Date = Date(),
        modelId: String? = nil,
        providerId: String? = nil,
        toolCallId: String? = nil,
        attachments: [MuseAttachment]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.toolCalls = toolCalls
        self.state = state
        self.errorMessage = errorMessage
        self.timestamp = timestamp
        self.modelId = modelId
        self.providerId = providerId
        self.toolCallId = toolCallId
        self.attachments = attachments
    }
}

struct MuseConversation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [MuseMessage]

    init(
        id: UUID = UUID(),
        title: String = String(localized: "New Conversation"),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [MuseMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    var previewText: String {
        if let latest = messages.last {
            return latest.content.isEmpty ? String(localized: "No messages yet") : latest.content
        }
        return String(localized: "No messages yet")
    }
}

struct MuseConversationIndexEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
}

extension MuseMessage {
    func toModelMessage() -> ModelMessage? {
        switch role {
        case .system:
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return .system(SystemModelMessage(content: text))

        case .user:
            return .user(UserModelMessage(content: .text(exportedUserText())))

        case .assistant:
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let thinking = (thinkingContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let calls = toolCalls ?? []

            if calls.isEmpty, thinking.isEmpty {
                guard !text.isEmpty else { return nil }
                return .assistant(AssistantModelMessage(content: .text(text)))
            }

            var parts: [AssistantContentPart] = []
            if !text.isEmpty {
                parts.append(.text(TextPart(text: text)))
            }
            if !thinking.isEmpty {
                parts.append(.reasoning(ReasoningPart(text: thinking)))
            }
            for call in calls {
                parts.append(
                    .toolCall(
                        ToolCallPart(
                            toolCallId: call.id,
                            toolName: call.name,
                            input: parseToolArguments(call.arguments)
                        )
                    )
                )
            }
            guard !parts.isEmpty else { return nil }
            return .assistant(AssistantModelMessage(content: .parts(parts)))

        case .tool:
            guard let toolCallId, !toolCallId.isEmpty else { return nil }
            let toolName = (providerId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (providerId ?? "tool")
                : "tool"
            let output = LanguageModelV3ToolResultOutput.text(value: content)
            let part = ToolContentPart.toolResult(
                ToolResultPart(
                    toolCallId: toolCallId,
                    toolName: toolName,
                    output: output
                )
            )
            return .tool(ToolModelMessage(content: [part]))
        }
    }

    private func exportedUserText() -> String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        let names = attachments?.map(\.name) ?? []
        if names.isEmpty {
            return "Attachment"
        }
        return "Attached files: \(names.joined(separator: ", "))"
    }

    private func parseToolArguments(_ raw: String) -> JSONValue {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .object([:]) }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .object(["raw": .string(trimmed)])
        }
        return json
    }
}

