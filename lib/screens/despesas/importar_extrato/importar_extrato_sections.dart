import 'package:flutter/material.dart';

import '../../../models/cartao_credito_model.dart';
import '../../../services/extrato_csv_service.dart';
import '../../../theme/app_tokens.dart';

class CartaoStepSection extends StatelessWidget {
  const CartaoStepSection({
    super.key,
    required this.cartoes,
    required this.cartaoSelecionado,
    required this.onCartaoChanged,
    required this.onGerenciarCartoes,
  });

  final List<CartaoCredito> cartoes;
  final CartaoCredito? cartaoSelecionado;
  final ValueChanged<CartaoCredito?> onCartaoChanged;
  final VoidCallback onGerenciarCartoes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1) Escolha o cartao',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s12),
            DropdownButtonFormField<CartaoCredito>(
              initialValue: cartaoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Cartao',
                border: OutlineInputBorder(),
              ),
              items: cartoes
                  .map(
                    (cartao) => DropdownMenuItem<CartaoCredito>(
                      value: cartao,
                      child: Text(cartao.label),
                    ),
                  )
                  .toList(),
              onChanged: onCartaoChanged,
            ),
            const SizedBox(height: AppSpacing.s12),
            TextButton.icon(
              onPressed: onGerenciarCartoes,
              icon: const Icon(Icons.credit_card),
              label: const Text('Gerenciar cartoes'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArquivoCsvStepSection extends StatelessWidget {
  const ArquivoCsvStepSection({
    super.key,
    required this.carregandoArquivo,
    required this.nomeArquivo,
    required this.onSelecionarArquivo,
  });

  final bool carregandoArquivo;
  final String? nomeArquivo;
  final VoidCallback onSelecionarArquivo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2) Selecione o CSV da fatura',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s12),
            OutlinedButton.icon(
              onPressed: carregandoArquivo ? null : onSelecionarArquivo,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                nomeArquivo == null
                    ? 'Escolher arquivo CSV'
                    : 'Arquivo: $nomeArquivo',
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            const Text('OFX ainda nao implementado nesta primeira versao.'),
          ],
        ),
      ),
    );
  }
}

class MapeamentoColunasSection extends StatelessWidget {
  const MapeamentoColunasSection({
    super.key,
    required this.campoDataLancamento,
    required this.campoDescricao,
    required this.campoValor,
    required this.campoDataCompra,
    required this.campoParcela,
  });

  final Widget campoDataLancamento;
  final Widget campoDescricao;
  final Widget campoValor;
  final Widget campoDataCompra;
  final Widget campoParcela;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3) Mapeie as colunas',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s12),
            campoDataLancamento,
            const SizedBox(height: AppSpacing.s12),
            campoDescricao,
            const SizedBox(height: AppSpacing.s12),
            campoValor,
            const SizedBox(height: AppSpacing.s12),
            campoDataCompra,
            const SizedBox(height: AppSpacing.s12),
            campoParcela,
          ],
        ),
      ),
    );
  }
}

class PreviewImportacaoSection extends StatelessWidget {
  const PreviewImportacaoSection({
    super.key,
    required this.preview,
    required this.duplicadosFuture,
    required this.salvando,
    required this.podeImportar,
    required this.onImportar,
    required this.itensPreview,
  });

  final ResultadoMapeamentoExtrato preview;
  final Future<int> duplicadosFuture;
  final bool salvando;
  final bool podeImportar;
  final VoidCallback onImportar;
  final List<Widget> itensPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: FutureBuilder<int>(
          future: duplicadosFuture,
          builder: (context, duplicadosSnapshot) {
            final int duplicadosDetectados = duplicadosSnapshot.data ?? 0;
            final int importaveis =
                preview.gastos.length - duplicadosDetectados;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '5) Previa antes de salvar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${importaveis < 0 ? 0 : importaveis} gastos serao importados',
                ),
                Text('${preview.ignorados} linhas ignoradas'),
                if (duplicadosSnapshot.connectionState ==
                    ConnectionState.waiting)
                  const Text('Analisando duplicados...')
                else
                  Text('$duplicadosDetectados duplicados detectados'),
                if (preview.ignoradosPorMotivo.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s8),
                  const Text(
                    'Motivos de ignorados:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ...preview.ignoradosPorMotivo.entries.map(
                    (entry) => Text('- ${entry.value}x ${entry.key}'),
                  ),
                ],
                const SizedBox(height: AppSpacing.s12),
                ...itensPreview,
                if (preview.gastos.length > 8)
                  Text('... e mais ${preview.gastos.length - 8} registros'),
                const SizedBox(height: AppSpacing.s16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: podeImportar ? onImportar : null,
                    icon: salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt_outlined),
                    label: Text(
                      salvando ? 'Importando...' : 'Salvar gastos importados',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
