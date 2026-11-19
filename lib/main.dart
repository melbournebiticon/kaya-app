import 'package:kaya/app/app.dart';
import 'package:kaya/core/config/supabase_bootstrap.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final KayaBackendRepositories backendRepositories =
      await KayaBackendRepositories.initializeFromEnvironment();
  runApp(
    KayaApp(
      requireAuthentication: true,
      backendRepositories: backendRepositories,
    ),
  );
}
