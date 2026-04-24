import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:paga_o_que_me_deve/features/recorrencias/domain/models/recorrencia_ativa.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificacaoLocalService {
  NotificacaoLocalService._();
  static final NotificacaoLocalService instance = NotificacaoLocalService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _canalId = 'recorrencias_vencimento';
  static const String _canalNome = 'Recorrencias a vencer';
  static const String _canalDescricao =
      'Lembretes de despesas recorrentes proximas do vencimento';
  static const int _baseRecorrenciasId = 700000;
  static const int _rangeRecorrencias = 100000;

  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    // CORREÇÃO: O parâmetro 'settings' tem de ser nomeado (settings: settings)
    await _plugin.initialize(
      settings: settings,
      // Preparado para quando o usuário clicar na notificação
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          debugPrint('Notificação clicada com payload: ${response.payload}');
          // Futuro: Redirecionar via GoRouter usando o payload
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    const canal = AndroidNotificationChannel(
      _canalId,
      _canalNome,
      description: _canalDescricao,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canal);
  }

  int _idDaRecorrencia(String recorrenciaId) =>
      _baseRecorrenciasId + (recorrenciaId.hashCode.abs() % _rangeRecorrencias);

  Future<void> agendarResumoFinanceiroDiario({
    required double totalGastos,
    required double totalReceber,
    required List<String> nomesReceber,
  }) async {
    if (totalGastos <= 0 && totalReceber <= 0) return;

    var mensagem = '';

    if (totalGastos > 0) {
      mensagem +=
          '💸 Você tem R\$ ${totalGastos.toStringAsFixed(2)} em contas hoje. ';
    }

    if (totalReceber > 0) {
      mensagem += '💰 Lembre-se de receber de: ${nomesReceber.join(', ')}.';
    }

    final agora = DateTime.now();
    final dataAgendada = DateTime(agora.year, agora.month, agora.day, 9);

    if (agora.isAfter(dataAgendada)) return;

    final scheduled = tz.TZDateTime.from(dataAgendada, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'lembretes_diarios',
      'Lembretes Diários',
      channelDescription: 'Resumo financeiro do dia',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: 999,
      title: 'Resumo do Dia',
      body: mensagem,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> sincronizarRecorrencias(
    List<RecorrenciaAtiva> recorrencias,
  ) async {
    final pendentes = await _plugin.pendingNotificationRequests();

    for (final pending in pendentes) {
      if (pending.id >= _baseRecorrenciasId &&
          pending.id < (_baseRecorrenciasId + _rangeRecorrencias)) {
        await _plugin.cancel(id: pending.id);
      }
    }

    for (final recorrencia in recorrencias) {
      if (recorrencia.status != RecorrenciaStatus.ativa ||
          !recorrencia.notificacaoAtiva) {
        continue;
      }

      await agendarLembreteRecorrencia(
        recorrencia,
        diasAntes: recorrencia.diasAntesNotificacao,
      );
    }
  }

  Future<void> agendarLembreteRecorrencia(
    RecorrenciaAtiva recorrencia, {
    int diasAntes = 2,
    int hora = 9,
    int minuto = 0,
  }) async {
    final dataBase = DateTime(
      recorrencia.proximoVencimento.year,
      recorrencia.proximoVencimento.month,
      recorrencia.proximoVencimento.day,
      hora,
      minuto,
    ).subtract(Duration(days: diasAntes));

    if (!dataBase.isAfter(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(dataBase, tz.local);

    const androidDetails = AndroidNotificationDetails(
      _canalId,
      _canalNome,
      channelDescription: _canalDescricao,
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: _idDaRecorrencia(recorrencia.id),
      title: 'Conta perto do vencimento',
      body: 'Faltam $diasAntes dia(s) para pagar ${recorrencia.titulo}.',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'recorrencia:${recorrencia.id}',
    );
  }
}
