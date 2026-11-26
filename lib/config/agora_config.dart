/// Agora RTC credentials.
///
/// Get a free App ID from https://console.agora.io (Create Project → App ID).
/// Paste it below. The project must stay in "App ID only" mode (no App
/// Certificate) for the token-less join used here, or calls need a token
/// server (see Agora docs).
class AgoraConfig {
  /// Paste your Agora App ID here (48 hex chars).
  static const String appId = 'YOUR_AGORA_APP_ID';

  static bool get isConfigured =>
      appId != 'YOUR_AGORA_APP_ID' && appId.length >= 32;
}
