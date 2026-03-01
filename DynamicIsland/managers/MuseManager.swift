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

import AISDKProviderUtils
import AppKit
import AVFoundation
import Defaults
import Foundation

@MainActor
final class MuseManager: NSObject, ObservableObject {
    static let shared = MuseManager()

    @Published var conversations: [MuseConversation] = []
    @Published var currentConversationID: UUID?
    @Published var attachedFiles: [MuseAttachment] = []
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var isGenerating: Bool = false
    @Published var lastErrorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let conversationStore = MuseConversationStore.shared
    private let agentRunner = MuseAgentRunner()

    private var activeConversationID: UUID?
    private var activeAssistantMessageID: UUID?

    private let attachedFilesDefaultsKey = "MuseAttachedFiles"
    private let legacyAttachedFilesDefaultsKey = "ScreenAssistantFiles"

    static let audioDataDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsPath.appendingPathComponent("MuseAudio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let screenshotDataDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsPath.appendingPathComponent("MuseScreenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private override init() {
        super.init()
        loadConversations()
        loadAttachedFilesFromDefaults()
    }

    deinit {
        recordingTimer?.invalidate()
        audioRecorder?.stop()
    }

    var currentConversation: MuseConversation? {
        guard let currentConversationID else { return nil }
        return conversations.first(where: { $0.id == currentConversationID })
    }

    func createConversation() {
        let conversation = MuseConversation()
        conversations.insert(conversation, at: 0)
        currentConversationID = conversation.id
        conversationStore.saveConversation(conversation)
    }

    func selectConversation(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        currentConversationID = id
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        conversationStore.deleteConversation(id: id)

        if currentConversationID == id {
            if let first = conversations.first {
                currentConversationID = first.id
            } else {
                createConversation()
            }
        }
    }

    func clearConversation(_ id: UUID) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[conversationIndex].messages.removeAll()
        conversations[conversationIndex].title = String(localized: "New Conversation")
        conversations[conversationIndex].updatedAt = Date()
        conversationStore.saveConversation(conversations[conversationIndex])
    }

    func addFiles(_ urls: [URL]) {
        let validFiles = urls.filter {
            FileManager.default.fileExists(atPath: $0.path)
                && FileManager.default.isReadableFile(atPath: $0.path)
        }

        let attachments = validFiles.map(MuseAttachment.init(fileURL:))
        attachedFiles.append(contentsOf: attachments)
        saveAttachedFilesToDefaults()
    }

    func removeFile(_ file: MuseAttachment) {
        attachedFiles.removeAll { $0.id == file.id }
        if let audioName = file.audioFileName {
            let audioURL = Self.audioDataDirectory.appendingPathComponent(audioName)
            try? FileManager.default.removeItem(at: audioURL)
        }
        saveAttachedFilesToDefaults()
    }

    func clearAllFiles() {
        for file in attachedFiles {
            if let audioName = file.audioFileName {
                let audioURL = Self.audioDataDirectory.appendingPathComponent(audioName)
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        attachedFiles.removeAll()
        saveAttachedFilesToDefaults()
    }

    func attachScreenshot(type: ScreenshotSnippingTool.ScreenshotType = .area) {
        ScreenshotSnippingTool.shared.startSnipping(type: type) { [weak self] url in
            Task { @MainActor in
                self?.addFiles([url])
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func sendMessage(_ rawMessage: String) {
        let message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty || !attachedFiles.isEmpty else { return }

        guard let conversationID = ensureCurrentConversation() else { return }
        stopGeneration()

        let provider = selectedProvider()
        let model = selectedModel(for: provider)
        let files = attachedFiles

        let userMessage = MuseMessage(
            role: .user,
            content: message,
            state: .complete,
            attachments: files
        )
        appendMessage(userMessage, to: conversationID)
        maybeUpdateConversationTitle(for: conversationID, from: message)
        clearAllFiles()

        var assistantMessage = MuseMessage(
            role: .assistant,
            content: "",
            state: .sending,
            modelId: model.id,
            providerId: provider.rawValue
        )
        assistantMessage.streamingBuffer = ""
        appendMessage(assistantMessage, to: conversationID)

        let systemPrompt = normalizedSystemPrompt()
        let modelMessages = makeModelMessages(
            for: conversationID,
            excluding: assistantMessage.id
        )

        do {
            let languageModel = try MuseProviderFactory.makeLanguageModel(
                provider: provider,
                modelID: model.id
            )

            isGenerating = true
            lastErrorMessage = nil
            activeConversationID = conversationID
            activeAssistantMessageID = assistantMessage.id

            agentRunner.run(
                messages: modelMessages,
                model: languageModel,
                tools: MuseTools.all,
                systemPrompt: systemPrompt,
                maxSteps: 10
            ) { [weak self] event in
                self?.apply(event, conversationID: conversationID, messageID: assistantMessage.id)
            }
        } catch {
            failGenerating(error, conversationID: conversationID, messageID: assistantMessage.id)
        }
    }

    func stopGeneration() {
        guard isGenerating else { return }
        agentRunner.stop()
        isGenerating = false

        if let conversationID = activeConversationID,
           let messageID = activeAssistantMessageID {
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                if [.sending, .thinking, .streaming, .toolCalling].contains(draft.state) {
                    draft.state = .stopped
                    if draft.content.isEmpty {
                        draft.content = draft.streamingBuffer
                    }
                }
            }
        }

        activeConversationID = nil
        activeAssistantMessageID = nil
    }

    // MARK: - Internal Conversation Mutation

    private func loadConversations() {
        conversations = conversationStore.loadConversations()
        if conversations.isEmpty {
            createConversation()
        } else {
            currentConversationID = conversations.first?.id
        }
    }

    private func ensureCurrentConversation() -> UUID? {
        if currentConversationID == nil || !conversations.contains(where: { $0.id == currentConversationID }) {
            createConversation()
        }
        return currentConversationID
    }

    private func appendMessage(_ message: MuseMessage, to conversationID: UUID) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[conversationIndex].messages.append(message)
        conversations[conversationIndex].updatedAt = Date()
        conversationStore.saveConversation(conversations[conversationIndex])
    }

    private func updateMessage(conversationID: UUID, messageID: UUID, mutate: (inout MuseMessage) -> Void) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }

        mutate(&conversations[conversationIndex].messages[messageIndex])
        conversations[conversationIndex].updatedAt = Date()
        conversationStore.saveConversation(conversations[conversationIndex])
    }

    private func maybeUpdateConversationTitle(for conversationID: UUID, from firstMessage: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard conversations[conversationIndex].messages.count <= 1 else { return }

        let trimmed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let title = String(trimmed.prefix(20))
        conversations[conversationIndex].title = title
        conversations[conversationIndex].updatedAt = Date()
        conversationStore.saveConversation(conversations[conversationIndex])
    }

    // MARK: - Agent Event Handling

    private func apply(_ event: AgentEvent, conversationID: UUID, messageID: UUID) {
        switch event {
        case .thinking(let text):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                draft.state = .thinking
                draft.thinkingContent = (draft.thinkingContent ?? "") + text
            }

        case .text(let text):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                draft.state = .streaming
                draft.streamingBuffer += text
                draft.content = draft.streamingBuffer
            }

        case .toolCallStart(let id, let name):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                draft.state = .toolCalling
                var calls = draft.toolCalls ?? []
                if !calls.contains(where: { $0.id == id }) {
                    calls.append(
                        MuseToolCall(
                            id: id,
                            name: name,
                            arguments: "",
                            result: nil,
                            state: .calling
                        )
                    )
                }
                draft.toolCalls = calls
            }

        case .toolCallArguments(let id, let arguments):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                var calls = draft.toolCalls ?? []
                if let index = calls.firstIndex(where: { $0.id == id }) {
                    calls[index].arguments += arguments
                } else {
                    calls.append(
                        MuseToolCall(
                            id: id,
                            name: "tool",
                            arguments: arguments,
                            result: nil,
                            state: .calling
                        )
                    )
                }
                draft.toolCalls = calls
            }

        case .toolCallFinished(let id):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                var calls = draft.toolCalls ?? []
                if let index = calls.firstIndex(where: { $0.id == id }), calls[index].state == .calling {
                    calls[index].state = .success
                }
                draft.toolCalls = calls
                if draft.state == .toolCalling {
                    draft.state = .streaming
                }
            }

        case .toolResult(let id, let name, let content, let isError):
            updateMessage(conversationID: conversationID, messageID: messageID) { draft in
                var calls = draft.toolCalls ?? []
                if let index = calls.firstIndex(where: { $0.id == id }) {
                    calls[index].result = content
                    calls[index].state = isError ? .error : .success
                } else {
                    calls.append(
                        MuseToolCall(
                            id: id,
                            name: name,
                            arguments: "",
                            result: content,
                            state: isError ? .error : .success
                        )
                    )
                }
                draft.toolCalls = calls
                if isError {
                    draft.errorMessage = content
                }
                if draft.state == .toolCalling {
                    draft.state = .streaming
                }
            }

        case .stepFinished:
            break

        case .done:
            finishGenerating(conversationID: conversationID, messageID: messageID)

        case .error(let message):
            failGenerating(
                NSError(domain: "MuseAgentRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: message]),
                conversationID: conversationID,
                messageID: messageID
            )
        }
    }

    private func finishGenerating(conversationID: UUID, messageID: UUID) {
        updateMessage(conversationID: conversationID, messageID: messageID) { draft in
            if draft.state != .error && draft.state != .stopped {
                draft.state = .complete
            }
            if draft.content.isEmpty {
                draft.content = draft.streamingBuffer
            }
        }
        isGenerating = false
        activeConversationID = nil
        activeAssistantMessageID = nil
    }

    private func failGenerating(_ error: Error, conversationID: UUID, messageID: UUID) {
        let message = error.localizedDescription
        updateMessage(conversationID: conversationID, messageID: messageID) { draft in
            draft.state = .error
            draft.errorMessage = message
            if draft.content.isEmpty {
                draft.content = draft.streamingBuffer
            }
        }

        lastErrorMessage = message
        isGenerating = false
        activeConversationID = nil
        activeAssistantMessageID = nil
    }

    // MARK: - Prompt/Model Conversion

    private func makeModelMessages(for conversationID: UUID, excluding messageID: UUID) -> [ModelMessage] {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else { return [] }

        return conversation.messages
            .filter { $0.id != messageID }
            .compactMap { $0.toModelMessage() }
    }

    private func normalizedSystemPrompt() -> String? {
        let prompt = Defaults[.museSystemPrompt].trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt.isEmpty ? nil : prompt
    }

    // MARK: - Provider Selection

    private func selectedProvider() -> AIModelProvider {
        Defaults[.selectedAIProvider]
    }

    private func selectedModel(for provider: AIModelProvider) -> AIModel {
        if let model = Defaults[.selectedAIModel], provider.supportedModels.contains(where: { $0.id == model.id }) {
            return model
        }
        return provider.supportedModels.first ?? AIModel(id: "gpt-4.1-mini", name: "GPT-4.1 mini", supportsThinking: false)
    }

    // MARK: - Recording

    private func startRecording() {
        guard !isRecording else { return }

        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let audioURL = Self.audioDataDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.audioRecorder else { return }
                self.recordingDuration = recorder.currentTime
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
    }

    // MARK: - Attached Files Persistence

    private func saveAttachedFilesToDefaults() {
        guard let data = try? JSONEncoder().encode(attachedFiles) else { return }
        UserDefaults.standard.set(data, forKey: attachedFilesDefaultsKey)
    }

    private func loadAttachedFilesFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: attachedFilesDefaultsKey),
           let decoded = try? JSONDecoder().decode([MuseAttachment].self, from: data) {
            attachedFiles = decoded
            return
        }

        // One-time migration from legacy key.
        if let data = UserDefaults.standard.data(forKey: legacyAttachedFilesDefaultsKey),
           let decoded = try? JSONDecoder().decode([MuseAttachment].self, from: data) {
            attachedFiles = decoded
            saveAttachedFilesToDefaults()
            UserDefaults.standard.removeObject(forKey: legacyAttachedFilesDefaultsKey)
        }
    }
}

extension MuseManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard flag else {
            lastErrorMessage = String(localized: "Recording failed")
            return
        }

        let fileName = recorder.url.lastPathComponent
        let displayName = String(localized: "Recording \(DateFormatter.shortTime.string(from: Date()))")
        attachedFiles.append(MuseAttachment(audioFileName: fileName, name: displayName))
        saveAttachedFilesToDefaults()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        if let error {
            lastErrorMessage = error.localizedDescription
        }
    }
}

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

