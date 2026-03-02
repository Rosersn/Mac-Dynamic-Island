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

import Foundation

final class MuseConversationStore {
    static let shared = MuseConversationStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let indexKey = "MuseConversationIndex"

    static let conversationsDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = documentsPath.appendingPathComponent("MuseConversations")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadConversations() -> [MuseConversation] {
        let index = loadIndex()

        if index.isEmpty {
            return scanConversationsFromDisk()
        }

        var conversations: [MuseConversation] = []
        for entry in index.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            if let conversation = loadConversation(id: entry.id) {
                conversations.append(conversation)
            }
        }
        return conversations
    }

    func loadConversation(id: UUID) -> MuseConversation? {
        let fileURL = conversationFileURL(id: id)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(MuseConversation.self, from: data)
    }

    func saveConversation(_ conversation: MuseConversation) {
        let fileURL = conversationFileURL(id: conversation.id)
        do {
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("MuseConversationStore save failed: \(error.localizedDescription)")
        }

        var index = loadIndex()
        if let existingIndex = index.firstIndex(where: { $0.id == conversation.id }) {
            index[existingIndex] = MuseConversationIndexEntry(
                id: conversation.id,
                title: conversation.title,
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt
            )
        } else {
            index.append(
                MuseConversationIndexEntry(
                    id: conversation.id,
                    title: conversation.title,
                    createdAt: conversation.createdAt,
                    updatedAt: conversation.updatedAt
                )
            )
        }
        saveIndex(index)
    }

    func deleteConversation(id: UUID) {
        let fileURL = conversationFileURL(id: id)
        try? FileManager.default.removeItem(at: fileURL)

        var index = loadIndex()
        index.removeAll { $0.id == id }
        saveIndex(index)
    }

    func saveAllConversations(_ conversations: [MuseConversation]) {
        for conversation in conversations {
            saveConversation(conversation)
        }
    }

    private func conversationFileURL(id: UUID) -> URL {
        Self.conversationsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func loadIndex() -> [MuseConversationIndexEntry] {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let index = try? decoder.decode([MuseConversationIndexEntry].self, from: data) else {
            return []
        }
        return index
    }

    private func saveIndex(_ index: [MuseConversationIndexEntry]) {
        guard let data = try? encoder.encode(index) else { return }
        UserDefaults.standard.set(data, forKey: indexKey)
    }

    private func scanConversationsFromDisk() -> [MuseConversation] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: Self.conversationsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        let conversations = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> MuseConversation? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(MuseConversation.self, from: data)
            }
            .sorted(by: { $0.updatedAt > $1.updatedAt })

        let index = conversations.map {
            MuseConversationIndexEntry(
                id: $0.id,
                title: $0.title,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        saveIndex(index)
        return conversations
    }
}

