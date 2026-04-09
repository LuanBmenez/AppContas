import 'package:flutter/material.dart';

import '../../data/services/dashboard_saldo_service.dart';

class DashboardSaldoResumo extends StatelessWidget {
  const DashboardSaldoResumo({super.key, required this.resumo});

  final ResumoMensalDashboard resumo;

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
            ),
            _ResumoItem(
              label: 'Recebido',
              valor: resumo.totalRecebido,
              color: Colors.green,
            ),
            _ResumoItem(
              label: 'Despesas',
              valor: resumo.totalDespesas,
              color: Colors.red,
            ),
            _ResumoItem(
              label: 'Saldo Final',
              valor: resumo.saldoFinal,
              color: Colors.purple,
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
            'R\$ ${valor.toStringAsFixed(2)}',
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
