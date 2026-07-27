import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/shortcut_status.dart';
import 'package:make_it_sound_natural/l10n/correction_variant_localizations.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/screens/home/home_shortcut_listeners.dart';
import 'package:make_it_sound_natural/screens/home/source_panel.dart';
import 'package:make_it_sound_natural/screens/home/variants_panel.dart';
import 'package:make_it_sound_natural/screens/home_flow_state.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/openai_service.dart';
import 'package:make_it_sound_natural/services/provider_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/utils/logger.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';
import 'package:make_it_sound_natural/widgets/app_window_header.dart';
import 'package:make_it_sound_natural/widgets/target_profile_picker_dialog.dart';

const Duration _appliedRingHold = Duration(milliseconds: 400);

/// Main home screen displaying text input and correction variants.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen widget.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Logger _log = getLogger('HomeScreen');
  final _openAIService = OpenAIService();
  final _settingsService = SettingsService();
  final _targetProfileService = TargetProfileService();
  final _providerCatalogService = ProviderCatalogService();
  final _contextController = TextEditingController();
  final _textToImproveController = TextEditingController();

  HomeFlowState _flow = const HomeFlowState.empty();
  late final HomeShortcutListeners _listeners = HomeShortcutListeners(
    onVariants: (content) => unawaited(_handleVariantsReceived(content)),
    onStatus: _handleShortcutStatus,
    onNotEditable: _handleNotEditable,
    onOpenSettings: _handleOpenSettingsRequest,
    onTextCaptured: _handleTextCaptured,
    onError: _handleShortcutError,
  );

  bool _isApiKeyMissing = false;
  bool _isWindowVisible = true;

  /// Bumped whenever a run starts or is cancelled, so a reply that arrives
  /// after cancellation is discarded instead of resurrecting variants.
  int _processGeneration = 0;
  String? _lastSubmittedText;
  String _autoApplyVariant = AppDefaults.variant;
  String _currentShortcut = AppDefaults.correctionShortcut;
  String _replaceShortcut = AppDefaults.replaceShortcut;
  String _appendShortcut = AppDefaults.appendShortcut;
  int? _justAppliedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    unawaited(_loadContext());
    unawaited(_checkApiKey());
    unawaited(_loadAutoApplyVariant());
    unawaited(_loadShortcut());
    _listeners.start();
    _checkForCachedText();
    _checkForCachedVariants();
    unawaited(_showInitialTargetProfilePicker());
  }

  Future<void> _showInitialTargetProfilePicker() async {
    final selectionRequired = await _targetProfileService.isSelectionRequired();
    if (!selectionRequired || !mounted) return;

    final currentProfile = await _targetProfileService.getSelectedProfile();
    if (!mounted) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final selected = await showDialog<TargetProfile>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TargetProfilePickerDialog(
        service: _targetProfileService,
        currentProfile: currentProfile,
        forceSelection: true,
      ),
    );
    if (selected == null || !mounted) return;

    final profile = await _targetProfileService.selectProfile(selected.id);
    await ShortcutService().setTargetProfile(
      profile,
      selectionRequired: false,
    );
  }

  Future<void> _loadShortcut() async {
    final shortcut = await _settingsService.getShortcut();
    // The footer advertises these two, and the user can rebind them.
    final replace = await _settingsService.getReplaceShortcut();
    final append = await _settingsService.getAppendShortcut();
    if (mounted) {
      setState(() {
        _currentShortcut = shortcut;
        _replaceShortcut = replace;
        _appendShortcut = append;
      });
    }
  }

  Future<void> _loadAutoApplyVariant() async {
    final variant = await _settingsService.getDefaultVariant();
    if (mounted) {
      setState(() => _autoApplyVariant = variant);
    }
  }

  /// Persists the tone applied to future runs, including runs started by the
  /// global shortcut. Settings -> Writing shows and writes the same value.
  Future<void> _setAutoApplyVariant(String variant) async {
    setState(() => _autoApplyVariant = variant);
    await _settingsService.setDefaultVariant(variant);
    await ShortcutService().setDefaultVariant(variant);
  }

  Future<void> _checkApiKey() async {
    final hasApiKey = await _settingsService.hasReadyActiveProviderForRewrite();
    if (mounted) {
      setState(() => _isApiKeyMissing = !hasApiKey);
    }
  }

  Future<void> _loadContext() async {
    final ctx = await _settingsService.getContext();
    if (mounted) {
      setState(() => _contextController.text = ctx);
    }
  }

  Future<void> _saveContext() async {
    await _settingsService.setContext(_contextController.text);
    await ShortcutService().setContext(_contextController.text);
  }

  Future<void> _clearContext() async {
    _contextController.clear();
    await _saveContext();
    if (mounted) {
      showAppToast(context, AppLocalizations.of(context)!.contextCleared);
    }
  }

  void _handleShortcutStatus(ShortcutStatus status) {
    if (!mounted) return;

    // State first, and before the visibility guard: a shortcut run normally
    // completes while this window is hidden, and the card the user will see
    // when they come back has to reflect what already happened to their
    // document. Toasts below are the part that needs the window on screen.
    if (status == ShortcutStatus.success) {
      final applied = _flow.selectedIndex;
      if (applied != null) {
        // The run pasted the preferred tone at the cursor, so that card is
        // the text now sitting in the user's document — it must say
        // "Applied" rather than offer to apply it a second time.
        setState(() => _flow = _flow.selectVariant(applied, applied: true));
      }
    }

    if (!_isWindowVisible) return;

    switch (status) {
      case ShortcutStatus.contextReplaced:
        unawaited(_loadContext());
        showAppToast(
          context,
          AppLocalizations.of(context)!.statusContextReplaced,
        );
      case ShortcutStatus.contextAppended:
        unawaited(_loadContext());
        showAppToast(
          context,
          AppLocalizations.of(context)!.statusContextAppended,
        );
      case ShortcutStatus.windowChanged:
        if (mounted) {
          setState(() => _flow = _flow.clearSelection());
        }
        showAppToast(
          context,
          AppLocalizations.of(context)!.windowChanged,
          kind: AppToastKind.warning,
        );
      case ShortcutStatus.success:
      case ShortcutStatus.notEditable:
      // Success: variants flow. Not editable: [_handleNotEditable].
      case ShortcutStatus.error:
      // Errors: [_handleShortcutError] and [ShortcutService.errorStream].
    }
  }

  /// Listens to the [ShortcutService.notEditableStream] and displays a snackbar
  /// when the user attempts to use the shortcut in a non-editable context.
  ///
  /// Shows an informative message explaining why text replacement could not
  /// be performed (e.g., cursor not in an editable field).
  void _handleNotEditable() {
    if (!mounted || !_isWindowVisible) return;
    // The native side reports a role-specific reason; the UI states the one
    // thing the user can act on.
    showAppToast(
      context,
      AppLocalizations.of(context)!.notEditableGeneric,
      kind: AppToastKind.muted,
      icon: Icons.edit_off_rounded,
    );
  }

  void _handleOpenSettingsRequest() {
    _log.info('Received openSettings event!');
    if (!mounted) return;
    // Bring app to foreground first, then navigate
    _bringAppToForeground();
    _openSettings();
  }

  void _handleTextCaptured(String text) {
    if (!mounted) return;
    setState(() {
      _textToImproveController.text = text;
    });
  }

  /// Shows API/LLM errors from the global shortcut (and other native paths).
  void _handleShortcutError(String message) {
    if (!mounted) return;
    _bringAppToForeground();
    // Show immediately: [addPostFrameCallback] can run after [mounted] is
    // false in tests (and in edge timing), skipping the toast entirely.
    showAppToast(
      context,
      AppLocalizations.of(context)!.errorLabel(message),
      kind: AppToastKind.error,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Cancels an in-flight run from Escape while the window is focused and no
  /// dialog is open. Dialogs own Escape when they are on top.
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    if (!mounted || !_flow.isProcessing) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    _cancelProcessing();
    return true;
  }

  void _cancelProcessing() {
    if (!_flow.isProcessing) return;
    _processGeneration++;
    setState(() => _flow = _flow.stopProcessing());
    showAppToast(context, AppLocalizations.of(context)!.processingCancelled);
  }

  Future<void> _processManualText() async {
    if (_flow.isProcessing) {
      _cancelProcessing();
      return;
    }

    final text = _textToImproveController.text.trim();
    if (text.isEmpty) return;

    _lastSubmittedText = text;
    final generation = ++_processGeneration;
    final requestStart = DateTime.now().toUtc();
    setState(() => _flow = _flow.startProcessing());

    try {
      final variants = await _openAIService.generateVariants(text);
      if (!mounted || generation != _processGeneration) return;

      final selectedIndex = await _preferredVariantIndex(variants);
      if (!mounted || generation != _processGeneration) return;

      setState(() {
        _flow = _flow.withVariants(variants, selectedIndex: selectedIndex);
      });
    } on Exception catch (e) {
      _log.warning('Error processing text: $e');
      if (!mounted || generation != _processGeneration) return;

      final authFailureProvider = await _authFailureProviderSince(requestStart);
      if (!mounted || generation != _processGeneration) return;

      if (authFailureProvider != null) {
        setState(() {
          _flow = _flow.failWithAuthFailure(providerName: authFailureProvider);
        });
        return;
      }

      setState(() => _flow = _flow.stopProcessing());
      showAppToast(
        context,
        AppLocalizations.of(context)!.errorLabel(e.toString()),
        kind: AppToastKind.error,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  /// Returns the display name of the active provider when it recorded an
  /// authentication failure for the run that started at [requestStart].
  Future<String?> _authFailureProviderSince(DateTime requestStart) async {
    final provider = await _settingsService.getProvider();
    final failure = await _settingsService.getProviderAuthFailure(provider);
    if (failure == null || failure.occurredAt.isBefore(requestStart)) {
      return null;
    }
    final entry = await _providerCatalogService.providerById(provider);
    return entry?.displayName ?? provider;
  }

  void _retryProcessing() {
    final text = _lastSubmittedText;
    if (text == null) return;
    _textToImproveController.text = text;
    unawaited(_processManualText());
  }

  void _clearTextToImprove() {
    setState(_textToImproveController.clear);
  }

  void _bringAppToForeground() {
    // Use platform channel to bring window to front on macOS
    unawaited(ShortcutService().bringToForeground());
  }

  void _checkForCachedVariants() {
    final cached = ShortcutService().lastVariants;
    if (cached != null && cached.isNotEmpty) {
      unawaited(_handleVariantsReceived(cached));
    }
  }

  void _checkForCachedText() {
    final cached = ShortcutService().lastCapturedText;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _textToImproveController.text = cached;
      });
    }
  }

  Future<void> _handleVariantsReceived(String content) async {
    try {
      final variants = _openAIService.parseVariants(content);
      if (variants.isEmpty) return;

      final selectedIndex = await _preferredVariantIndex(variants);

      setState(() {
        _flow = _flow.withVariants(variants, selectedIndex: selectedIndex);
      });
    } on Exception catch (e) {
      debugPrint('Error parsing variants: $e');
    }
  }

  Future<int> _preferredVariantIndex(List<CorrectionVariant> variants) async {
    final defaultVariant = await _settingsService.getDefaultVariant();
    final defaultVariantKind = CorrectionVariantKind.tryParseLabel(
      defaultVariant,
    );
    final selectedIndex = variants.indexWhere(
      (variant) => defaultVariantKind == null
          ? variant.label == defaultVariant
          : variant.kind == defaultVariantKind,
    );
    return selectedIndex == -1 ? 0 : selectedIndex;
  }

  Future<void> _selectVariant(int index) async {
    final selectedVariant = _flow.variants[index];
    final generation = _processGeneration;
    setState(() {
      // Move the highlight straight away so the tap feels immediate, but do
      // not claim it was applied until the native side says so.
      _flow = _flow.selectVariant(index, applied: false);
      _justAppliedIndex = index;
    });
    Future<void>.delayed(_appliedRingHold, () {
      if (mounted) setState(() => _justAppliedIndex = null);
    });

    unawaited(Clipboard.setData(ClipboardData(text: selectedVariant.text)));
    final replaced = await ShortcutService().replaceTextInOriginalApp(
      selectedVariant.text,
    );
    if (!mounted || generation != _processGeneration) return;

    // Only claim a replacement the native side actually performed; otherwise
    // the clipboard is all the user got.
    setState(() {
      _flow = _flow.selectVariant(index, applied: replaced);
    });

    final l10n = AppLocalizations.of(context)!;
    showAppToast(
      context,
      replaced
          ? l10n.appliedCopiedToClipboard(
              l10n.correctionVariantDisplayLabel(selectedVariant),
            )
          : l10n.copiedToClipboard,
    );
  }

  void _copyToClipboard(String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    showAppToast(context, AppLocalizations.of(context)!.copiedToClipboard);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isWindowVisible = state == AppLifecycleState.resumed;
    });
    // Reload context when returning to the foreground. Do not call
    // [clearSnackBars] here: [ShortcutService.errorStream] shows an error
    // SnackBar and then [bringToForeground] activates the window, which
    // triggers [resumed] and would remove the SnackBar the user never saw.
    if (_isWindowVisible && mounted) {
      unawaited(_loadContext());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    unawaited(_listeners.dispose());
    _contextController.dispose();
    _textToImproveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppWindowHeader(
            activeTab: AppHeaderTab.rewrite,
            onRewrite: () {},
            onSettings: _openSettings,
          ),
          Expanded(
            // Columns fill the window and scroll their own content, the way a
            // Mac app uses extra height: more room to work, not bigger type.
            //
            // The height is clamped to a floor rather than left free, so at a
            // large editor font in a short window the page scrolls instead of
            // squeezing the fields until the panel overflows.
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.rewriteMaxContentWidth,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SourcePanel(
                          isApiKeyMissing: _isApiKeyMissing,
                          onConfigureApiKey: _openSettings,
                          onDismissApiKey: () =>
                              setState(() => _isApiKeyMissing = false),
                          textController: _textToImproveController,
                          contextController: _contextController,
                          isProcessing: _flow.isProcessing,
                          onProcess: _processManualText,
                          replaceShortcut: _replaceShortcut,
                          appendShortcut: _appendShortcut,
                          onClearText: _clearTextToImprove,
                          onTextChanged: (_) => setState(() {}),
                          onContextChanged: (_) => _saveContext(),
                          onClearContext: _clearContext,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: VariantsPanel(
                          flow: _flow,
                          autoApplyVariant: _autoApplyVariant,
                          shortcut: _currentShortcut,
                          justAppliedIndex: _justAppliedIndex,
                          onSelect: (index) => unawaited(_selectVariant(index)),
                          onCopy: _copyToClipboard,
                          onAutoApplyChanged: (value) =>
                              unawaited(_setAutoApplyVariant(value)),
                          onOpenSettings: _openSettings,
                          onRetry: _retryProcessing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    unawaited(
      Navigator.push(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SettingsScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        unawaited(_checkApiKey());
        unawaited(_loadAutoApplyVariant());
        unawaited(_loadShortcut());
      }),
    );
  }
}
