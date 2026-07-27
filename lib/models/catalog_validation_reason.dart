/// Why a provider or model catalog edit was rejected.
///
/// The services throw English sentences so failures read well in logs, but the
/// UI has to show localized copy. Carrying the reason as a value keeps the two
/// from drifting: matching on the English text meant a reworded message
/// silently fell through to raw English in the other eight locales.
enum CatalogValidationReason {
  /// The model slug field was left empty.
  modelSlugRequired,

  /// Another model on this provider already uses the slug.
  modelSlugDuplicate,

  /// Hiding this model would leave the picker with nothing to show.
  modelVisibilityRequired,

  /// The provider name field was left empty.
  providerNameRequired,

  /// The provider name has no letters or digits.
  providerNameInvalid,

  /// The base URL field was left empty.
  providerUrlRequired,

  /// The base URL is not a valid HTTPS URL.
  providerUrlInvalid,

  /// The entry cannot be edited or removed, or no longer exists.
  ///
  /// Not reachable from the UI, which only offers these actions on custom
  /// entries that are on screen, so it has no localized copy of its own.
  notMutable,
}
