import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AppTelemetryEvents {
  AppTelemetryEvents._();

  static const String dashboardExportPdfStarted =
      'dashboard_export_pdf_started';
  static const String dashboardExportPdfFinished =
      'dashboard_export_pdf_finished';
  static const String dashboardExportPdfException =
      'dashboard_export_pdf_exception';
  static const String dashboardExportPdfIgnoredBusy =
      'dashboard_export_pdf_ignored_busy';
  static const String dashboardExportPdfUnsupportedPlatform =
      'dashboard_export_pdf_unsupported_platform';
}

typedef TelemetrySender =
    Future<void> Function(String event, Map<String, Object?> params);

class DeveloperLogTelemetryProvider {
  const DeveloperLogTelemetryProvider();

  Future<void> call(String event, Map<String, Object?> params) async {
    final payload = <String, Object?>{
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      ...params,
    };
    developer.log(jsonEncode(payload), name: 'app.telemetry', level: 800);
  }
}

class FirebaseAnalyticsTelemetryProvider {
  FirebaseAnalyticsTelemetryProvider({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> call(String event, Map<String, Object?> params) async {
    await _analytics.logEvent(name: event, parameters: _toAnalytics(params));
  }

  Map<String, Object> _toAnalytics(Map<String, Object?> params) {
    final result = <String, Object>{};

    params.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is String || value is num || value is bool) {
        result[key] = value;
        return;
      }
      result[key] = value.toString();
    });

    return result;
  }
}

class AppTelemetryService {
  AppTelemetryService({List<TelemetrySender>? providers})
    : _providers = providers ?? _defaultProviders();

  final List<TelemetrySender> _providers;

  static final Map<String, Set<String>> _allowedParams = <String, Set<String>>{
    AppTelemetryEvents.dashboardExportPdfStarted: <String>{
      'origemAcao',
      'referenciaAno',
      'referenciaMes',
    },
    AppTelemetryEvents.dashboardExportPdfFinished: <String>{
      'origemAcao',
      'referenciaAno',
      'referenciaMes',
      'duracaoMs',
      'sucesso',
      'fallbackCompartilhamento',
      'erroTipo',
    },
    AppTelemetryEvents.dashboardExportPdfException: <String>{
      'origemAcao',
      'erroTipo',
      'erroMensagem',
    },
    AppTelemetryEvents.dashboardExportPdfIgnoredBusy: <String>{'origemAcao'},
    AppTelemetryEvents.dashboardExportPdfUnsupportedPlatform: <String>{
      'origemAcao',
      'platform',
      'duracaoMs',
    },
  };

  void logEvent(String event, {Map<String, Object?> params = const {}}) {
    if (!_allowedParams.containsKey(event)) {
      // Unknown events are ignored to prevent ungoverned telemetry growth.
      return;
    }

    final sanitized = _sanitize(event, params);
    for (final provider in _providers) {
      provider(event, sanitized);
    }
  }

  Map<String, Object?> _sanitize(String event, Map<String, Object?> params) {
    final allowed = _allowedParams[event] ?? const <String>{};
    final sanitized = <String, Object?>{};

    params.forEach((key, value) {
      if (!allowed.contains(key)) {
        return;
      }
      sanitized[key] = _sanitizeValue(key, value);
    });

    return sanitized;
  }

  Object? _sanitizeValue(String key, Object? value) {
    if (value == null) {
      return null;
    }

    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('valor') || lowerKey.contains('montante')) {
      return _bucketMoney(value);
    }

    if (lowerKey.contains('erro') && value is String) {
      final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      return clean.length > 120 ? clean.substring(0, 120) : clean;
    }

    if (value is String || value is num || value is bool) {
      return value;
    }

    return value.toString();
  }

  String _bucketMoney(Object value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (parsed == null) {
      return 'desconhecido';
    }
    if (parsed < 100) {
      return '0-99';
    }
    if (parsed < 500) {
      return '100-499';
    }
    if (parsed < 2000) {
      return '500-1999';
    }
    return '2000+';
  }

  static List<TelemetrySender> _defaultProviders() {
    final providers = <TelemetrySender>[
      FirebaseAnalyticsTelemetryProvider().call,
    ];

    if (!kReleaseMode) {
      providers.add(const DeveloperLogTelemetryProvider().call);
    }

    return providers;
  }
}
