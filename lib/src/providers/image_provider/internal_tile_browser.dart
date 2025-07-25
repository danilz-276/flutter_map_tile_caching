// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

part of '../../../flutter_map_tile_caching.dart';

Future<Uint8List> _internalTileBrowser({
  required TileCoordinates coords,
  required TileLayer options,
  required FMTCTileProvider provider,
  required bool requireValidImage,
  required _TLIRConstructor? currentTLIR,
}) async {
  late final compiledReadableStores = provider._compileReadableStores();

  void registerHit(List<String> storeNames) {
    currentTLIR?.hitOrMiss = true;
    if (provider.recordHitsAndMisses) {
      FMTCBackendAccess.internal.incrementStoreHits(storeNames: storeNames);
    }
  }

  void registerMiss() {
    currentTLIR?.hitOrMiss = false;
    if (provider.recordHitsAndMisses) {
      FMTCBackendAccess.internal
          .incrementStoreMisses(storeNames: compiledReadableStores);
    }
  }

  final networkUrl = provider.getTileUrl(coords, options);
  final matcherUrl = provider.urlTransformer?.call(networkUrl) ?? networkUrl;

  currentTLIR?.networkUrl = networkUrl;
  currentTLIR?.storageSuitableUID = matcherUrl;

  late final DateTime cacheFetchStartTime;
  if (currentTLIR != null) cacheFetchStartTime = DateTime.now();

  final (
    tile: existingTile,
    intersectedStoreNames: intersectedExistingStores,
    allStoreNames: allExistingStores,
  ) = await FMTCBackendAccess.internal.readTile(
    url: matcherUrl,
    storeNames: compiledReadableStores,
  );

  currentTLIR?.cacheFetchDuration =
      DateTime.now().difference(cacheFetchStartTime);

  if (allExistingStores.isNotEmpty) {
    currentTLIR?.existingStores = allExistingStores;
  }

  final tileRetrievableFromOtherStoresAsFallback = existingTile != null &&
      provider.useOtherStoresAsFallbackOnly &&
      provider.stores.keys
          .toSet()
          .intersection(allExistingStores.toSet())
          .isEmpty;

  currentTLIR?.tileRetrievableFromOtherStoresAsFallback =
      tileRetrievableFromOtherStoresAsFallback;

  // Prepare a list of image bytes and prefill if there's already a cached
  // tile available
  Uint8List? bytes;
  if (existingTile != null) bytes = existingTile.bytes;

  // If there is a cached tile that's in date available, use it
  final needsUpdating = existingTile != null &&
      (provider.loadingStrategy == BrowseLoadingStrategy.onlineFirst ||
          (provider.cachedValidDuration != Duration.zero &&
              DateTime.timestamp().millisecondsSinceEpoch -
                      existingTile.lastModified.millisecondsSinceEpoch >
                  provider.cachedValidDuration.inMilliseconds));

  currentTLIR?.needsUpdating = needsUpdating;

  if (existingTile != null &&
      !needsUpdating &&
      !tileRetrievableFromOtherStoresAsFallback) {
    currentTLIR?.resultPath =
        TileLoadingInterceptorResultPath.perfectFromStores;

    registerHit(intersectedExistingStores);
    return bytes!;
  }

  // If a tile is not available and cache only mode is in use, just fail
  // before attempting a network call
  if (provider.loadingStrategy == BrowseLoadingStrategy.cacheOnly) {
    if (existingTile != null) {
      currentTLIR?.resultPath =
          TileLoadingInterceptorResultPath.cacheOnlyFromOtherStores;

      registerMiss();
      return bytes!;
    }

    throw FMTCBrowsingError(
      type: FMTCBrowsingErrorType.missingInCacheOnlyMode,
      networkUrl: networkUrl,
      storageSuitableUID: matcherUrl,
    );
  }

  // Setup a network request for the tile & handle network exceptions
  final Response response;

  late final DateTime networkFetchStartTime;
  if (currentTLIR != null) networkFetchStartTime = DateTime.now();

  try {
    if (provider.fakeNetworkDisconnect) {
      throw const SocketException(
        'Faked `SocketException` due to `fakeNetworkDisconnect` flag set',
      );
    }
    response = await provider.httpClient
        .get(Uri.parse(networkUrl), headers: provider.headers);
  } catch (e) {
    if (existingTile != null) {
      currentTLIR?.resultPath =
          TileLoadingInterceptorResultPath.cacheAsFallback;

      registerMiss();
      return bytes!;
    }

    throw FMTCBrowsingError(
      type: e is SocketException
          ? FMTCBrowsingErrorType.noConnectionDuringFetch
          : FMTCBrowsingErrorType.unknownFetchException,
      networkUrl: networkUrl,
      storageSuitableUID: matcherUrl,
      originalError: e,
    );
  }

  currentTLIR?.networkFetchDuration =
      DateTime.now().difference(networkFetchStartTime);

  // Check whether the network response is not 200 OK
  if (response.statusCode != 200) {
    if (existingTile != null) {
      currentTLIR?.resultPath =
          TileLoadingInterceptorResultPath.cacheAsFallback;

      registerMiss();
      return bytes!;
    }

    throw FMTCBrowsingError(
      type: FMTCBrowsingErrorType.negativeFetchResponse,
      networkUrl: networkUrl,
      storageSuitableUID: matcherUrl,
      response: response,
    );
  }

  // Perform a secondary check to ensure that the bytes recieved actually
  // encode a valid image
  if (requireValidImage) {
    late final Object? isValidImageData;

    try {
      isValidImageData = (await (await instantiateImageCodec(
                response.bodyBytes,
                targetWidth: 8,
                targetHeight: 8,
              ))
                      .getNextFrame())
                  .image
                  .width >
              0
          ? null
          : Exception('Image was decodable, but had a width of 0');
      // We don't care about the exact error
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      isValidImageData = e;
    }

    if (isValidImageData != null) {
      if (existingTile != null) {
        currentTLIR?.resultPath =
            TileLoadingInterceptorResultPath.cacheAsFallback;

        registerMiss();
        return bytes!;
      }

      throw FMTCBrowsingError(
        type: FMTCBrowsingErrorType.invalidImageData,
        networkUrl: networkUrl,
        storageSuitableUID: matcherUrl,
        response: response,
        originalError: isValidImageData,
      );
    }
  }

  // Find the stores that need to have this tile written to, depending on
  // their read/write settings
  // At this point, we've downloaded the tile anyway, so we might as well
  // write the stores that allow it, even if the existing tile hasn't expired
  final writeTileToSpecified = provider.stores.entries
      .where(
        (e) => switch (e.value) {
          null => false,
          BrowseStoreStrategy.read => false,
          BrowseStoreStrategy.readUpdate =>
            intersectedExistingStores.contains(e.key),
          BrowseStoreStrategy.readUpdateCreate => true,
        },
      )
      .map((e) => e.key);

  final writeTileToIntermediate =
      (provider.otherStoresStrategy == BrowseStoreStrategy.readUpdate &&
                  existingTile != null
              ? writeTileToSpecified.followedBy(
                  intersectedExistingStores
                      .whereNot((e) => provider.stores.containsKey(e)),
                )
              : writeTileToSpecified)
          .toSet()
          .toList(growable: false);

  // Cache tile to necessary stores
  if (writeTileToIntermediate.isNotEmpty ||
      provider.otherStoresStrategy == BrowseStoreStrategy.readUpdateCreate) {
    final writeOp = FMTCBackendAccess.internal.writeTile(
      storeNames: writeTileToIntermediate,
      writeAllNotIn:
          provider.otherStoresStrategy == BrowseStoreStrategy.readUpdateCreate
              ? provider.stores.keys.toList(growable: false)
              : null,
      url: matcherUrl,
      bytes: response.bodyBytes,
    );
    currentTLIR?.storesWriteResult = writeOp;

    unawaited(
      writeOp.then((result) {
        final createdIn =
            result.entries.where((e) => e.value).map((e) => e.key);

        // Clear out old tiles if the maximum store length has been exceeded
        // We only need to even attempt this if the number of tiles has changed
        if (createdIn.isEmpty) return;

        // Internally debounced, so we don't need to debounce here
        FMTCBackendAccess.internal.removeOldestTilesAboveLimit(
          storeNames: createdIn.toList(growable: false),
        );
      }),
    );
  }

  currentTLIR?.resultPath = TileLoadingInterceptorResultPath.fetchedFromNetwork;

  registerMiss();
  return response.bodyBytes;
}
