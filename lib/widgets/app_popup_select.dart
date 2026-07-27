import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

const double _menuRowHeight = 26;
const double _menuMaxHeight = 320;
const double _menuMinWidth = 112;
const double _menuMaxWidth = 340;
const double _checkColumnWidth = 18;
const double _groupHeaderHeight = 22;

/// Opacity applied to a disabled control's own content.
const double _disabledAlpha = 0.38;

/// One row in an [AppPopupSelect]: either a choice or a group heading.
///
/// Modelled as a sealed pair rather than one class with a nullable `value`.
/// Overloading null as "this is a heading" made the two states
/// indistinguishable, so a select over a nullable type — or a forgotten
/// `value` — silently produced a disabled heading instead of a compile error.
sealed class AppPopupEntry<T> {
  const AppPopupEntry(this.label);

  /// Row text.
  final String label;
}

/// A selectable entry.
class AppPopupOption<T> extends AppPopupEntry<T> {
  /// Creates a selectable entry.
  const AppPopupOption({
    required this.value,
    required String label,
    this.detail,
  }) : super(label);

  /// Value reported to `onChanged`.
  final T value;

  /// Optional trailing detail, for example an average latency.
  final String? detail;
}

/// A non-selectable group heading.
class AppPopupHeader<T> extends AppPopupEntry<T> {
  /// Creates a group heading.
  const AppPopupHeader(super.label);
}

/// A macOS-style pop-up button.
///
/// Material's `DropdownButton` opens a 48px-per-row menu over its own field;
/// a Mac pop-up button shows a compact anchored menu that marks the current
/// choice with a checkmark. This keeps the second behaviour, which is the one
/// users read as native.
class AppPopupSelect<T> extends StatelessWidget {
  /// Creates a pop-up select.
  const AppPopupSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
    this.monospaceLabels = false,
    this.placeholder,
    this.shrinkWrap = false,
    this.enabled = true,
  });

  /// Currently selected value.
  final T? value;

  /// Entries, in display order, optionally including group headings.
  final List<AppPopupEntry<T>> options;

  /// Called with the chosen value.
  final ValueChanged<T> onChanged;

  /// Renders labels in the mono face, for model ids and URLs.
  final bool monospaceLabels;

  /// Shown when nothing is selected.
  final String? placeholder;

  /// Sizes the control to its label instead of filling the available width.
  ///
  /// Needed where the control sits inline in an unbounded row, which cannot
  /// give a flexible child any width to expand into.
  final bool shrinkWrap;

  /// Whether the menu can be opened.
  ///
  /// A disabled select must not open at all: swallowing the choice after the
  /// menu has been used reads as the app ignoring the user.
  final bool enabled;

  AppPopupOption<T>? get _selected {
    for (final option in options) {
      if (option is AppPopupOption<T> && option.value == value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _selected;
    final labelStyle = _labelStyle(theme);

    final foreground = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: _disabledAlpha);

    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: '',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(
        minWidth: _menuMinWidth,
        maxWidth: _menuMaxWidth,
        maxHeight: _menuMaxHeight,
      ),
      // Highlights the current row and scrolls it into view.
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in options)
          switch (option) {
            AppPopupHeader<T>() => PopupMenuItem<T>(
              enabled: false,
              height: _groupHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: _checkColumnWidth),
                child: Text(
                  option.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            AppPopupOption<T>() => PopupMenuItem<T>(
              value: option.value,
              height: _menuRowHeight,
              child: _MenuRow(
                label: option.label,
                detail: option.detail,
                selected: option.value == value,
                monospace: monospaceLabels,
              ),
            ),
          },
      ],
      // `_Field` carries hover and focus itself: PopupMenuButton wraps its
      // child in an InkWell, but the opaque fill below paints over the splash,
      // so without this the control had no hover, no press and no focus ring —
      // the only interactive thing in the app with none of the three.
      child: _Field(
        enabled: enabled,
        height: AppSizes.controlHeight,
        child: Row(
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _label(
              shrinkWrap: shrinkWrap,
              child: Text(
                selected?.label ?? placeholder ?? '',
                overflow: TextOverflow.ellipsis,
                style: selected == null
                    ? labelStyle.copyWith(color: colorScheme.onSurfaceVariant)
                    : labelStyle.copyWith(color: foreground),
              ),
            ),
            if (selected?.detail != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                selected!.detail!,
                style: labelStyle.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.unfold_more_rounded,
              size: AppSizes.iconMd,
              color: enabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label({required bool shrinkWrap, required Widget child}) {
    return shrinkWrap ? child : Expanded(child: child);
  }

  TextStyle _labelStyle(ThemeData theme) {
    final base = theme.textTheme.bodySmall ?? const TextStyle();
    if (!monospaceLabels) {
      return base.copyWith(color: theme.colorScheme.onSurface);
    }
    return base.copyWith(
      color: theme.colorScheme.onSurface,
      fontFamily: AppTextStyles.monoFontFamily,
    );
  }
}

/// The pop-up's visible field, with the states `PopupMenuButton` cannot paint.
class _Field extends StatefulWidget {
  const _Field({
    required this.enabled,
    required this.height,
    required this.child,
  });

  final bool enabled;
  final double height;
  final Widget child;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final focused = _focused && widget.enabled;

    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      mouseCursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: switch ((widget.enabled, _hovered)) {
            (false, _) => colorScheme.surfaceContainerHighest,
            (true, true) => colorScheme.surfaceContainerHigh,
            (true, false) => colorScheme.surfaceContainerLowest,
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          // Matches `inputDecorationTheme.focusedBorder` so a focused select
          // and a focused text field read as the same state.
          border: Border.all(
            color: focused ? colorScheme.primary : theme.dividerColor,
            width: focused ? 2 : 1,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.detail,
    required this.selected,
    required this.monospace,
  });

  final String label;
  final String? detail;
  final bool selected;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurface,
      fontFamily: monospace ? AppTextStyles.monoFontFamily : null,
    );

    return Row(
      children: [
        SizedBox(
          width: _checkColumnWidth,
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: AppSizes.iconSm,
                  color: theme.colorScheme.onSurface,
                )
              : null,
        ),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (detail != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            detail!,
            style: style.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
