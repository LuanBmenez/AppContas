import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';

class ResumoMensalRecebimentos extends StatelessWidget {
  const ResumoMensalRecebimentos({required this.recebimentos, super.key});

  final List<Recebimento> recebimentos;

  @override
  Widget build(BuildContext context) {
    final totalPrevisto = recebimentos.fold<double>(
      0,
      (soma, r) => soma + r.valor,
    );

    final totalRecebido = recebimentos
        .where((r) => r.status == StatusRecebimento.recebido)
        .fold<double>(0, (soma, r) => soma + r.valor);

    final totalPendente = recebimentos
        .where((r) => r.status == StatusRecebimento.pendente)
        .fold<double>(0, (soma, r) => soma + r.valor);

    final totalAtrasado = recebimentos
        .where((r) => r.status == StatusRecebimento.atrasado)
        .fold<double>(0, (soma, r) => soma + r.valor);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 12,
          spacing: 12,
          children: [
            _ResumoItem(
              label: 'Previsto',
              valor: totalPrevisto,
              color: Colors.blue,
            ),
            _ResumoItem(
              label: 'Recebido',
              valor: totalRecebido,
              color: Colors.green,
            ),
            _ResumoItem(
              label: 'Pendente',
              valor: totalPendente,
              color: Colors.orange,
            ),
            _ResumoItem(
              label: 'Atrasado',
              valor: totalAtrasado,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoItem extends StatelessWidget {
  const _ResumoItem({
    required this.label,
    required this.valor,
    required this.color,
  });

  final String label;
  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
