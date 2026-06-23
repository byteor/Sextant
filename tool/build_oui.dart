import 'dart:io';

import 'package:sextant/enrich/oui_refresh.dart';

/// One-off generator for `assets/oui.tsv` from the IEEE OUI registry CSV
/// (https://standards-oui.ieee.org/oui/oui.csv). Run manually when the
/// bundled snapshot needs updating for a release:
///   dart run tool/build_oui.dart
/// (download the CSV to /tmp/oui.csv first).
void main() {
  final csv = File('/tmp/oui.csv').readAsStringSync();
  final table = parseOuiCsv(csv);
  Directory('assets').createSync(recursive: true);
  File('assets/oui.tsv').writeAsStringSync(ouiTableToTsv(table));
  stdout.writeln('Wrote assets/oui.tsv with ${table.length} entries.');
}
