import 'package:cloud_firestore/cloud_firestore.dart';

class RecorrenciaConfiguracao {
  const RecorrenciaConfiguracao({
    required this.recorrenciaId,
    required this.confirmada,
    required this.pausada,
    required this.ignorada,
    required this.notificacaoAtiva,
    required this.diasAntesNotificacao,
  });

  final String recorrenciaId;
  final bool confirmada;
  final bool pausada;
  final bool ignorada;
  final bool notificacaoAtiva;
  final int diasAntesNotificacao;

  factory RecorrenciaConfiguracao.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return RecorrenciaConfiguracao(
      recorrenciaId: data['recorrenciaId'] as String? ?? doc.id,
      confirmada: data['confirmada'] as bool? ?? false,
      pausada: data['pausada'] as bool? ?? false,
      ignorada: data['ignorada'] as bool? ?? false,
      notificacaoAtiva: data['notificacaoAtiva'] as bool? ?? true,
      diasAntesNotificacao: data['diasAntesNotificacao'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recorrenciaId': recorrenciaId,
      'confirmada': confirmada,
      'pausada': pausada,
      'ignorada': ignorada,
      'notificacaoAtiva': notificacaoAtiva,
      'diasAntesNotificacao': diasAntesNotificacao,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  RecorrenciaConfiguracao copyWith({
    String? recorrenciaId,
    bool? confirmada,
    bool? pausada,
    bool? ignorada,
    bool? notificacaoAtiva,
    int? diasAntesNotificacao,
  }) {
    return RecorrenciaConfiguracao(
      recorrenciaId: recorrenciaId ?? this.recorrenciaId,
      confirmada: confirmada ?? this.confirmada,
      pausada: pausada ?? this.pausada,
      ignorada: ignorada ?? this.ignorada,
      notificacaoAtiva: notificacaoAtiva ?? this.notificacaoAtiva,
      diasAntesNotificacao:
          diasAntesNotificacao ?? this.diasAntesNotificacao,
    );
  }

  static const RecorrenciaConfiguracao vazio = RecorrenciaConfiguracao(
    recorrenciaId: '',
    confirmada: false,
    pausada: false,
    ignorada: false,
    notificacaoAtiva: true,
    diasAntesNotificacao: 2,
  );
}
