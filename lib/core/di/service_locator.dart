import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:paga_o_que_me_deve/core/services/notificacao_local_service.dart';
import 'package:paga_o_que_me_deve/data/services/database_service.dart';
import 'package:paga_o_que_me_deve/domain/repositories/finance_repository.dart';

final GetIt getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerLazySingleton<FinanceRepository>(DatabaseService.new);

  getIt.registerLazySingleton<NotificacaoLocalService>(
    () => NotificacaoLocalService.instance,
  );

  getIt.registerLazySingleton<FirebaseAuth>(
    () => FirebaseAuth.instance,
  );
}
