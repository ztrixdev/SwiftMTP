import Foundation
import SwiftUI

// MARK: - AI Natural Language Search Result

/// Represents the outcome of an inline AI natural language search.
enum AINLSearchResult {
    /// AI returned a list of matching file names (parsed from `[...]`).
    case matchedNames([String])
    /// AI returned an error or non-parseable response.
    case error(String)
}

// MARK: - AI Natural Language Search Manager

/// Handles the inline "Search with AI" button logic:
/// 1. Disables the button and shows a "Thinking…" indicator.
/// 2. Sends the search query + directory context to the AI backend.
/// 3. Parses the response:
///    - If the response contains a JSON array `["name1", "name2"]`, returns `.matchedNames`.
///    - Otherwise returns `.error` with the raw message.
@MainActor
class AINaturalLanguageSearchManager: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var isSuccess: Bool = false
    @Published var errorMessage: String? = nil

    /// Perform an inline AI search. Returns parsed file names on success,
    /// or sets `errorMessage` on failure.
    /// - Parameters:
    ///   - query: The user's search text.
    ///   - context: The JSON directory listing from `manager.lastDirectoryJson`.
    ///   - completion: Called with the result when the AI responds.
    func search(
        query: String,
        context: String,
        completion: @escaping (AINLSearchResult) -> Void
    ) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isProcessing = true
        isSuccess = false
        errorMessage = nil

        let aiManager = AIManager()

        // Use the conversation-based `sendQuery` to leverage the system prompt
        // that is already configured for file-name extraction.
        aiManager.sendQuery(query, context: context)

        // Poll for the response since `sendQuery` is async internally.
        // We observe the AIManager's published properties.
        Task {
            // Wait until AIManager finishes processing
            while aiManager.isProcessing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            // Check the last message from AIManager
            guard let lastMessage = aiManager.messages.last else {
                self.errorMessage = "No response from AI."
                self.isProcessing = false
                completion(.error("No response from AI."))
                return
            }

            switch lastMessage.role {
            case .error:
                self.errorMessage = lastMessage.content
                self.isProcessing = false
                completion(.error(lastMessage.content))

            case .assistant:
                let content = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if let names = Self.parseFileNames(from: content) {
                    self.isProcessing = false
                    self.isSuccess = true
                    self.errorMessage = nil
                    completion(.matchedNames(names))
                } else {
                    // Response doesn't contain a valid array — treat as error
                    self.errorMessage = content
                    self.isProcessing = false
                    completion(.error(content))
                }

            case .user:
                // Shouldn't happen, but handle gracefully
                self.errorMessage = "Unexpected response."
                self.isProcessing = false
                completion(.error("Unexpected response."))
            }
        }
    }

    /// Attempt to parse a JSON array of strings from the AI response.
    /// Looks for content within `[...]` brackets.
    static func parseFileNames(from text: String) -> [String]? {
        // Find the first `[` and last `]` in the text
        guard let startIndex = text.firstIndex(of: "["),
              let endIndex = text.lastIndex(of: "]"),
              startIndex < endIndex else {
            return nil
        }

        let jsonSubstring = String(text[startIndex...endIndex])
        guard let data = jsonSubstring.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return nil
        }

        return parsed
    }
}
