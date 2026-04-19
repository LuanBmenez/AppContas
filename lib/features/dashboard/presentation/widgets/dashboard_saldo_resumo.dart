import 'package:flutter/material.dart';

import 'package:paga_o_que_me_deve/features/dashboard/data/services/dashboard_saldo_service.dart';

class DashboardSaldoResumo extends StatelessWidget {
  const DashboardSaldoResumo({
    required this.resumo, super.key,
    this.mostrarValores = true,
  });

  final ResumoMensalDashboard resumo;
  final bool mostrarValores;

  @override
  Widget build(BuildContext context) {
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
              label: 'Saldo Inicial',
              valor: resumo.saldoInicial,
              color: Colors.blue,
              mostrarValores: mostrarValores,
            ),
            _ResumoItem(
              label: 'Recebido',
              valor: resumo.totalRecebido,
              color: Colors.green,
              mostrarValores: mostrarValores,
            ),
            _ResumoItem(
              label: 'Despesas',
              valor: resumo.totalDespesas,
              color: Colors.red,
              mostrarValores: mostrarValores,
            ),
            _ResumoItem(
              label: 'Saldo Final',
              valor: resumo.saldoFinal,
              color: Colors.purple,
              mostrarValores: mostrarValores,
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
    required this.mostrarValores,
  });

  final String label;
  final double valor;
  final Color color;
  final bool mostrarValores;

  String _formatarValor() {
    if (!mostrarValores) {
      return '••••';
    }

    return 'R\$ ${valor.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
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
            _formatarValor(),
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
