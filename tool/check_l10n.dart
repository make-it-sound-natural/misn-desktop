import 'dart:convert';
import 'dart:io';

final _arbDirectory = Directory('lib/l10n');
final _templateFile = File('lib/l10n/app_en.arb');

void main() {
  final template = _readArb(_templateFile);
  final templateKeys = _messageKeys(template).toSet();
  var hasError = false;

  for (final file in _arbDirectory.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.arb'),
  )) {
    if (file.path == _templateFile.path) continue;

    final localeArb = _readArb(file);
    final localeKeys = _messageKeys(localeArb).toSet();
    final missing = templateKeys.difference(localeKeys).toList()..sort();
    final extra = localeKeys.difference(templateKeys).toList()..sort();
    final untranslated =
        templateKeys
            .where(
              (key) =>
                  localeArb[key] == template[key] && !_allowedSharedKeys(key),
            )
            .toList()
          ..sort();

    if (missing.isNotEmpty || extra.isNotEmpty || untranslated.isNotEmpty) {
      hasError = true;
      stderr.writeln('${file.path}:');
      _writeFinding('missing', missing);
      _writeFinding('extra', extra);
      _writeFinding('untranslated', untranslated);
    }
  }

  if (hasError) {
    exitCode = 1;
  }
}

Map<String, Object?> _readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

Iterable<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

bool _allowedSharedKeys(String key) => const {
  'openAI',
  'openRouter',
  'balanced',
  'casual',
  'formal',
  'concise',
  'errorLabel',
  'shortcutCorrection',
  'targetProfileInstruction',
  'targetProfileName',
  'updates',
  'versionLabel',
  'pixelsUnit',
}.contains(key);

void _writeFinding(String label, List<String> values) {
  if (values.isEmpty) return;
  stderr.writeln('  $label: ${values.join(', ')}');
}
