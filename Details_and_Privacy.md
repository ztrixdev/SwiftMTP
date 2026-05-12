# About AI Features in SwiftMTP

## Details

SwiftMTP currently supports two modes for AI: **Apple Foundation Models** and **AI API**.

Apple Foundation Models are on-device models provided by Apple that run entirely locally on your Mac. They feature a fixed 4096-token context window and require macOS 26 or later with Apple Intelligence enabled.

AI API Integration mode supports both OpenAI and Anthropic API formats. When configuring, ensure the API Endpoint includes the full path (e.g., including `v1/messages` or similar). You must explicitly specify the model in Model Name (recommended to use `flash` or similar high-speed models).

## Privacy and Security

- **Onboarding Notice**: When you first switch the AI Mode from `None` to any other option in Settings, a disclosure notice will appear explaining the terms of use. You must read and agree to all terms before activating AI features.
- **On-Device Local Processing**: All inference using Apple Foundation Models is performed entirely on your local hardware.
- **Manual Trigger Only**: AI features must be manually triggered by the user.
- **Metadata Handling**: In API mode, item metadata (such as names, types, and modification dates) and device information (model, USB status) may be sent to the provider to build context for your requests. The actual contents of your files will **never** be uploaded or shared.