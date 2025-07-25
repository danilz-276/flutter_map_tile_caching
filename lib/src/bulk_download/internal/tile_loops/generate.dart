// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

part of 'shared.dart';

/// A set of methods for each type of [BaseRegion] that generates the
/// coordinates of every tile within the specified [DownloadableRegion]
///
/// These methods must be run within seperate isolates, as they do heavy,
/// potentially lengthy computation. They do perform multiple-communication,
/// sending a new coordinate after they recieve a request message only. They
/// will kill themselves after there are no tiles left to generate.
///
/// See [TileCounters] for methods that do not generate each coordinate, but
/// just count the number of tiles with a more efficient method.
///
/// The number of tiles returned by each method must match the number of tiles
/// returned by the respective method in [TileCounters]. This is enforced by
/// automated tests.
@internal
class TileGenerators {
  /// Generate the coordinates of each tile within a [DownloadableRegion] with
  /// generic type [RectangleRegion]
  @internal
  static Future<void> rectangleTiles(
    ({SendPort sendPort, DownloadableRegion<RectangleRegion> region}) input, {
    StreamQueue? multiRequestQueue,
  }) async {
    final region = input.region;
    final sendPort = input.sendPort;
    final inMulti = multiRequestQueue != null;

    final StreamQueue requestQueue;
    if (inMulti) {
      requestQueue = multiRequestQueue;
    } else {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);
      requestQueue = StreamQueue(receivePort);
    }

    final northWest = region.originalRegion.bounds.northWest;
    final southEast = region.originalRegion.bounds.southEast;

    int tileCounter = -1;
    final start = region.start - 1;
    final end = (region.end ?? double.infinity) - 1;

    for (double zoomLvl = region.minZoom.toDouble();
        zoomLvl <= region.maxZoom;
        zoomLvl++) {
      final nwPoint = (region.crs.latLngToPoint(northWest, zoomLvl) /
              region.options.tileSize)
          .floor();
      final sePoint = (region.crs.latLngToPoint(southEast, zoomLvl) /
                  region.options.tileSize)
              .ceil() -
          const Point(1, 1);

      for (int x = nwPoint.x; x <= sePoint.x; x++) {
        for (int y = nwPoint.y; y <= sePoint.y; y++) {
          tileCounter++;
          if (tileCounter < start) continue;
          if (tileCounter > end) {
            if (!inMulti) Isolate.exit();
            return;
          }

          await requestQueue.next;
          sendPort.send((x, y, zoomLvl.toInt()));
        }
      }
    }

    if (!inMulti) Isolate.exit();
  }

  /// Generate the coordinates of each tile within a [DownloadableRegion] with
  /// generic type [CircleRegion]
  @internal
  static Future<void> circleTiles(
    ({SendPort sendPort, DownloadableRegion<CircleRegion> region}) input, {
    StreamQueue? multiRequestQueue,
  }) async {
    final region = input.region;
    final sendPort = input.sendPort;
    final inMulti = multiRequestQueue != null;

    final StreamQueue requestQueue;
    if (inMulti) {
      requestQueue = multiRequestQueue;
    } else {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);
      requestQueue = StreamQueue(receivePort);
    }

    int tileCounter = -1;
    final start = region.start - 1;
    final end = (region.end ?? double.infinity) - 1;

    final edgeTile = const Distance(roundResult: false).offset(
      region.originalRegion.center,
      region.originalRegion.radius * 1000,
      0,
    );

    for (int zoomLvl = region.minZoom; zoomLvl <= region.maxZoom; zoomLvl++) {
      final centerTile = (region.crs.latLngToPoint(
                region.originalRegion.center,
                zoomLvl.toDouble(),
              ) /
              region.options.tileSize)
          .floor();

      final radius = centerTile.y -
          (region.crs.latLngToPoint(edgeTile, zoomLvl.toDouble()) /
                  region.options.tileSize)
              .floor()
              .y;

      final radiusSquared = radius * radius;

      if (radius == 0) {
        tileCounter++;
        if (tileCounter < start) continue;
        if (tileCounter > end) {
          if (!inMulti) Isolate.exit();
          return;
        }

        await requestQueue.next;
        sendPort.send((centerTile.x, centerTile.y, zoomLvl));

        continue;
      }

      if (radius == 1) {
        tileCounter++;
        if (tileCounter >= start) {
          if (tileCounter > end) {
            if (!inMulti) Isolate.exit();
            return;
          }

          await requestQueue.next;
          sendPort.send((centerTile.x, centerTile.y, zoomLvl));
        }

        tileCounter++;
        if (tileCounter >= start) {
          if (tileCounter > end) {
            if (!inMulti) Isolate.exit();
            return;
          }

          await requestQueue.next;
          sendPort.send((centerTile.x, centerTile.y - 1, zoomLvl));
        }

        tileCounter++;
        if (tileCounter >= start) {
          if (tileCounter > end) {
            if (!inMulti) Isolate.exit();
            return;
          }

          await requestQueue.next;
          sendPort.send((centerTile.x - 1, centerTile.y, zoomLvl));
        }

        tileCounter++;
        if (tileCounter >= start) {
          if (tileCounter > end) {
            if (!inMulti) Isolate.exit();
            return;
          }

          await requestQueue.next;
          sendPort.send((centerTile.x - 1, centerTile.y - 1, zoomLvl));
        }

        continue;
      }

      for (int dy = 0; dy < radius; dy++) {
        final mdx = sqrt(radiusSquared - dy * dy).floor();
        for (int dx = -mdx - 1; dx <= mdx; dx++) {
          tileCounter++;
          if (tileCounter >= start) {
            if (tileCounter > end) {
              if (!inMulti) Isolate.exit();
              return;
            }

            await requestQueue.next;
            sendPort.send((dx + centerTile.x, dy + centerTile.y, zoomLvl));
          }

          tileCounter++;
          if (tileCounter >= start) {
            if (tileCounter > end) {
              if (!inMulti) Isolate.exit();
              return;
            }

            await requestQueue.next;
            sendPort.send((dx + centerTile.x, -dy - 1 + centerTile.y, zoomLvl));
          }
        }
      }
    }

    if (!inMulti) Isolate.exit();
  }

  /// Generate the coordinates of each tile within a [DownloadableRegion] with
  /// generic type [LineRegion]
  @internal
  static Future<void> lineTiles(
    ({SendPort sendPort, DownloadableRegion<LineRegion> region}) input, {
    StreamQueue? multiRequestQueue,
  }) async {
    // This took some time and is fairly complicated, so this is the overall
    // explanation:
    // 1. Given 4 `LatLng` points, create a 'straight' rectangle around the
    //    'rotated' rectangle, that can be defined with just 2 `LatLng` points
    // 2. Convert the straight rectangle into tile numbers, and loop through the
    //    same as `rectangleTiles`
    // 3. For every generated tile number (which represents top-left of the
    //    tile), generate the rest of the tile corners
    // 4. Check whether the square tile overlaps the rotated rectangle from the
    //    start, add it to the list if it does
    // 5. Keep track of the number of overlaps per row: if there was one overlap
    //    and now there isn't, skip the rest of the row because we can be sure
    //    there are no more tiles

    // Overlap algorithm originally in Python, available at https://stackoverflow.com/a/56962827/11846040
    bool overlap(_Polygon a, _Polygon b) {
      for (int x = 0; x < 2; x++) {
        final _Polygon polygon = x == 0 ? a : b;

        for (int i1 = 0; i1 < polygon.points.length; i1++) {
          final i2 = (i1 + 1) % polygon.points.length;
          final p1 = polygon.points[i1];
          final p2 = polygon.points[i2];

          final normal = Point(p2.y - p1.y, p1.x - p2.x);

          var minA = largestInt;
          var maxA = smallestInt;
          for (final p in a.points) {
            final projected = normal.x * p.x + normal.y * p.y;
            if (projected < minA) minA = projected;
            if (projected > maxA) maxA = projected;
          }

          var minB = largestInt;
          var maxB = smallestInt;
          for (final p in b.points) {
            final projected = normal.x * p.x + normal.y * p.y;
            if (projected < minB) minB = projected;
            if (projected > maxB) maxB = projected;
          }

          if (maxA < minB || maxB < minA) return false;
        }
      }

      return true;
    }

    final region = input.region;
    final sendPort = input.sendPort;
    final inMulti = multiRequestQueue != null;

    final StreamQueue requestQueue;
    if (inMulti) {
      requestQueue = multiRequestQueue;
    } else {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);
      requestQueue = StreamQueue(receivePort);
    }

    final lineOutline = region.originalRegion.toOutlines(1);

    int tileCounter = -1;
    final start = region.start - 1;
    final end = (region.end ?? double.infinity) - 1;

    for (double zoomLvl = region.minZoom.toDouble();
        zoomLvl <= region.maxZoom;
        zoomLvl++) {
      final generatedTiles = <int>[];

      for (final rect in lineOutline) {
        final rotatedRectangle = (
          bottomLeft: rect[0],
          bottomRight: rect[1],
          topRight: rect[2],
          topLeft: rect[3],
        );

        final rotatedRectangleLats = [
          rotatedRectangle.topLeft.latitude,
          rotatedRectangle.topRight.latitude,
          rotatedRectangle.bottomLeft.latitude,
          rotatedRectangle.bottomRight.latitude,
        ];
        final rotatedRectangleLngs = [
          rotatedRectangle.topLeft.longitude,
          rotatedRectangle.topRight.longitude,
          rotatedRectangle.bottomLeft.longitude,
          rotatedRectangle.bottomRight.longitude,
        ];

        final rotatedRectangleNW =
            (region.crs.latLngToPoint(rotatedRectangle.topLeft, zoomLvl) /
                    region.options.tileSize)
                .floor();
        final rotatedRectangleNE =
            (region.crs.latLngToPoint(rotatedRectangle.topRight, zoomLvl) /
                        region.options.tileSize)
                    .ceil() -
                const Point(1, 0);
        final rotatedRectangleSW =
            (region.crs.latLngToPoint(rotatedRectangle.bottomLeft, zoomLvl) /
                        region.options.tileSize)
                    .ceil() -
                const Point(0, 1);
        final rotatedRectangleSE =
            (region.crs.latLngToPoint(rotatedRectangle.bottomRight, zoomLvl) /
                        region.options.tileSize)
                    .ceil() -
                const Point(1, 1);

        final straightRectangleNW = (region.crs.latLngToPoint(
                  LatLng(rotatedRectangleLats.max, rotatedRectangleLngs.min),
                  zoomLvl,
                ) /
                region.options.tileSize)
            .floor();
        final straightRectangleSE = (region.crs.latLngToPoint(
                      LatLng(
                        rotatedRectangleLats.min,
                        rotatedRectangleLngs.max,
                      ),
                      zoomLvl,
                    ) /
                    region.options.tileSize)
                .ceil() -
            const Point(1, 1);

        for (int x = straightRectangleNW.x; x <= straightRectangleSE.x; x++) {
          bool foundOverlappingTile = false;
          for (int y = straightRectangleNW.y; y <= straightRectangleSE.y; y++) {
            final tile = _Polygon(
              Point(x, y),
              Point(x + 1, y),
              Point(x + 1, y + 1),
              Point(x, y + 1),
            );
            if (generatedTiles.contains(tile.hashCode)) continue;

            if (overlap(
              _Polygon(
                rotatedRectangleNW,
                rotatedRectangleNE,
                rotatedRectangleSE,
                rotatedRectangleSW,
              ),
              tile,
            )) {
              generatedTiles.add(tile.hashCode);
              foundOverlappingTile = true;

              tileCounter++;
              if (tileCounter < start) continue;
              if (tileCounter > end) {
                if (!inMulti) Isolate.exit();
                return;
              }

              await requestQueue.next;
              sendPort.send((x, y, zoomLvl.toInt()));
            } else if (foundOverlappingTile) {
              break;
            }
          }
        }
      }
    }

    if (!inMulti) Isolate.exit();
  }

  /// Generate the coordinates of each tile within a [DownloadableRegion] with
  /// generic type [CustomPolygonRegion]
  @internal
  static Future<void> customPolygonTiles(
    ({
      SendPort sendPort,
      DownloadableRegion<CustomPolygonRegion> region
    }) input, {
    StreamQueue? multiRequestQueue,
  }) async {
    final region = input.region;
    final sendPort = input.sendPort;
    final inMulti = multiRequestQueue != null;

    final StreamQueue requestQueue;
    if (inMulti) {
      requestQueue = multiRequestQueue;
    } else {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);
      requestQueue = StreamQueue(receivePort);
    }

    int tileCounter = -1;
    final start = region.start - 1;
    final end = (region.end ?? double.infinity) - 1;

    for (double zoomLvl = region.minZoom.toDouble();
        zoomLvl <= region.maxZoom;
        zoomLvl++) {
      final allOutlineTiles = <Point<int>>{};

      final pointsOutline = region.originalRegion.outline
          .map((e) => region.crs.latLngToPoint(e, zoomLvl).floor());

      for (final triangle in Earcut.triangulateFromPoints(
        pointsOutline.map((e) => e.toDoublePoint()),
      ).map(pointsOutline.elementAt).slices(3)) {
        final outlineTiles = {
          ..._bresenhamsLGA(
            Point(triangle[0].x, triangle[0].y),
            Point(triangle[1].x, triangle[1].y),
            unscaleBy: region.options.tileSize,
          ),
          ..._bresenhamsLGA(
            Point(triangle[1].x, triangle[1].y),
            Point(triangle[2].x, triangle[2].y),
            unscaleBy: region.options.tileSize,
          ),
          ..._bresenhamsLGA(
            Point(triangle[2].x, triangle[2].y),
            Point(triangle[0].x, triangle[0].y),
            unscaleBy: region.options.tileSize,
          ),
        };
        allOutlineTiles.addAll(outlineTiles);

        final byY = <int, Set<int>>{};
        for (final Point(:x, :y) in outlineTiles) {
          (byY[y] ??= {}).add(x);
        }

        for (final MapEntry(key: y, value: xs) in byY.entries) {
          final xsRawMin = xs.min;
          int i = 0;
          for (; xs.contains(xsRawMin + i); i++) {}
          final xsMin = xsRawMin + i;

          final xsRawMax = xs.max;
          i = 0;
          for (; xs.contains(xsRawMax - i); i++) {}
          final xsMax = xsRawMax - i;

          for (int x = xsMin; x <= xsMax; x++) {
            tileCounter++;
            if (tileCounter < start) continue;
            if (tileCounter > end) {
              if (!inMulti) Isolate.exit();
              return;
            }

            await requestQueue.next;
            sendPort.send((x, y, zoomLvl.toInt()));
          }
        }
      }

      for (final Point(:x, :y) in allOutlineTiles) {
        tileCounter++;
        if (tileCounter < start) continue;
        if (tileCounter > end) {
          if (!inMulti) Isolate.exit();
          return;
        }

        await requestQueue.next;
        sendPort.send((x, y, zoomLvl.toInt()));
      }
    }

    if (!inMulti) Isolate.exit();
  }

  /// Generate the coordinates of each tile within a [DownloadableRegion] with
  /// generic type [MultiRegion]
  @internal
  static Future<void> multiTiles(
    ({SendPort sendPort, DownloadableRegion<MultiRegion> region}) input, {
    StreamQueue? multiRequestQueue,
  }) async {
    final region = input.region;
    final inMulti = multiRequestQueue != null;

    final StreamQueue requestQueue;
    if (inMulti) {
      requestQueue = multiRequestQueue;
    } else {
      final receivePort = ReceivePort();
      input.sendPort.send(receivePort.sendPort);
      requestQueue = StreamQueue(receivePort);
    }

    for (final subRegion in region.originalRegion.regions) {
      await subRegion
          .toDownloadable(
            minZoom: region.minZoom,
            maxZoom: region.maxZoom,
            options: region.options,
            start: region.start,
            end: region.end,
            crs: region.crs,
          )
          .when(
            rectangle: (region) => rectangleTiles(
              (sendPort: input.sendPort, region: region),
              multiRequestQueue: requestQueue,
            ),
            circle: (region) => circleTiles(
              (sendPort: input.sendPort, region: region),
              multiRequestQueue: requestQueue,
            ),
            line: (region) => lineTiles(
              (sendPort: input.sendPort, region: region),
              multiRequestQueue: requestQueue,
            ),
            customPolygon: (region) => customPolygonTiles(
              (sendPort: input.sendPort, region: region),
              multiRequestQueue: requestQueue,
            ),
            multi: (region) => multiTiles(
              (sendPort: input.sendPort, region: region),
              multiRequestQueue: requestQueue,
            ),
          );
    }

    if (!inMulti) Isolate.exit();
  }
}
