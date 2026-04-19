import 'package:paga_o_que_me_deve/domain/models/gasto.dart';

enum RecorrenciaOrigem {
  detectada,
  manual,
}

enum RecorrenciaStatus {
  ativa,
  pausada,
}

class RecorrenciaAtiva {
  const RecorrenciaAtiva({
    required this.id,
    required this.titulo,
    required this.valorMedio,
    required this.ultimoValor,
    required this.variacaoValor,
    required this.categoriaLabel,
    required this.diaDoMes,
    required this.proximoVencimento,
    required this.origem,
    required this.status,
    required this.notificacaoAtiva,
    required this.diasAntesNotificacao,
    required this.quantidadeHistorica,
    required this.ativosDesdeHoje,
    required this.gastoReferencia,
  });

  final String id;
  final String titulo;
  final double valorMedio;
  final double ultimoValor;
  final double variacaoValor;
  final String categoriaLabel;
  final int diaDoMes;
  final DateTime proximoVencimento;
  final RecorrenciaOrigem origem;
  final RecorrenciaStatus status;
  final bool notificacaoAtiva;
  final int diasAntesNotificacao;
  final int quantidadeHistorica;
  final List<Gasto> ativosDesdeHoje;
  final Gasto gastoReferencia;

  int get quantidadeFutura => ativosDesdeHoje.length;

  int get venceEmDias {
    final hoje = DateTime.now();
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final inicioVencimento = DateTime(
      proximoVencimento.year,
      proximoVencimento.month,
      proximoVencimento.day,
    );
    return inicioVencimento.difference(inicioHoje).inDays;
  }

  bool get estaAtrasada => venceEmDias < 0;
  bool get venceHoje => venceEmDias == 0;
  bool get venceEmBreve => venceEmDias >= 0 && venceEmDias <= 2;
  bool get temVariacaoValor => variacaoValor.abs() >= 0.01;

  String get origemLabel {
    switch (origem) {
      case RecorrenciaOrigem.detectada:
        return 'Detectada';
      case RecorrenciaOrigem.manual:
        return 'Confirmada';
    }
  }

  String get statusLabel {
    switch (status) {
      case RecorrenciaStatus.ativa:
        return 'Ativa';
      case RecorrenciaStatus.pausada:
        return 'Pausada';
    }
  }
}
