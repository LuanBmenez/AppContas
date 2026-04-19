import 'dart:async';

import 'package:paga_o_que_me_deve/core/services/notificacao_local_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/data/services/recorrencias_service.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';

class RecorrenciasNotificacaoSyncService {
  RecorrenciasNotificacaoSyncService({required RecorrenciasService recorrenciasService, required NotificacaoLocalService notificacaoLocalService}) : _recorrenciasService = recorrenciasService, _notificacaoLocalService = notificacaoLocalService;

  final RecorrenciasService _recorrenciasService;
  final NotificacaoLocalService _notificacaoLocalService;
  StreamSubscription<List<RecorrenciaAtiva>>? _subscription;

  Future<void> start() async {
    await stop();
    _subscription = _recorrenciasService.streamRecorrenciasAtivas().listen((recorrencias) async {
      await _notificacaoLocalService.sincronizarRecorrencias(recorrencias);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
