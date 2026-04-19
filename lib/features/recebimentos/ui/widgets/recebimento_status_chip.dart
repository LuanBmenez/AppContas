import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/domain/models/recebimento.dart';

class RecebimentoStatusChip extends StatelessWidget {
  const RecebimentoStatusChip({required this.status, super.key});

  final StatusRecebimento status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (status) {
      case StatusRecebimento.pendente:
        color = Colors.orange;
        label = 'Pendente';
      case StatusRecebimento.recebido:
        color = Colors.green;
        label = 'Recebido';
      case StatusRecebimento.atrasado:
        color = Colors.red;
        label = 'Atrasado';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
