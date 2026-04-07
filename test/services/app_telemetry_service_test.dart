import 'package:flutter_test/flutter_test.dart';
import 'package:paga_o_que_me_deve/services/app_telemetry_service.dart';

void main() {
  group('AppTelemetryService', () {
    test('ignora evento fora do contrato', () {
      final _SpyTelemetryProvider spy = _SpyTelemetryProvider();
      final AppTelemetryService service = AppTelemetryService(
        providers: <TelemetryProvider>[spy],
      );

      service.logEvent(
        'evento_desconhecido',
        params: <String, Object?>{'x': 1},
      );

      expect(spy.calls, isEmpty);
    });

    test('filtra parametros nao permitidos pelo contrato', () {
      final _SpyTelemetryProvider spy = _SpyTelemetryProvider();
      final AppTelemetryService service = AppTelemetryService(
        providers: <TelemetryProvider>[spy],
      );

      service.logEvent(
        AppTelemetryEvents.dashboardExportPdfStarted,
        params: <String, Object?>{
          'origemAcao': 'topo',
          'referenciaAno': 2026,
          'referenciaMes': 4,
          'paramNaoPermitido': 'remover',
        },
      );

      expect(spy.calls.length, 1);
      expect(spy.calls.first.params.containsKey('paramNaoPermitido'), isFalse);
      expect(spy.calls.first.params['origemAcao'], 'topo');
    });

    test('sanitiza mensagem de erro longa', () {
      final _SpyTelemetryProvider spy = _SpyTelemetryProvider();
      final AppTelemetryService service = AppTelemetryService(
        providers: <TelemetryProvider>[spy],
      );

      final String erroLongo = 'x' * 500;
      service.logEvent(
        AppTelemetryEvents.dashboardExportPdfException,
        params: <String, Object?>{
          'origemAcao': 'cta',
          'erroTipo': 'FormatException',
          'erroMensagem': erroLongo,
        },
      );

      final String mensagem = spy.calls.first.params['erroMensagem']! as String;
      expect(mensagem.length <= 120, isTrue);
    });
  });
}

class _SpyTelemetryProvider implements TelemetryProvider {
  final List<_TelemetryCall> calls = <_TelemetryCall>[];

  @override
  Future<void> send(String event, Map<String, Object?> params) async {
    calls.add(_TelemetryCall(event: event, params: params));
  }
}

class _TelemetryCall {
  _TelemetryCall({required this.event, required this.params});

  final String event;
  final Map<String, Object?> params;
}
