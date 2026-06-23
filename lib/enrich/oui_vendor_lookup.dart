/// Parses the bundled `assets/oui.tsv` (`AABBCC\tVendor` per line) into an OUI
/// table keyed by uppercase 6-hex-digit prefix. Blank and malformed lines are
/// skipped.
Map<String, String> parseOuiTsv(String tsv) {
  final table = <String, String>{};
  for (final line in tsv.split('\n')) {
    final tab = line.indexOf('\t');
    if (tab != 6) continue;
    table[line.substring(0, 6)] = line.substring(tab + 1).trim();
  }
  return table;
}

/// Resolves a device manufacturer from a MAC address using its OUI (the first
/// three octets / 24-bit prefix assigned by the IEEE).
///
/// The [table] is keyed by uppercase 6-hex-digit OUI (e.g. `A483E7`). A bundled
/// IEEE snapshot is loaded into this table at startup; an online fallback for
/// unknown OUIs is layered on top in a later phase (hybrid lookup).
class OuiVendorLookup {
  const OuiVendorLookup(this.table);

  final Map<String, String> table;

  /// Returns the manufacturer for [mac], or null if the MAC is malformed or the
  /// OUI is unknown.
  String? vendorFor(String mac) {
    final hex = mac.replaceAll(RegExp('[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length < 6) return null;
    return table[hex.substring(0, 6)];
  }
}
