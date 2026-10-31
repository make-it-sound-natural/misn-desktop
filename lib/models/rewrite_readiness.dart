/// Whether the saved provider and model can run a rewrite.
enum RewriteReadiness {
  /// The selected provider has a key and a visible selected model.
  ready,

  /// The selected provider needs an API key.
  missingApiKey,

  /// No visible model is selected for the provider.
  missingModel,
}
