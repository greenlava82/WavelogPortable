import 'package:get_it/get_it.dart';
import 'services/database_service.dart';
import 'services/session_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register DatabaseService as a lazy singleton
  locator.registerLazySingleton<DatabaseService>(() => DatabaseService.create());

  // Register SessionService as a lazy singleton
  locator.registerLazySingleton<SessionService>(() => SessionService.create());
}
