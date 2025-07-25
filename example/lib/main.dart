import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/screens/export/export.dart';
import 'src/screens/import/import.dart';
import 'src/screens/initialisation_error/initialisation_error.dart';
import 'src/screens/main/main.dart';
import 'src/screens/store_editor/store_editor.dart';
import 'src/shared/misc/shared_preferences.dart';
import 'src/shared/state/download_configuration_provider.dart';
import 'src/shared/state/download_provider.dart';
import 'src/shared/state/general_provider.dart';
import 'src/shared/state/recoverable_regions_provider.dart';
import 'src/shared/state/region_selection_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sharedPrefs = await SharedPreferences.getInstance();

  Object? initErr;
  try {
    await FMTCObjectBoxBackend().initialise();
    // We don't know what errors will be thrown, we want to handle them all
    // later
    // ignore: avoid_catches_without_on_clauses
  } catch (err) {
    initErr = err;
  }

  runApp(_AppContainer(initialisationError: initErr));
}

class _AppContainer extends StatelessWidget {
  const _AppContainer({
    required this.initialisationError,
  });

  final Object? initialisationError;

  static final _routes = <String,
      ({
    Widget Function(BuildContext)? std,
    PageRoute Function(BuildContext, RouteSettings)? custom,
  })>{
    MainScreen.route: (
      std: (BuildContext context) => const MainScreen(),
      custom: null,
    ),
    StoreEditorPopup.route: (
      std: null,
      custom: (context, settings) => MaterialPageRoute(
            builder: (context) => const StoreEditorPopup(),
            settings: settings,
            fullscreenDialog: true,
          ),
    ),
    ImportPopup.route: (
      std: null,
      custom: (context, settings) => MaterialPageRoute(
            builder: (context) => const ImportPopup(),
            settings: settings,
            fullscreenDialog: true,
          ),
    ),
    ExportPopup.route: (
      std: null,
      custom: (context, settings) => MaterialPageRoute(
            builder: (context) => const ExportPopup(),
            settings: settings,
            fullscreenDialog: true,
          ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final themeData = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      textTheme: GoogleFonts.ubuntuTextTheme(ThemeData.light().textTheme),
      colorSchemeSeed: Colors.green,
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check)
              : null,
        ),
      ),
    );

    if (initialisationError case final err?) {
      return MaterialApp(
        title: 'FMTC Demo (Initialisation Error)',
        theme: themeData,
        home: InitialisationError(err: err),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GeneralProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => RegionSelectionProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadConfigurationProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadingProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider(
          create: (_) => RecoverableRegionsProvider(),
          lazy: true,
        ),
      ],
      child: MaterialApp(
        title: 'FMTC Demo',
        restorationScopeId: 'FMTC Demo',
        theme: themeData,
        initialRoute: MainScreen.route,
        onGenerateRoute: (settings) {
          final route = _routes[settings.name]!;
          if (route.custom != null) return route.custom!(context, settings);
          return MaterialPageRoute(builder: route.std!, settings: settings);
        },
      ),
    );
  }
}
