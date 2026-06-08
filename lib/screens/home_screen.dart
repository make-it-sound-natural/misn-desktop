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
import 'package:make_it_sound_natural/screens/home_flow_state.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/services/openai_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/logger.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_panel.dart';
import 'package:make_it_sound_natural/widgets/app_window_header.dart';
import 'package:make_it_sound_natural/widgets/target_profile_picker_dialog.dart';
import 'package:make_it_sound_natural/widgets/unity_card.dart';

const double _rewriteSubtleAlpha = 0.7;
const double _rewriteHintAlpha = 0.8;
const double _variantSelectedBackgroundAlpha = 0.1;
const double _rewriteIconButtonSize = 28;
const double _rewriteIconButtonGlyphSize = 16;
const double _rewriteInlineIconSize = 14;
const double _rewriteProgressIndicatorSize = 12;
const double _rewriteBannerIconSize = 18;
const double _variantActionButtonSize = 32;
const double _variantCopyIconSize = 18;
const double _variantHeaderIconSize = 28;
const double _variantHeaderIconGlyphSize = 16;
const double _rewriteInputFocusedBorderWidth = 2;
const double _rewriteInputBorderWidth = 1;
const double _shortcutBadgeLetterSpacing = 1;

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
  final _contextController = TextEditingController();
  final _textToImproveController = TextEditingController();

  HomeFlowState _flow = const HomeFlowState.empty();
  StreamSubscription<String>? _variantsSubscription;
  StreamSubscription<ShortcutStatus>? _statusSubscription;
  StreamSubscription<String>? _notEditableSubscription;
  StreamSubscription<void>? _openSettingsSubscription;
  StreamSubscription<String>? _textCapturedSubscription;
  StreamSubscription<String>? _errorSubscription;

  bool _isApiKeyMissing = false;
  String _currentShortcut = AppDefaults.correctionShortcut;
  bool _isWindowVisible = true;

  /// Long enough to read provider errors (e.g. credits, max_tokens); users can
  /// dismiss early via the close control on the snackbar.
  static const Duration _errorSnackBarDuration = Duration(seconds: 120);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadContext());
    unawaited(_loadShortcut());
    unawaited(_checkApiKey());
    _listenToShortcutVariants();
    _listenToStatus();
    _listenToNotEditable();
    _listenToOpenSettings();
    _listenToTextCaptured();
    _listenToShortcutErrors();
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
    if (mounted) {
      setState(() => _currentShortcut = shortcut);
    }
  }

  Future<void> _checkApiKey() async {
    final hasApiKey = await _settingsService.hasApiKeyForActiveProvider();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.contextCleared)),
      );
    }
  }

  void _listenToStatus() {
    _statusSubscription = ShortcutService().statusStream.listen((status) {
      if (!mounted || !_isWindowVisible) return;

      switch (status) {
        case ShortcutStatus.contextReplaced:
          unawaited(_loadContext());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.statusContextReplaced,
              ),
            ),
          );
        case ShortcutStatus.contextAppended:
          unawaited(_loadContext());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.statusContextAppended,
              ),
            ),
          );
        case ShortcutStatus.windowChanged:
          if (mounted) {
            setState(() => _flow = _flow.clearSelection());
          }
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.windowChanged),
              backgroundColor: AppStatusColors.of(context).warning,
            ),
          );
        case ShortcutStatus.success:
        case ShortcutStatus.notEditable:
        // Success: variants flow. Not editable: [_listenToNotEditable].
        case ShortcutStatus.error:
        // Errors: [_listenToShortcutErrors] and
        // [ShortcutService.errorStream].
      }
    });
  }

  /// Listens to the [ShortcutService.notEditableStream] and displays a snackbar
  /// when the user attempts to use the shortcut in a non-editable context.
  ///
  /// Shows an informative message explaining why text replacement could not
  /// be performed (e.g., cursor not in an editable field).
  void _listenToNotEditable() {
    _notEditableSubscription = ShortcutService().notEditableStream.listen((
      reason,
    ) {
      if (!mounted || !_isWindowVisible) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.edit_off_rounded,
                color: AppStatusColors.of(context).onStatus,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(reason)),
            ],
          ),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    });
  }

  void _listenToOpenSettings() {
    _openSettingsSubscription = ShortcutService().openSettingsStream.listen((
      _,
    ) {
      _log.info('Received openSettings event!');
      if (!mounted) return;
      // Bring app to foreground first, then navigate
      _bringAppToForeground();
      _openSettings();
    });
  }

  void _listenToTextCaptured() {
    _textCapturedSubscription = ShortcutService().textCapturedStream.listen((
      text,
    ) {
      if (!mounted) return;
      setState(() {
        _textToImproveController.text = text;
      });
    });
  }

  /// Shows API/LLM errors from the global shortcut (and other native paths).
  void _listenToShortcutErrors() {
    _errorSubscription = ShortcutService().errorStream.listen((message) {
      if (!mounted) return;
      _bringAppToForeground();
      // Show immediately: [addPostFrameCallback] can run after [mounted] is
      // false in tests (and in edge timing), skipping the SnackBar entirely.
      _showDismissibleErrorSnackBar(
        backgroundColor: AppStatusColors.of(context).error,
        foregroundColor: AppStatusColors.of(context).onStatus,
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppStatusColors.of(context).onStatus,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.errorLabel(message),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showDismissibleErrorSnackBar({
    required Widget content,
    required Color backgroundColor,
    Color? foregroundColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: _errorSnackBarDuration,
        showCloseIcon: true,
        closeIconColor: foregroundColor ?? Colors.white,
      ),
    );
  }

  Future<void> _processManualText() async {
    final text = _textToImproveController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noTextToProcess),
        ),
      );
      return;
    }

    setState(() => _flow = _flow.startProcessing());

    try {
      final variants = await _openAIService.generateVariants(text);
      if (!mounted) return;

      final selectedIndex = await _preferredVariantIndex(variants);

      setState(() {
        _flow = _flow.withVariants(variants, selectedIndex: selectedIndex);
      });
    } on Exception catch (e) {
      _log.warning('Error processing text: $e');
      if (!mounted) return;
      setState(() => _flow = _flow.stopProcessing());
      _showDismissibleErrorSnackBar(
        backgroundColor: AppStatusColors.of(context).warning,
        foregroundColor: AppStatusColors.of(context).onStatus,
        content: Text(AppLocalizations.of(context)!.errorLabel(e.toString())),
      );
    }
  }

  void _clearTextToImprove() {
    setState(_textToImproveController.clear);
  }

  void _bringAppToForeground() {
    // Use platform channel to bring window to front on macOS
    unawaited(ShortcutService().bringToForeground());
  }

  void _listenToShortcutVariants() {
    _variantsSubscription = ShortcutService().variantsGeneratedStream.listen(
      _handleVariantsReceived,
    );
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

  void _selectVariant(int index) {
    final selectedVariant = _flow.variants[index];
    setState(() => _flow = _flow.selectVariant(index));
    unawaited(
      ShortcutService().replaceTextInOriginalApp(selectedVariant.text),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          )!.appliedLabel(
            AppLocalizations.of(
              context,
            )!.correctionVariantDisplayLabel(selectedVariant),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.copiedToClipboard)),
    );
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
    unawaited(_variantsSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_notEditableSubscription?.cancel());
    unawaited(_openSettingsSubscription?.cancel());
    unawaited(_textCapturedSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    _contextController.dispose();
    _textToImproveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AppWindowHeader(
            activeTab: AppHeaderTab.rewrite,
            onRewrite: () {},
            onSettings: _openSettings,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < AppSizes.rewriteTwoPanelBreakpoint;
                final sourcePanel = _SourcePanel(
                  fillHeight: !compact,
                  isApiKeyMissing: _isApiKeyMissing,
                  onConfigureApiKey: _openSettings,
                  onDismissApiKey: () =>
                      setState(() => _isApiKeyMissing = false),
                  textController: _textToImproveController,
                  contextController: _contextController,
                  isProcessing: _flow.isProcessing,
                  onProcess: _processManualText,
                  onClearText: _clearTextToImprove,
                  onTextChanged: (_) => setState(() {}),
                  onContextChanged: (_) => _saveContext(),
                  onClearContext: _clearContext,
                );
                final variantsPanel = _VariantsPanel(
                  variants: _flow.variants,
                  selectedIndex: _flow.selectedIndex,
                  shortcut: _currentShortcut,
                  onSelect: _selectVariant,
                  onCopy: _copyToClipboard,
                );

                if (compact) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      sourcePanel,
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(height: 420, child: variantsPanel),
                    ],
                  );
                }

                final panelHeight =
                    (constraints.maxHeight - AppSpacing.lg - AppSpacing.xl)
                        .clamp(420.0, 560.0);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    height: panelHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(flex: 46, child: sourcePanel),
                        const SizedBox(width: AppSpacing.lg),
                        Flexible(flex: 54, child: variantsPanel),
                      ],
                    ),
                  ),
                );
              },
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
        unawaited(_loadShortcut());
      }),
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({
    required this.fillHeight,
    required this.isApiKeyMissing,
    required this.onConfigureApiKey,
    required this.onDismissApiKey,
    required this.textController,
    required this.contextController,
    required this.isProcessing,
    required this.onProcess,
    required this.onClearText,
    required this.onTextChanged,
    required this.onContextChanged,
    required this.onClearContext,
  });

  final bool fillHeight;
  final bool isApiKeyMissing;
  final VoidCallback onConfigureApiKey;
  final VoidCallback onDismissApiKey;
  final TextEditingController textController;
  final TextEditingController contextController;
  final bool isProcessing;
  final VoidCallback onProcess;
  final VoidCallback onClearText;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onContextChanged;
  final VoidCallback onClearContext;

  @override
  Widget build(BuildContext context) {
    return _RewriteSection(
      title: 'SOURCE',
      fillHeight: fillHeight,
      child: AppPanel(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isApiKeyMissing) ...[
                _ApiKeyBanner(
                  onConfigure: onConfigureApiKey,
                  onDismiss: onDismissApiKey,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              _TextToImproveInput(
                controller: textController,
                isProcessing: isProcessing,
                onProcess: onProcess,
                onClear: onClearText,
                onChanged: onTextChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              _ContextInput(
                controller: contextController,
                onChanged: onContextChanged,
                onClear: onClearContext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantsPanel extends StatelessWidget {
  const _VariantsPanel({
    required this.variants,
    required this.selectedIndex,
    required this.shortcut,
    required this.onSelect,
    required this.onCopy,
  });

  final List<CorrectionVariant> variants;
  final int? selectedIndex;
  final String shortcut;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RewriteSection(
      title: 'VARIANTS',
      trailing: Container(
        height: _variantActionButtonSize,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: Theme.of(
              context,
            ).dividerColor.withValues(alpha: _rewriteSubtleAlpha),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context)!.autoApplyVariant(
            AppLocalizations.of(
              context,
            )!.correctionVariantLabel(CorrectionVariantKind.balanced),
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: AppPanel(
        child: variants.isEmpty
            ? _EmptyState(shortcut: shortcut)
            : _VariantsList(
                variants: variants,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                onCopy: onCopy,
              ),
      ),
    );
  }
}

class _RewriteSection extends StatelessWidget {
  const _RewriteSection({
    required this.title,
    required this.child,
    this.trailing,
    this.fillHeight = true,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.sectionTitleOf(context),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        if (fillHeight) Expanded(child: child) else child,
      ],
    );
  }
}

/// Subtle banner shown when API key is missing.
class _ApiKeyBanner extends StatelessWidget {
  const _ApiKeyBanner({
    required this.onConfigure,
    required this.onDismiss,
  });

  final VoidCallback onConfigure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = AppStatusColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: statusColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: statusColors.warning,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            size: _rewriteBannerIconSize,
            color: statusColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.apiKeyRequired,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onConfigure,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppLocalizations.of(context)!.configure,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: _rewriteBannerIconSize,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text to improve input field with process button.
class _TextToImproveInput extends StatelessWidget {
  const _TextToImproveInput({
    required this.controller,
    required this.isProcessing,
    required this.onProcess,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final VoidCallback onProcess;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final editorFontSize = AppearanceScope.maybePreferencesOf(
      context,
    ).editorFontSize;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.textToImprove,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                if (controller.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _ClearIconButton(onPressed: onClear),
                  ),
                MouseRegion(
                  cursor: isProcessing
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: isProcessing ? null : onProcess,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        gradient: isProcessing
                            ? null
                            : AppColors.accentGradient,
                        color: isProcessing
                            ? AppColors.textSecondary.withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isProcessing)
                            const SizedBox(
                              width: _rewriteProgressIndicatorSize,
                              height: _rewriteProgressIndicatorSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.auto_fix_high_rounded,
                              size: _rewriteInlineIconSize,
                              color: Colors.white,
                            ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            isProcessing
                                ? AppLocalizations.of(context)!.processing
                                : AppLocalizations.of(context)!.process,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isMetaPressed &&
                !isProcessing) {
              onProcess();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 4,
            minLines: 2,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: editorFontSize,
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.textToImproveHint,
              hintStyle: _rewriteHintStyle(context),
              filled: true,
              fillColor: _rewriteInputFillColor(context),
              border: _rewriteInputBorder(context),
              enabledBorder: _rewriteInputBorder(context),
              focusedBorder: _rewriteInputBorder(context, focused: true),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Context input field with label row and clear button.
class _ContextInput extends StatefulWidget {
  const _ContextInput({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_ContextInput> createState() => _ContextInputState();
}

class _ContextInputState extends State<_ContextInput> {
  @override
  Widget build(BuildContext context) {
    final editorFontSize = AppearanceScope.maybePreferencesOf(
      context,
    ).editorFontSize;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.contextOptional,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              _ClearIconButton(onPressed: widget.onClear),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: widget.controller,
          onChanged: (value) {
            widget.onChanged(value);
            setState(() {});
          },
          maxLines: 5,
          minLines: 1,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: editorFontSize,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.addContextHint,
            hintStyle: _rewriteHintStyle(context),
            helperText: AppLocalizations.of(context)!.contextHelper,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: _rewriteInputFillColor(context),
            border: _rewriteInputBorder(context),
            enabledBorder: _rewriteInputBorder(context),
            focusedBorder: _rewriteInputBorder(context, focused: true),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          ),
        ),
      ],
    );
  }
}

/// Empty state with wave logo watermark.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.shortcut});

  final String shortcut;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.selectTextInstruction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                ShortcutFormatter.formatShortcutDisplay(shortcut),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: _shortcutBadgeLetterSpacing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of variant cards.
class _VariantsList extends StatelessWidget {
  const _VariantsList({
    required this.variants,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCopy,
  });

  final List<CorrectionVariant> variants;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.dragged);
          }),
          thickness: WidgetStateProperty.all(6),
          radius: const Radius.circular(3),
          thumbColor: WidgetStateProperty.all(
            Theme.of(context).textTheme.bodySmall?.color?.withValues(
              alpha: 0.4,
            ),
          ),
          trackVisibility: WidgetStateProperty.all(false),
          crossAxisMargin: 2,
          mainAxisMargin: 4,
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        itemCount: variants.length,
        separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final variant = variants[index];
          final isSelected = selectedIndex == index;
          final editorFontSize = AppearanceScope.maybePreferencesOf(
            context,
          ).editorFontSize;
          final colorScheme = Theme.of(context).colorScheme;
          final statusColors = AppStatusColors.of(context);

          return UnityCard(
            isSelected: isSelected,
            onTap: () => onSelect(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _VariantIcon(
                      icon: _iconForVariantKind(variant.kind),
                      selected: isSelected,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.correctionVariantDisplayLabel(variant),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: statusColors.successContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: statusColors.success,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              AppLocalizations.of(context)!.applied,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: statusColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => onSelect(index),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          minimumSize: const Size(48, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(AppLocalizations.of(context)!.apply),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        size: _variantCopyIconSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => onCopy(variant.text),
                      tooltip: AppLocalizations.of(context)!.copy,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: _variantActionButtonSize,
                        height: _variantActionButtonSize,
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: AppSpacing.lg,
                  color: Theme.of(
                    context,
                  ).dividerColor.withValues(alpha: _rewriteSubtleAlpha),
                ),
                SelectableText(
                  variant.text,
                  style: TextStyle(fontSize: editorFontSize, height: 1.42),
                  onTap: () => onSelect(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClearIconButton extends StatelessWidget {
  const _ClearIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(
        Icons.close_rounded,
        size: _rewriteIconButtonGlyphSize,
      ),
      tooltip: AppLocalizations.of(context)!.clear,
      color: colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _rewriteIconButtonSize,
        height: _rewriteIconButtonSize,
      ),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: _rewriteSubtleAlpha,
        ),
        foregroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

class _VariantIcon extends StatelessWidget {
  const _VariantIcon({
    required this.icon,
    required this.selected,
  });

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final background = selected
        ? colorScheme.primary.withValues(
            alpha: _variantSelectedBackgroundAlpha,
          )
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: _rewriteSubtleAlpha,
          );
    return Container(
      width: _variantHeaderIconSize,
      height: _variantHeaderIconSize,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: _variantHeaderIconGlyphSize, color: foreground),
    );
  }
}

IconData _iconForVariantKind(CorrectionVariantKind? kind) {
  switch (kind) {
    case CorrectionVariantKind.balanced:
      return Icons.tune_rounded;
    case CorrectionVariantKind.casual:
      return Icons.chat_bubble_outline_rounded;
    case CorrectionVariantKind.formal:
      return Icons.business_center_outlined;
    case CorrectionVariantKind.concise:
      return Icons.short_text_rounded;
    case null:
      return Icons.auto_awesome_rounded;
  }
}

TextStyle _rewriteHintStyle(BuildContext context) {
  return TextStyle(
    color: Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: _rewriteHintAlpha),
  );
}

Color _rewriteInputFillColor(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.dark) {
    return AppColors.darkControlSurface;
  }
  return theme.colorScheme.surfaceContainerHighest;
}

OutlineInputBorder _rewriteInputBorder(
  BuildContext context, {
  bool focused = false,
}) {
  final theme = Theme.of(context);
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(
      color: focused ? theme.colorScheme.primary : theme.dividerColor,
      width: focused
          ? _rewriteInputFocusedBorderWidth
          : _rewriteInputBorderWidth,
    ),
  );
}
