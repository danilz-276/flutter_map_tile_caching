// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

/// A plugin for 'flutter_map' providing advanced offline functionality
///
/// * [GitHub Repository](https://github.com/JaffaKetchup/flutter_map_tile_caching)
/// * [pub.dev Package](https://pub.dev/packages/flutter_map_tile_caching)
///
/// * [Documentation Site](https://fmtc.jaffaketchup.dev/)
/// * [Full API Reference](https://pub.dev/documentation/flutter_map_tile_caching/latest/flutter_map_tile_caching/flutter_map_tile_caching-library.html)
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' hide readBytes;
import 'package:http/http.dart' as http show readBytes;
import 'package:http/io_client.dart';
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

import 'src/backend/export_external.dart';
import 'src/backend/export_internal.dart';
import 'src/bulk_download/internal/instance.dart';
import 'src/bulk_download/internal/rate_limited_stream.dart';
import 'src/bulk_download/internal/tile_loops/shared.dart';
import 'src/providers/image_provider/browsing_errors.dart';

export 'src/backend/export_external.dart';
export 'src/providers/image_provider/browsing_errors.dart';

part 'src/bulk_download/external/download_progress.dart';
part 'src/bulk_download/external/tile_event.dart';
part 'src/bulk_download/internal/control_cmds.dart';
part 'src/bulk_download/internal/manager.dart';
part 'src/bulk_download/internal/thread.dart';
part 'src/providers/tile_loading_interceptor/result.dart';
part 'src/providers/tile_loading_interceptor/map_typedef.dart';
part 'src/providers/tile_loading_interceptor/result_path.dart';
part 'src/providers/image_provider/image_provider.dart';
part 'src/providers/image_provider/internal_tile_browser.dart';
part 'src/providers/tile_provider/custom_user_agent_compat_map.dart';
part 'src/providers/tile_provider/strategies.dart';
part 'src/providers/tile_provider/tile_provider.dart';
part 'src/providers/tile_provider/typedefs.dart';
part 'src/regions/base_region.dart';
part 'src/regions/downloadable_region.dart';
part 'src/regions/shapes/multi.dart';
part 'src/regions/recovered_region.dart';
part 'src/regions/shapes/circle.dart';
part 'src/regions/shapes/custom_polygon.dart';
part 'src/regions/shapes/line.dart';
part 'src/regions/shapes/rectangle.dart';
part 'src/root/external.dart';
part 'src/root/recovery.dart';
part 'src/root/root.dart';
part 'src/root/statistics.dart';
part 'src/store/download.dart';
part 'src/store/manage.dart';
part 'src/store/metadata.dart';
part 'src/store/statistics.dart';
part 'src/store/store.dart';
