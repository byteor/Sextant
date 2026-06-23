import 'dart:convert';
import 'dart:io';

/// Pure CSV parsing for the IEEE OUI registry's published CSV format
/// (`Registry,Assignment,Organization Name,Organization Address`). Shared by
/// the in-app refresher below and the one-off `tool/build_oui.dart` generator,
/// so both parse identically.
Map<String, String> parseOuiCsv(String csv) {
  final table = <String, String>{};
  for (final line in csv.split('\n').skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = _parseCsvLine(line);
    if (fields.length < 3) continue;
    final oui = fields[1].trim().toUpperCase();
    final org = fields[2].trim();
    if (oui.length != 6 || org.isEmpty) continue;
    table[oui] = org;
  }
  return table;
}

/// Minimal RFC-4180 CSV line parser (handles double-quoted fields containing
/// commas and escaped quotes).
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  fields.add(buf.toString());
  return fields;
}

/// Serialises an OUI table back into the same `AABBCC\tVendor` TSV format as
/// the bundled `assets/oui.tsv`, so it can be cached to disk and re-loaded
/// with the existing `parseOuiTsv`.
String ouiTableToTsv(Map<String, String> table) {
  final out = StringBuffer();
  for (final entry in table.entries) {
    out.writeln('${entry.key}\t${entry.value}');
  }
  return out.toString();
}

/// Fetches the raw IEEE OUI CSV from [source]. The default implementation
/// hits the network directly; tests inject a fake to avoid real HTTP calls.
typedef OuiCsvFetcher = Future<String?> Function(Uri source);

Future<String?> _fetchOuiCsv(Uri source) async {
  final client = HttpClient();
  try {
    final request =
        await client.getUrl(source).timeout(const Duration(seconds: 20));
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return await response.transform(utf8.decoder).join().timeout(
          const Duration(seconds: 20),
        );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Refreshes a cached copy of the IEEE OUI registry on disk, so the bundled
/// `assets/oui.tsv` (which only updates between app releases) doesn't go
/// stale forever between them. Refreshing is best-effort: a failed fetch
/// (offline, non-200, parse error) leaves the existing cache (or the bundled
/// asset, if there is no cache yet) as the fallback.
class OuiRefresher {
  OuiRefresher({
    this.maxAge = const Duration(days: 30),
    Uri? source,
    OuiCsvFetcher? fetch,
  })  : source = source ?? Uri.parse('https://standards-oui.ieee.org/oui/oui.csv'),
        _fetch = fetch ?? _fetchOuiCsv;

  final Duration maxAge;
  final Uri source;
  final OuiCsvFetcher _fetch;

  /// Refreshes [cacheFile] in place if it's missing or older than [maxAge].
  /// Returns true if a refresh actually happened.
  Future<bool> refreshIfStale(File cacheFile) async {
    if (await cacheFile.exists()) {
      final age = DateTime.now().difference(await cacheFile.lastModified());
      if (age < maxAge) return false;
    }
    final csv = await _fetch(source);
    if (csv == null) return false;
    final table = parseOuiCsv(csv);
    if (table.isEmpty) return false;
    await cacheFile.create(recursive: true);
    await cacheFile.writeAsString(ouiTableToTsv(table));
    return true;
  }
}
