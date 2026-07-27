import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/home/rewrite_section.dart';
import 'package:make_it_sound_natural/screens/home/rewrite_shared.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_inline_banner.dart';
import 'package:make_it_sound_natural/widgets/app_kbd_chip.dart';
import 'package:make_it_sound_natural/widgets/app_panel.dart';

/// Share of the two-field region the source editor takes before any drag.
const double _defaultSourceShare = 0.6;

/// Least the source editor may be squeezed to by the divider.
const double _minSourceShare = 0.25;

/// Most it may claim, so the context field never disappears entirely.
const double _maxSourceShare = 0.8;

/// Rough share of the panel the two fields occupy, used to scale the drag.
const double _fieldsRegionShare = 0.75;

/// Denominator for the integer flex weights the split is expressed in.
const int _flexResolution = 1000;

/// Width of the grip shown on the divider while the pointer is over it.
const double _dividerGripWidth = 28;

/// Height of that grip.
const double _dividerGripHeight = 3;

/// Left Rewrite column: the text to rewrite, its context, and Process.
///
/// Split out of `home_screen.dart`, which had grown past the file-length
/// guideline; the two columns share no private state, so this is the seam.
class SourcePanel extends StatefulWidget {
  /// Creates the source column.
  const SourcePanel({
    required this.isApiKeyMissing,
    required this.onConfigureApiKey,
    required this.onDismissApiKey,
    required this.textController,
    required this.contextController,
    required this.isProcessing,
    required this.onProcess,
    required this.replaceShortcut,
    required this.appendShortcut,
    required this.onClearText,
    required this.onTextChanged,
    required this.onContextChanged,
    required this.onClearContext,
    super.key,
  });

  /// Whether the active provider still needs an API key.
  final bool isApiKeyMissing;

  /// Opens Settings at the provider section.
  final VoidCallback onConfigureApiKey;

  /// Hides the missing-key banner for this session.
  final VoidCallback onDismissApiKey;

  /// Controller for the text to rewrite.
  final TextEditingController textController;

  /// Controller for the persistent context field.
  final TextEditingController contextController;

  /// Whether a run is in flight.
  final bool isProcessing;

  /// Starts a run, or cancels the one in flight.
  final VoidCallback onProcess;

  /// Current replace-context shortcut, shown under the context field.
  final String replaceShortcut;

  /// Current append-context shortcut, shown in the footer.
  final String appendShortcut;

  /// Empties the source field.
  final VoidCallback onClearText;

  /// Reports edits to the source field.
  final ValueChanged<String> onTextChanged;

  /// Reports edits to the context field.
  final ValueChanged<String> onContextChanged;

  /// Empties the context field.
  final VoidCallback onClearContext;

  @override
  State<SourcePanel> createState() => _SourcePanelState();
}

class _SourcePanelState extends State<SourcePanel> {
  final _settingsService = SettingsService();

  /// Share of the two-field region the source editor takes.
  ///
  /// A ratio rather than a pixel height so the split survives a resize, and
  /// so both fields stay flexible — flex children always fit, which means the
  /// panel cannot overflow at any window size or text size.
  double _sourceShare = _defaultSourceShare;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSourceShare());
  }

  Future<void> _loadSourceShare() async {
    final stored = await _settingsService.getSourceEditorShare();
    if (stored != null && mounted) {
      setState(() => _sourceShare = _clampShare(stored));
    }
  }

  void _dragDivider(double delta, double panelHeight) {
    // The two fields occupy most of the panel; scaling the drag by that
    // estimate keeps the divider tracking the pointer closely enough that the
    // gesture feels direct.
    final fieldsHeight = math.max(1, panelHeight * _fieldsRegionShare);
    setState(() {
      _sourceShare = _clampShare(_sourceShare + delta / fieldsHeight);
    });
  }

  double _clampShare(double value) =>
      value.clamp(_minSourceShare, _maxSourceShare);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RewriteSection(
      title: l10n.sourceEyebrow,
      child: AppPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelHeight = constraints.maxHeight;
            // Integer flex weights: whatever the panel gets, the two fields
            // divide it, so nothing can ever overflow the column.
            final sourceFlex = (_sourceShare * _flexResolution).round();
            final contextFlex = _flexResolution - sourceFlex;

            final l10n = AppLocalizations.of(context)!;
            final hintStyle = Theme.of(context).textTheme.bodySmall;

            // Labels and hints are fixed rows here at the panel level; only
            // the two fields flex. Fixed chrome inside a flex share overflows
            // as soon as the share shrinks below its natural height.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isApiKeyMissing)
                  _ApiKeyBanner(
                    onConfigure: widget.onConfigureApiKey,
                    onDismiss: widget.onDismissApiKey,
                  ),
                Text(
                  l10n.textToImprove,
                  style: AppTextStyles.groupTitleOf(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  flex: sourceFlex,
                  child: _TextToImproveInput(
                    controller: widget.textController,
                    onProcess: widget.onProcess,
                    onClear: widget.onClearText,
                    onChanged: widget.onTextChanged,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // The keyboard equivalent of the Process button, under the
                // field it submits. No sentence needed: the pairing explains
                // itself.
                _HintPair(keys: '⌘↵', verb: l10n.hintProcess),
                _FieldDivider(
                  onDrag: (delta) => _dragDivider(delta, panelHeight),
                  onDragEnd: () => unawaited(
                    _settingsService.setSourceEditorShare(_sourceShare),
                  ),
                ),
                Text(
                  l10n.contextOptional,
                  style: AppTextStyles.groupTitleOf(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Takes whatever the editor leaves, so dragging the divider
                // moves the boundary one-to-one and nothing can overflow.
                Expanded(
                  flex: contextFlex,
                  child: _ContextInput(
                    controller: widget.contextController,
                    onChanged: widget.onContextChanged,
                    onClear: widget.onClearContext,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // A full sentence, not bare verbs: "replace" and "append" on
                // their own read as acting on the source text, when both act
                // on the context field from another application.
                Wrap(
                  spacing: AppSpacing.xxsPlus,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.contextShortcutHintLead, style: hintStyle),
                    AppKbdChip(
                      ShortcutFormatter.formatShortcutDisplay(
                        widget.replaceShortcut,
                      ),
                    ),
                    Text(l10n.contextShortcutHintReplace, style: hintStyle),
                    AppKbdChip(
                      ShortcutFormatter.formatShortcutDisplay(
                        widget.appendShortcut,
                      ),
                    ),
                    Text(l10n.contextShortcutHintAppend, style: hintStyle),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SourcePanelFooter(
                  isProcessing: widget.isProcessing,
                  canProcess: widget.textController.text.trim().isNotEmpty,
                  onProcess: widget.onProcess,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draggable boundary between the source editor and the context field.
///
/// The mockup asked for `resize: vertical` on both textareas — a browser
/// affordance with no native counterpart. On macOS the equivalent is a
/// draggable divider, which also redistributes the panel in one gesture
/// instead of growing one field and pushing the other down.
class _FieldDivider extends StatefulWidget {
  const _FieldDivider({required this.onDrag, required this.onDragEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  State<_FieldDivider> createState() => _FieldDividerState();
}

class _FieldDividerState extends State<_FieldDivider> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => widget.onDrag(details.delta.dy),
        onVerticalDragEnd: (_) => widget.onDragEnd(),
        child: SizedBox(
          height: AppSpacing.md,
          child: Center(
            child: AnimatedOpacity(
              opacity: _active ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: _dividerGripWidth,
                height: _dividerGripHeight,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shortcut hints on the left, the single primary action on the right.
/// One key and the verb it performs, kept on the same line.
class _HintPair extends StatelessWidget {
  const _HintPair({required this.keys, required this.verb});

  final String keys;
  final String verb;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppKbdChip(keys),
        const SizedBox(width: AppSpacing.xxsPlus),
        Text(verb, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SourcePanelFooter extends StatelessWidget {
  const _SourcePanelFooter({
    required this.isProcessing,
    required this.canProcess,
    required this.onProcess,
  });

  final bool isProcessing;
  final bool canProcess;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Just the button: every shortcut hint now sits beside the thing it acts
    // on — ⌘↵ under the source field, the context pair under context, and the
    // rewrite gesture in the empty Variants column it fills.
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: AppSizes.ctaHeight,
        child: FilledButton(
          key: const Key('rewrite-process'),
          // Stays enabled while running: a second press cancels the run.
          onPressed: canProcess || isProcessing ? onProcess : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing) ...[
                SizedBox(
                  width: rewriteProgressIndicatorSize,
                  height: rewriteProgressIndicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(isProcessing ? l10n.processing : l10n.process),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warns that the active provider cannot run a rewrite yet.
class _ApiKeyBanner extends StatelessWidget {
  const _ApiKeyBanner({
    required this.onConfigure,
    required this.onDismiss,
  });

  final VoidCallback onConfigure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppInlineBanner(
        icon: Icons.key_rounded,
        kind: AppInlineBannerKind.warning,
        message: l10n.providerSetupRequired,
        actions: [
          // Tinted with its own status, matching the error banner. The
          // theme's accent here made a secondary link the only saturated
          // thing on the screen while the CTA sat grey and disabled.
          TextButton(
            onPressed: onConfigure,
            style: TextButton.styleFrom(
              foregroundColor: AppStatusColors.of(context).warning,
            ),
            child: Text(l10n.configure),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

/// Source text field. Cmd+Enter starts a run from inside the field.
class _TextToImproveInput extends StatelessWidget {
  const _TextToImproveInput({
    required this.controller,
    required this.onProcess,
    required this.onClear,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onProcess;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final editorFontSize = AppearanceScope.maybePreferencesOf(
      context,
    ).editorFontSize;
    final theme = Theme.of(context);
    // Only the field: labels and hints are fixed-height chrome and live at
    // the panel level, outside the flexed regions. Fixed content inside a
    // flex share overflows the moment the share gets small.
    return _FieldWithClearAction(
      controller: controller,
      onClear: onClear,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isMetaPressed) {
            onProcess();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        // `expands` instead of a 3-4 line cap: this is the surface the
        // user works on, so it should take whatever height the window
        // gives it and scroll inside itself once the text outgrows that.
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: editorFontSize,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.textToImproveHint,
            contentPadding: rewriteFieldPadding,
          ),
        ),
      ),
    );
  }
}

/// Optional context field.
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
    // Only the field; its label and shortcut hint are panel-level chrome so
    // they can never be squeezed out of the flex share this widget fills.
    return _FieldWithClearAction(
      controller: widget.controller,
      onClear: widget.onClear,
      child: TextField(
        controller: widget.controller,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: editorFontSize,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.addContextHint,
          contentPadding: rewriteFieldPadding,
        ),
      ),
    );
  }
}

/// Anchors the clear action inside the field edge, and only when there is
/// something to clear.
class _FieldWithClearAction extends StatelessWidget {
  const _FieldWithClearAction({
    required this.controller,
    required this.onClear,
    required this.child,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (controller.text.isNotEmpty)
          Positioned(
            top: AppSpacing.xxsPlus,
            right: AppSpacing.xxsPlus,
            child: _ClearIconButton(onPressed: onClear),
          ),
      ],
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
        size: AppSizes.iconMd,
      ),
      tooltip: AppLocalizations.of(context)!.clear,
      color: colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.controlHeight,
        height: AppSizes.controlHeight,
      ),
      // No permanent backplate: at 70% over the field it measured 1.03:1 and
      // read as a glyph floating on the user's own text. Every other icon
      // action in the app is a bare glyph that fills on hover, which is what
      // IconButton already does.
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
