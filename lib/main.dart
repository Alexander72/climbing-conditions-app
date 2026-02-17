import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'presentation/providers/crag_provider.dart';
import 'presentation/providers/weather_provider.dart';
import 'presentation/providers/condition_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  // Required for sqflite on desktop and web. On Android/iOS the default factory is used.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ClimbingApp());
}

class ClimbingApp extends StatelessWidget {
  const ClimbingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CragProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => ConditionProvider()),
      ],
      child: MaterialApp(
        title: 'Climbing Conditions',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
