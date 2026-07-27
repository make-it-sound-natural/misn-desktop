import 'dart:io';

import 'package:flutter/services.dart';

/// Utility class for formatting and validating keyboard shortcuts.
class ShortcutFormatter {
  /// Formats a shortcut string for display with platform-specific symbols.
  ///
  /// Converts modifier keys (cmd, ctrl, shift, alt) to their platform-specific
  /// symbols (⌘, ⇧, ⌃, ⌥ on macOS) or text labels on other platforms.
  static String formatShortcutDisplay(String shortcut) {
    if (shortcut.isEmpty) return '';

    final parts = shortcut.split('+');
    final formattedParts = parts.map((part) {
      final lowerPart = part.toLowerCase().trim();
      switch (lowerPart) {
        case 'cmd':
        case 'command':
        case 'meta':
          return Platform.isMacOS ? '⌘' : 'Win';
        case 'shift':
          return Platform.isMacOS ? '⇧' : 'Shift';
        case 'ctrl':
        case 'control':
          return Platform.isMacOS ? '⌃' : 'Ctrl';
        case 'alt':
        case 'option':
          return Platform.isMacOS ? '⌥' : 'Alt';
        default:
          return part.toUpperCase();
      }
    }).toList();

    return formattedParts.join(Platform.isMacOS ? '' : ' + ');
  }

  /// Converts a set of keyboard keys to a shortcut string.
  ///
  /// Sorts modifiers in a standard order (Cmd/Meta, Ctrl, Alt, Shift) followed
  /// by the main key, and joins them with '+' separators.
  static String shortcutToString(Set<LogicalKeyboardKey> keys) {
    final sortedKeys = _sortKeys(keys);
    final parts = sortedKeys.map(_keyLabel).toList();
    return parts.join('+');
  }

  /// Validates that a shortcut has a command modifier and a real key.
  ///
  /// Checks the parts rather than the joined string: a substring test lets
  /// `cmd+ctrl+shift` pass, which is a chord no key can complete.
  static bool validateShortcutStructure(String shortcut) {
    final parts = shortcut
        .toLowerCase()
        .split('+')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    const commandModifiers = {'cmd', 'ctrl', 'meta'};
    const modifiers = {...commandModifiers, 'shift', 'alt', 'opt', 'option'};

    final hasCommandModifier = parts.any(commandModifiers.contains);
    final hasKey = parts.any((part) => !modifiers.contains(part));
    return hasCommandModifier && hasKey;
  }

  static String _keyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta) {
      return 'cmd';
    }
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control) {
      return 'ctrl';
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt) {
      return 'alt';
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift) {
      return 'shift';
    }
    return key.keyLabel.toLowerCase();
  }

  static List<LogicalKeyboardKey> _sortKeys(Set<LogicalKeyboardKey> keys) {
    final modifiers = <LogicalKeyboardKey>[];
    final others = <LogicalKeyboardKey>[];

    for (final key in keys) {
      if (_isModifier(key)) {
        modifiers.add(key);
      } else {
        others.add(key);
      }
    }

    // Sort modifiers: Ctrl, Alt, Shift, Meta
    // (standard order varies, but let's pick one)
    // Actually standard notation: Cmd-Opt-Shift-Ctrl usually?
    // Let's use: Cmd/Meta -> Ctrl -> Alt -> Shift -> Key
    modifiers.sort((a, b) {
      return _modifierRank(a).compareTo(_modifierRank(b));
    });

    return [...modifiers, ...others];
  }

  static bool _isModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift;
  }

  static int _modifierRank(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta) {
      return 0;
    }
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control) {
      return 1;
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt) {
      return 2;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift) {
      return 3;
    }
    return 4;
  }
}
