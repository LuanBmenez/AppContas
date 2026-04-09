import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/features/importacao/data/services/cancelamento_csv_service.dart';

class CancelamentoSection extends StatelessWidget {
  final List<TransacaoCanceladaDetectada> cancelamentos;
  final void Function(TransacaoCanceladaDetectada, bool) onAcao;
  const CancelamentoSection({
    super.key,
    required this.cancelamentos,
    required this.onAcao,
  });

  @override
  Widget build(BuildContext context) {
    if (cancelamentos.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Possíveis cancelamentos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...cancelamentos.map((c) => _buildItem(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, TransacaoCanceladaDetectada c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gasto:  ${c.gasto.titulo}  •  -${c.gasto.valor.abs().toStringAsFixed(2)}  •  ${_formatarData(c.gasto.data)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            'Recebimento:  ${c.recebimento.descricaoOriginal}  •  +${c.recebimento.valor.toStringAsFixed(2)}  •  ${_formatarData(c.recebimento.data)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text(
                  'Ignorar ambos',
                  style: TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onAcao(c, true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text(
                  'Manter separado',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onAcao(c, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
