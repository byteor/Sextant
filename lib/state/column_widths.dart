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
///
/// These defaults are deliberately tight: their sum (plus the icon column,
/// six 8px resize handles, and the table's 24px horizontal padding) must fit
/// within `main.dart`'s `WindowOptions.minimumSize` (820 logical pixels wide)
/// without overflowing — the device table has no horizontal-scroll fallback,
/// so anything wider would visibly break the moment a user shrinks the
/// window to its supported minimum. The "defaults keep the device table
/// within the app's minimum window width" test below (in
/// `column_widths_test.dart`) encodes this exact arithmetic and fails if
/// this regresses.
class ColumnWidths {
  const ColumnWidths({
    this.ip = 120,
    this.name = 140,
    this.mac = 130,
    this.vendor = 110,
    this.foundVia = _kFoundViaDefaultWidth,
    this.latency = 52,
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

/// The minimum width each column needs to show its header label in full —
/// measured from the current locale's text, so callers must remeasure when
/// the locale or font changes. "Open ports" has no persisted preferred width
/// (it's the table's flexible filler — see [ResizableColumn]'s doc comment),
/// so its minimum lives here rather than in [ColumnWidths].
typedef ColumnMinWidths = ({
  double ip,
  double name,
  double mac,
  double vendor,
  double openPorts,
  double foundVia,
  double latency,
});

/// On-screen widths for all seven of the device table's columns (the six
/// [ResizableColumn]s plus "Open ports"), fitted to the space actually
/// available this frame.
///
/// Shrinking happens in two stages before anything is allowed to overflow:
/// first "Open ports" gives up its leftover space, then — if that still
/// isn't enough — the six resizable columns shrink proportionally by their
/// slack (`preferred - min`) down to [ColumnMinWidths], which never clips a
/// header label. Only once every column is already at its minimum and the
/// row still doesn't fit does [overflows] become true, telling the caller to
/// fall back to horizontal scrolling instead of shrinking (or clipping)
/// further.
class EffectiveColumnWidths {
  const EffectiveColumnWidths({
    required this.ip,
    required this.name,
    required this.mac,
    required this.vendor,
    required this.openPorts,
    required this.foundVia,
    required this.latency,
    required this.naturalWidth,
    required this.overflows,
  });

  final double ip;
  final double name;
  final double mac;
  final double vendor;
  final double openPorts;
  final double foundVia;
  final double latency;

  /// Combined width of all seven columns at these widths. Equal to the space
  /// that was available when [overflows] is false; equal to the sum of every
  /// column's minimum when [overflows] is true (the width the caller should
  /// give the horizontal-scroll content).
  final double naturalWidth;

  /// True once [availableWidth] was too small to fit every column at its
  /// minimum — the caller should switch to horizontal scrolling rather than
  /// shrink (or clip) any further.
  final bool overflows;

  static EffectiveColumnWidths compute({
    required ColumnWidths preferred,
    required ColumnMinWidths minWidths,
    required double availableWidth,
  }) {
    final available = math.max(0.0, availableWidth);

    // A column can already be manually dragged (via its resize handle)
    // narrower than its header text — that's an explicit user choice, not
    // something this pass should undo. Clamping each minimum to at most its
    // preferred width means a column like that simply contributes no slack,
    // rather than making the whole row's minimum wider than the user chose.
    final minIp = math.min(minWidths.ip, preferred.ip);
    final minName = math.min(minWidths.name, preferred.name);
    final minMac = math.min(minWidths.mac, preferred.mac);
    final minVendor = math.min(minWidths.vendor, preferred.vendor);
    final minFoundVia = math.min(minWidths.foundVia, preferred.foundVia);
    final minLatency = math.min(minWidths.latency, preferred.latency);
    final minOpenPorts = minWidths.openPorts;

    final preferredSum6 =
        preferred.ip +
        preferred.name +
        preferred.mac +
        preferred.vendor +
        preferred.foundVia +
        preferred.latency;
    final minSum6 =
        minIp + minName + minMac + minVendor + minFoundVia + minLatency;
    final minAll = minSum6 + minOpenPorts;

    if (available >= preferredSum6 + minOpenPorts) {
      // Plenty of room: the six columns keep their stored widths, and
      // "Open ports" absorbs whatever's left over.
      return EffectiveColumnWidths(
        ip: preferred.ip,
        name: preferred.name,
        mac: preferred.mac,
        vendor: preferred.vendor,
        foundVia: preferred.foundVia,
        latency: preferred.latency,
        openPorts: available - preferredSum6,
        naturalWidth: available,
        overflows: false,
      );
    }

    if (available >= minAll) {
      // Not enough room for every column's preferred width plus "Open
      // ports"'s minimum: shrink the six resizable columns proportionally by
      // their slack until "Open ports" gets exactly its minimum.
      final targetSum6 = available - minOpenPorts;
      final totalSlack = preferredSum6 - minSum6;
      final deficit = preferredSum6 - targetSum6;
      double shrink(double preferredWidth, double minWidth) {
        if (totalSlack <= 0) return minWidth;
        final slack = preferredWidth - minWidth;
        return preferredWidth - deficit * (slack / totalSlack);
      }

      return EffectiveColumnWidths(
        ip: shrink(preferred.ip, minIp),
        name: shrink(preferred.name, minName),
        mac: shrink(preferred.mac, minMac),
        vendor: shrink(preferred.vendor, minVendor),
        foundVia: shrink(preferred.foundVia, minFoundVia),
        latency: shrink(preferred.latency, minLatency),
        openPorts: minOpenPorts,
        naturalWidth: available,
        overflows: false,
      );
    }

    // Every column is already at its minimum and it still doesn't fit:
    // stop shrinking. The caller falls back to horizontal scrolling.
    return EffectiveColumnWidths(
      ip: minIp,
      name: minName,
      mac: minMac,
      vendor: minVendor,
      foundVia: minFoundVia,
      latency: minLatency,
      openPorts: minOpenPorts,
      naturalWidth: minAll,
      overflows: true,
    );
  }
}
