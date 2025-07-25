// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

part of '../../../flutter_map_tile_caching.dart';

/// A geographically line/locus region based off a list of coords and a [radius]
class LineRegion extends BaseRegion {
  /// Create a geographically line/locus region based off a list of coords and a
  /// [radius]
  const LineRegion(this.line, this.radius);

  /// The center line defined by a list of coordinates
  final List<LatLng> line;

  /// The offset of the outline from the [line] in all directions (in meters)
  final double radius;

  /// Generate the list of rectangle segments formed from the locus of this line
  ///
  /// Use the optional [overlap] argument to set the behaviour of the joints
  /// between segments:
  ///
  /// * -1: joined by closest corners (largest gap)
  /// * 0 (default): joined by centers
  /// * 1 (as downloaded): joined by further corners (largest overlap)
  Iterable<List<LatLng>> toOutlines([int overlap = 0]) sync* {
    if (overlap < -1 || overlap > 1) {
      throw ArgumentError('`overlap` must be between -1 and 1 inclusive');
    }

    if (line.isEmpty) return;

    const dist = Distance();
    final rad = radius * pi / 4;

    for (int i = 0; i < line.length - 1; i++) {
      final cp = line[i];
      final np = line[i + 1];

      final bearing = dist.bearing(cp, np);
      final clockwiseRotation =
          (90 + bearing) > 360 ? 360 - (90 + bearing) : (90 + bearing);
      final anticlockwiseRotation =
          (bearing - 90) < 0 ? 360 + (bearing - 90) : (bearing - 90);

      final tr = dist.offset(cp, rad, clockwiseRotation); // Top right
      final br = dist.offset(np, rad, clockwiseRotation); // Bottom right
      final bl = dist.offset(np, rad, anticlockwiseRotation); // Bottom left
      final tl = dist.offset(cp, rad, anticlockwiseRotation); // Top left

      if (overlap == 0) yield [tr, br, bl, tl];

      final r = overlap == -1;
      final os = i == 0;
      final oe = i == line.length - 2;

      yield [
        if (os) tr else dist.offset(tr, r ? rad : -rad, bearing),
        if (oe) br else dist.offset(br, r ? -rad : rad, bearing),
        if (oe) bl else dist.offset(bl, r ? -rad : rad, bearing),
        if (os) tl else dist.offset(tl, r ? rad : -rad, bearing),
      ];
    }
  }

  @override
  DownloadableRegion<LineRegion> toDownloadable({
    required int minZoom,
    required int maxZoom,
    required TileLayer options,
    int start = 1,
    int? end,
    Crs crs = const Epsg3857(),
  }) =>
      DownloadableRegion._(
        this,
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: options,
        start: start,
        end: end,
        crs: crs,
      );

  /// Flattens the result of [toOutlines] - its documentation is quoted below
  ///
  /// > Generate the list of rectangle segments formed from the locus of this
  /// > line
  /// >
  /// > Use the optional [overlap] argument to set the behaviour of the joints
  /// between segments:
  /// >
  /// > * -1: joined by closest corners (largest gap),
  /// > * 0 (default): joined by centers
  /// > * 1 (as downloaded): joined by further corners (most overlap)
  @override
  Iterable<LatLng> toOutline([int overlap = 1]) =>
      toOutlines(overlap).expand((x) => x);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineRegion &&
          other.radius == radius &&
          listEquals(line, other.line));

  @override
  int get hashCode => Object.hashAll([...line, radius]);
}
