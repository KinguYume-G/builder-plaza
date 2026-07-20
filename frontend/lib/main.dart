import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'state/auth_provider.dart';
import 'state/collab_provider.dart';
import 'state/growth_provider.dart';
import 'state/market_provider.dart';
import 'state/matches_provider.dart';
import 'state/projects_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const BuilderPlazaApp());
}

class BuilderPlazaApp extends StatefulWidget {
  const BuilderPlazaApp({super.key});

  @override
  State<BuilderPlazaApp> createState() => _BuilderPlazaAppState();
}

class _BuilderPlazaAppState extends State<BuilderPlazaApp> {
  late final AuthProvider _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    _router = createRouter(_auth);
    // Restore any existing session so router gating works across reloads.
    _auth.bootstrap();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => ProjectsProvider()),
        ChangeNotifierProvider(create: (_) => GrowthProvider()),
        ChangeNotifierProvider(create: (_) => MatchesProvider()),
        ChangeNotifierProvider(create: (_) => CollabProvider()),
        ChangeNotifierProvider(create: (_) => MarketProvider()),
      ],
      child: MaterialApp.router(
        title: 'Builder Plaza',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        routerConfig: _router,
      ),
    );
  }
}
