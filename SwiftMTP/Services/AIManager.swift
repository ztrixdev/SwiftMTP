import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Mode

enum AIMode: String {
    case api = "api"
    case apple = "apple"
    case none = "none"
}

// MARK: - AI Message

struct AIMessage: Identifiable {
    let id = UUID()
    let role: AIMessageRole
    let content: String
    let timestamp = Date()
}

enum AIMessageRole {
    case user
    case assistant
    case error
}

// MARK: - AI Manager

@MainActor
class AIManager: ObservableObject {
    @AppStorage("aiMode") private var aiModeRaw: String = "none"
    @AppStorage("aiApiUrl") private var aiApiUrl: String = ""
    @AppStorage("aiModelName") private var aiModelName: String = ""
    @AppStorage("aiApiKey") private var aiApiKey: String = ""
    @AppStorage("aiApiFormat") private var aiApiFormat: String = "openai"
    @AppStorage("aiEnableAdvanced") private var aiEnableAdvanced: Bool = false
    @AppStorage("aiMaxTokens") private var aiMaxTokens: Int = 4096
    @AppStorage("aiThinkingMode") private var aiThinkingMode: Bool = true
    @AppStorage("aiReasoningLevel") private var aiReasoningLevel: String = "low"
    
    /// Define your AI system prompt here
    private let systemPrompt: String = """

    """ // Prompts for AI to filter items based on json and user input.
        // Desired Output: ["Vacation.jpg", "Work Project"]

    
    @Published var messages: [AIMessage] = []
    @Published var isProcessing: Bool = false
    
    var currentMode: AIMode {
        AIMode(rawValue: aiModeRaw) ?? .none
    }
    
    /// Send a query to the configured AI backend.
    func sendQuery(_ query: String, context: String = "") {
        let userMessage = AIMessage(role: .user, content: query)
        messages.append(userMessage)
        isProcessing = true
        
        // Combine context and query for the AI
        guard !context.isEmpty else {
            let errorMsg = AIMessage(role: .error, content: ErrorStringLocalizer.localize("No directory context available. Please make sure the file list has loaded before using AI."))
            messages.append(errorMsg)
            isProcessing = false
            return
        }
        
        guard !query.isEmpty else {
            let errorMsg = AIMessage(role: .error, content: ErrorStringLocalizer.localize("No query specified."))
            messages.append(errorMsg)
            isProcessing = false
            return
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let currentTime = formatter.string(from: Date())
        let promptForAI = "Current Time: \(currentTime)\n\nDirectory Context:\n\(context)\n\nUser Instruction: \(query)"
        
        switch currentMode {
        case .api:
            sendAPIRequest(promptForAI)
        case .apple:
            sendAppleFoundationModelRequest(promptForAI)
        case .none:
            let errorMsg = AIMessage(role: .error, content: ErrorStringLocalizer.localize("AI is not configured. Please set up an AI provider in Settings → AI."))
            messages.append(errorMsg)
            isProcessing = false
        }
    }
    
    /// Clear all conversation history.
    func clearMessages() {
        messages.removeAll()
    }
    
    /// Sends a one-off request with a custom system prompt and returns the result string.
    /// This is used for specific tasks like USB connectivity analysis that don't need conversation history.
    func sendOneOffRequest(query: String) async -> String? {
        guard currentMode == .api else { 
            if currentMode == .apple {
                return ErrorStringLocalizer.localize("This feature is currently only available in API mode. Apple Foundation Models are not supported yet.")
            }
            return ErrorStringLocalizer.localize("AI is not configured. Please set up an AI provider in Settings → AI.")
        }
        
        guard !aiApiUrl.isEmpty, !aiApiKey.isEmpty, !aiModelName.isEmpty else {
            return ErrorStringLocalizer.localize("API configuration is incomplete. Please check Settings → AI.")
        }
        
        let systemPrompt = """
                            
                            """ // Prompts for AI to analyze hardware, connection information, etc.
        
        let userMessage = AIMessage(role: .user, content: query)
        guard let request = buildURLRequest(systemPrompt: systemPrompt, messages: [userMessage]) else {
            return "Failed to construct request."
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return ErrorStringLocalizer.localize("Server returned error \( (response as? HTTPURLResponse)?.statusCode ?? -1 )")
            }
            
            if let result = parseResponseContent(data) {
                return result
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "No data"
                return ErrorStringLocalizer.localize("Failed to parse AI response. Raw: \(raw)")
            }
        } catch {
            return ErrorStringLocalizer.localize("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - API Helpers
    
    private func buildURLRequest(systemPrompt: String?, messages: [AIMessage]) -> URLRequest? {
        guard let url = URL(string: aiApiUrl) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        var body: [String: Any] = [
            "model": aiModelName,
            "stream": false
        ]
        
        let formattedMessages = messages
            .filter { $0.role != .error }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
            
        if aiApiFormat == "anthropic" {
            request.setValue(aiApiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            if let system = systemPrompt {
                body["system"] = system
            }
            body["max_tokens"] = aiEnableAdvanced ? aiMaxTokens : 4096
            body["messages"] = formattedMessages
        } else {
            // OpenAI compatible
            request.setValue("Bearer \(aiApiKey)", forHTTPHeaderField: "Authorization")
            
            var requestMessages: [[String: String]] = []
            if let system = systemPrompt {
                requestMessages.append(["role": "system", "content": system])
            }
            requestMessages.append(contentsOf: formattedMessages)
            
            body["messages"] = requestMessages
            
            if aiEnableAdvanced {
                if !aiThinkingMode {
                    body["thinking"] = ["type": "disabled"]
                } else {
                    body["thinking"] = ["type": "enabled"]
                    body["reasoning_effort"] = aiReasoningLevel
                }
            } else {
                // Defaults
                body["thinking"] = ["type": "enabled"]
                body["reasoning_effort"] = "low"
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        return request
    }
    
    private func parseResponseContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        if aiApiFormat == "anthropic" {
            if let contentBlocks = json["content"] as? [[String: Any]] {
                var fullText = ""
                for block in contentBlocks {
                    if let text = block["text"] as? String {
                        fullText += text
                    }
                }
                return fullText.isEmpty ? nil : fullText
            }
        } else {
            // OpenAI compatible
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        }
        return nil
    }
    
    // MARK: - API Backend
    
    private func sendAPIRequest(_ query: String) {
        guard !aiApiUrl.isEmpty, !aiApiKey.isEmpty, !aiModelName.isEmpty else {
            appendError("API configuration is incomplete. Please check Settings → AI.")
            return
        }
        
        // Use the augmented query (with context) for the actual API call, 
        // while keeping the UI's messages list clean.
        var apiMessages = messages
        if let lastIndex = apiMessages.lastIndex(where: { $0.role == .user }) {
            let _ = apiMessages[lastIndex]
            apiMessages[lastIndex] = AIMessage(role: .user, content: query)
        }
        
        guard let request = buildURLRequest(systemPrompt: systemPrompt, messages: apiMessages) else {
            appendError("Failed to construct request.")
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    appendError("Invalid server response.")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage: String
                    switch httpResponse.statusCode {
                    case 401:
                        errorMessage = "Invalid API Key. Please check your settings."
                    case 404:
                        errorMessage = "API endpoint not found. Please check the URL."
                    case 429:
                        errorMessage = "Rate limit exceeded. Please try again later."
                    case 500...599:
                        errorMessage = "Server error (\(httpResponse.statusCode)). Please try again later."
                    default:
                        let bodyString = String(data: data, encoding: .utf8) ?? "Unknown error"
                        errorMessage = "Server returned error \(httpResponse.statusCode): \(bodyString)"
                    }
                    appendError(errorMessage)
                    return
                }
                
                if let content = parseResponseContent(data) {
                    let assistantMsg = AIMessage(role: .assistant, content: content)
                    messages.append(assistantMsg)
                    isProcessing = false
                } else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "No data"
                    appendError("Failed to parse AI response. Raw response: \(rawResponse)")
                }
            } catch let error as URLError {
                let msg: String
                switch error.code {
                case .timedOut: msg = "Request timed out. The server took too long to respond."
                case .notConnectedToInternet: msg = "No internet connection detected."
                case .cannotFindHost, .dnsLookupFailed: msg = "Could not find the AI server. Check the URL."
                case .secureConnectionFailed, .serverCertificateHasBadDate: msg = "SSL/TLS connection failed."
                default: msg = "Network error: \(error.localizedDescription)"
                }
                appendError(msg)
            } catch {
                appendError("Unexpected error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Apple Foundation Model Backend
    // AFM's fixed 4096-token context window makes it almost unusable at present. 
    // It is really often to exceed the context window. Nevertheless, this is 
    // still an option for users. Do hope Apple could launch a stronger local model in the future.
    
    private func sendAppleFoundationModelRequest(_ query: String) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                Task {
                do {
                    let session = LanguageModelSession(instructions: systemPrompt)
                    let response = try await session.respond(to: query)
                    let content = response.content
                    if content.isEmpty {
                        appendError("Apple Foundation Model returned an empty response.")
                    } else {
                        let assistantMsg = AIMessage(role: .assistant, content: content)
                        messages.append(assistantMsg)
                        isProcessing = false
                    }
                } catch {
                    appendError("Apple Foundation Model error: \(error.localizedDescription)")
                }
            }
            case .unavailable(.appleIntelligenceNotEnabled):
                appendError("Apple Intelligence hasn't been turned on.")
            case .unavailable(.modelNotReady):
                appendError("Model is not ready yet. Try again later.")
            case .unavailable(.deviceNotEligible):
                appendError("Your Mac is not eligible for Apple Intelligence.")
            case .unavailable(_):
                appendError("Not available for unknown reasons.")
            }
        } else {
            appendError("Apple Foundation Models require macOS 26 or later with Apple Intelligence enabled.")
        }
        #else
        appendError("Apple Foundation Models are not available. Build with Xcode 26+.")
        #endif
    }
    
    // MARK: - Helpers
    
    private func appendError(_ text: String) {
        let localizedError = ErrorStringLocalizer.localize(text)
        let errorMsg = AIMessage(role: .error, content: localizedError)
        messages.append(errorMsg)
        isProcessing = false
    }
}
