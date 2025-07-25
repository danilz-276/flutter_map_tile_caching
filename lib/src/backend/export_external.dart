// Copyright © Luka S (JaffaKetchup) under GPL-v3
// A full license can be found at .\LICENSE

export 'errors/errors.dart';
export 'impls/web_noop/backend.dart'
    if (dart.library.ffi) 'impls/objectbox/backend/backend.dart';
export 'interfaces/backend/backend.dart';
export 'interfaces/backend/internal.dart';
export 'interfaces/backend/internal_thread_safe.dart';
