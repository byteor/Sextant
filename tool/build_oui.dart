// One-off build tool: transforms the IEEE OUI CSV (downloaded to /tmp/oui.csv
// from https://standards-oui.ieee.org/oui/oui.csv) into a compact
// `assets/oui.tsv` of `AABBCC\tVendor` lines that the app bundles and loads.
//
//   dart run tool/build_oui.dart
import 'dart:io';

void main() {
  final lines = File('/tmp/oui.csv').readAsLinesSync();
  final out = StringBuffer();
  var count = 0;
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = _parseCsvLine(line);
    if (fields.length < 3) continue;
    final oui = fields[1].trim().toUpperCase();
    final org = fields[2].trim();
    if (oui.length != 6 || org.isEmpty) continue;
    out.writeln('$oui\t$org');
    count++;
  }
  Directory('assets').createSync(recursive: true);
  File('assets/oui.tsv').writeAsStringSync(out.toString());
  stdout.writeln('Wrote assets/oui.tsv with $count entries.');
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
