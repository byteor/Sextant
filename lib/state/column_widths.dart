import 'dart:math' as math;

/// Identifies one resizable column in the device table. The leading icon
/// column and the "Open ports" column are not in this enum: the icon column
/// has no text to make room for, and "Open ports" is the table's flexible
/// filler, automatically absorbing whatever space these columns don't use.
enum ResizableColumn { ip, name, mac, vendor, foundVia, latency }

/// The smallest width a resizable column can be dragged to — small enough to
/// stay out of the way, large enough that a column never fully disappears.
const kMinColumnWidth = 40.0;

/// Default width of the "Found via" column: wide enough to fit every
/// `DiscoverySource` icon (16px, with 4px `Wrap` spacing between icons) on
/// one line without wrapping. `DiscoverySource` currently has 7 values:
/// `7 * 16.0 + 6 * 4.0 = 136.0`. This is a literal (not computed from
/// `DiscoverySource.values.length`) because Dart's constant evaluator
/// can't fold an enum's `.values.length` into a const default parameter
/// value — verified directly: `dart` rejects
/// `this.x = DiscoverySource.values.length * 1.0` with "The property
/// 'length' can't be accessed ... in a constant expression." Update this
/// literal if `DiscoverySource` gains or loses a value — the test in
/// `column_widths_test.dart` computes the expected width independently at
/// runtime (where `.length` access is unrestricted) and fails if this drifts
/// out of sync.
const _kFoundViaDefaultWidth = 136.0;

/// Current pixel widths of the device table's resizable columns. Immutable —
/// [resized] returns a new instance with one column adjusted.
class ColumnWidths {
  const ColumnWidths({
    this.ip = 130,
    this.name = 220,
    this.mac = 150,
    this.vendor = 160,
    this.foundVia = _kFoundViaDefaultWidth,
    this.latency = 56,
  });

  final double ip;
  final double name;
  final double mac;
  final double vendor;
  final double foundVia;
  final double latency;

  double of(ResizableColumn column) => switch (column) {
        ResizableColumn.ip => ip,
        ResizableColumn.name => name,
        ResizableColumn.mac => mac,
        ResizableColumn.vendor => vendor,
        ResizableColumn.foundVia => foundVia,
        ResizableColumn.latency => latency,
      };

  /// Returns a copy with [column] adjusted by [delta] (positive to grow,
  /// negative to shrink), clamped so it never drops below [kMinColumnWidth].
  ColumnWidths resized(ResizableColumn column, double delta) {
    final next = math.max(kMinColumnWidth, of(column) + delta);
    return switch (column) {
      ResizableColumn.ip => ColumnWidths(
          ip: next,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.name => ColumnWidths(
          ip: ip,
          name: next,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.mac => ColumnWidths(
          ip: ip,
          name: name,
          mac: next,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.vendor => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: next,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.foundVia => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: next,
          latency: latency,
        ),
      ResizableColumn.latency => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: next,
        ),
    };
  }
}
