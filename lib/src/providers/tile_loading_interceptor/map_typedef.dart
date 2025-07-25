// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

part of '../../../flutter_map_tile_caching.dart';

/// Mapping of [TileCoordinates] to [TileLoadingInterceptorResult]
///
/// Used within [ValueNotifier]s, which are updated when a tile completes
/// loading.
typedef TileLoadingInterceptorMap
    = Map<TileCoordinates, TileLoadingInterceptorResult>;
