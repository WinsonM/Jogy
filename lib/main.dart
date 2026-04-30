import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/auth_service.dart';
import 'data/datasources/remote_data_source.dart';
import 'data/repositories/post_repository_impl.dart';
import 'features/auth/pages/login_page.dart';
import 'features/home/home_wrapper.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/post_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Shared HTTP data source
  final remoteDataSource = RemoteDataSource();

  // Auth service — restores saved session
  final authService = AuthService(remoteDataSource: remoteDataSource);
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(
          create: (_) => PostProvider(
            PostRepositoryImpl(remoteDataSource: remoteDataSource),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationProvider(remoteDataSource: remoteDataSource),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jogy',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          return auth.isLoggedIn ? const HomeWrapper() : const LoginPage();
        },
      ),
    );
  }
}
