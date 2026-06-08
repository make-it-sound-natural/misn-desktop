import 'dart:io';

/// Writes Sparkle appcast feeds.
abstract final class AppcastWriter {
  /// Creates an empty Sparkle RSS feed.
  static String emptyFeed({
    required String title,
    required String link,
  }) {
    return '<?xml version="1.0" encoding="utf-8"?>\n'
        '<rss version="2.0" '
        'xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '    <channel>\n'
        '        <title>$title</title>\n'
        '        <link>$link</link>\n'
        '        <description>Updates for $title</description>\n'
        '        <language>en</language>\n'
        '\n'
        '    </channel>\n'
        '</rss>\n';
  }

  /// Inserts a new appcast item at the top of the feed.
  static void insertItem(
    File feed, {
    required String title,
    required String version,
    required String shortVersion,
    required String pubDate,
    required String minimumSystemVersion,
    required String dmgUrl,
    required String sparkleSignature,
    required int dmgSize,
    required List<String> notes,
  }) {
    final escapedNotes = notes
        .map(_escapeXml)
        .map((note) => '            <li>$note</li>')
        .join('\n');
    final item =
        '''
    <item>
        <title>${_escapeXml(title)}</title>
        <pubDate>$pubDate</pubDate>
        <sparkle:version>${_escapeXml(version)}</sparkle:version>
        <sparkle:shortVersionString>${_escapeXml(shortVersion)}</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>$minimumSystemVersion</sparkle:minimumSystemVersion>
        <description><![CDATA[
            <h2>What's Changed</h2>
            <ul>
$escapedNotes
            </ul>
        ]]></description>
        <enclosure
            url="$dmgUrl"
            $sparkleSignature
            length="$dmgSize"
            type="application/octet-stream"/>
    </item>
''';

    final content = feed.readAsStringSync();
    final updated = content.replaceFirst(
      '<language>en</language>',
      '<language>en</language>\n\n$item',
    );
    if (updated == content) {
      throw const FormatException('Feed has no language marker');
    }
    feed.writeAsStringSync(updated);
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
