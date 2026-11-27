import 'package:flutter/material.dart';

import 'data/content.dart';
import 'data/study_store.dart';
import 'player/background.dart';
import 'ui/app_theme.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await study.init();
  await ListenUpAudioHandler.init();
  runApp(const ListenUpApp());
}

class ListenUpApp extends StatelessWidget {
  const ListenUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ListenUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: FutureBuilder<List<Content>>(
        future: loadCatalog(),
        builder: (context, snap) => snap.hasData
            ? HomePage(catalog: snap.data!)
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
