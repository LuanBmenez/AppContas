import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';
import 'package:paga_o_que_me_deve/core/widgets/widgets.dart';
import 'package:paga_o_que_me_deve/domain/models/models.dart';

class NovoGastoPreviewCard extends StatelessWidget {
  const NovoGastoPreviewCard({
    super.key,
    required this.titulo,
    required this.categoriaNome,
    required this.categoriaPersonalizadaAtiva,
    required this.categoriaIcone,
    required this.valorPreview,
    required this.tipoSelecionado,
    required this.dataFormatada,
    required this.previewAccent,
    required this.previewSurface,
  });

  final String titulo;
  final String categoriaNome;
  final bool categoriaPersonalizadaAtiva;
  final IconData categoriaIcone;
  final String valorPreview;
  final TipoGasto tipoSelecionado;
  final String dataFormatada;
  final Color previewAccent;
  final Color previewSurface;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: previewAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Previa rapida',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                'Atualiza em tempo real',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [previewSurface, previewAccent.withValues(alpha: 0.10)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: previewAccent.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo.isEmpty ? 'Sem titulo' : titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  categoriaNome,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (categoriaPersonalizadaAtiva) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: previewAccent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Custom',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: previewAccent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        categoriaIcone,
                        color: previewAccent,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    valorPreview,
                    key: ValueKey<String>(valorPreview),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: previewAccent,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  tipoSelecionado == TipoGasto.fixo
                      ? 'Despesa fixa'
                      : 'Despesa variavel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: _ResumoMiniItem(
                        key: ValueKey<String>('data_$dataFormatada'),
                        icon: Icons.calendar_month_outlined,
                        label: 'Data',
                        value: dataFormatada,
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: _ResumoMiniItem(
                        key: ValueKey<String>('tipo_${tipoSelecionado.name}'),
                        icon: tipoSelecionado == TipoGasto.fixo
                            ? Icons.lock_outline
                            : Icons.auto_awesome_outlined,
                        label: 'Tipo',
                        value: tipoSelecionado.label,
                        accent: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NovoGastoCategoriaSection extends StatelessWidget {
  const NovoGastoCategoriaSection({
    super.key,
    required this.categoriaPersonalizadaAtiva,
    required this.buscaCategoriaController,
    required this.recentes,
    required this.categoriasPadrao,
    required this.categoriasPersonalizadas,
    required this.categoriaPersonalizadaSelecionadaId,
    required this.categoriaSelecionada,
    required this.onSelecionarCategoriaPadrao,
    required this.onSelecionarCategoriaPersonalizada,
    required this.onNovaCategoria,
    required this.onAbrirAcoesCategoria,
    required this.colunas,
  });

  final bool categoriaPersonalizadaAtiva;
  final TextEditingController buscaCategoriaController;
  final List<Widget> recentes;
  final List<CategoriaGasto> categoriasPadrao;
  final List<CategoriaPersonalizada> categoriasPersonalizadas;
  final String? categoriaPersonalizadaSelecionadaId;
  final CategoriaGasto categoriaSelecionada;
  final ValueChanged<CategoriaGasto> onSelecionarCategoriaPadrao;
  final ValueChanged<String> onSelecionarCategoriaPersonalizada;
  final VoidCallback onNovaCategoria;
  final ValueChanged<CategoriaPersonalizada> onAbrirAcoesCategoria;
  final int colunas;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Categoria',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              if (categoriaPersonalizadaAtiva)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Personalizada',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: buscaCategoriaController,
            decoration: const InputDecoration(
              labelText: 'Buscar categoria',
              hintText: 'Digite para filtrar',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (recentes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Recentes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: recentes,
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Sugeridas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          GridView.count(
            crossAxisCount: colunas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.s8,
            crossAxisSpacing: AppSpacing.s8,
            childAspectRatio: 2.3,
            children: categoriasPadrao.map((categoria) {
              final bool selecionada =
                  categoriaPersonalizadaSelecionadaId == null &&
                  categoria == categoriaSelecionada;
              return _CategoriaOptionTile(
                label: categoria.label,
                icon: categoria.icon,
                color: categoria.color,
                selecionada: selecionada,
                isFavorita: false,
                onTap: () => onSelecionarCategoriaPadrao(categoria),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Minhas categorias',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          GridView.count(
            crossAxisCount: colunas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.s8,
            crossAxisSpacing: AppSpacing.s8,
            childAspectRatio: 2.3,
            children: <Widget>[
              _NovaCategoriaTile(onTap: onNovaCategoria),
              ...categoriasPersonalizadas.map((categoria) {
                final bool selecionada =
                    categoria.id == categoriaPersonalizadaSelecionadaId;
                return _CategoriaOptionTile(
                  label: categoria.nome,
                  icon: categoria.icone,
                  color: categoria.cor,
                  selecionada: selecionada,
                  isFavorita: categoria.favorita,
                  onTap: () => onSelecionarCategoriaPersonalizada(categoria.id),
                  onLongPress: () => onAbrirAcoesCategoria(categoria),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class NovoGastoTipoSection extends StatelessWidget {
  const NovoGastoTipoSection({
    super.key,
    required this.tipoSelecionado,
    required this.onChanged,
  });

  final TipoGasto tipoSelecionado;
  final ValueChanged<TipoGasto> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          ToggleButtons(
            isSelected: <bool>[
              tipoSelecionado == TipoGasto.fixo,
              tipoSelecionado == TipoGasto.variavel,
            ],
            onPressed: (index) {
              onChanged(index == 0 ? TipoGasto.fixo : TipoGasto.variavel);
            },
            borderRadius: BorderRadius.circular(14),
            selectedColor: Colors.white,
            fillColor: Theme.of(context).colorScheme.primary,
            color: Colors.grey.shade700,
            constraints: const BoxConstraints(minHeight: 46),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Fixo'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Variavel'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NovoGastoRecorrenciaSection extends StatelessWidget {
  const NovoGastoRecorrenciaSection({
    super.key,
    required this.ativo,
    required this.mesesFuturos,
    required this.carregandoSugestao,
    required this.sugestao,
    required this.onAlterarAtivo,
    required this.onAlterarMeses,
    required this.onAplicarSugestao,
  });

  final bool ativo;
  final int mesesFuturos;
  final bool carregandoSugestao;
  final SugestaoRecorrenciaDespesa? sugestao;
  final ValueChanged<bool> onAlterarAtivo;
  final ValueChanged<int> onAlterarMeses;
  final VoidCallback onAplicarSugestao;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recorrencia',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              if (carregandoSugestao)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: ativo,
            onChanged: onAlterarAtivo,
            title: const Text('Criar despesas recorrentes mensais'),
            subtitle: const Text(
              'Gera os próximos lançamentos automaticamente.',
            ),
          ),
          if (ativo) ...[
            const SizedBox(height: AppSpacing.s8),
            DropdownButtonFormField<int>(
              initialValue: mesesFuturos,
              decoration: const InputDecoration(
                labelText: 'Gerar próximos meses',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 2, child: Text('2 meses')),
                DropdownMenuItem<int>(value: 3, child: Text('3 meses')),
                DropdownMenuItem<int>(value: 6, child: Text('6 meses')),
                DropdownMenuItem<int>(value: 12, child: Text('12 meses')),
              ],
              onChanged: (valor) {
                if (valor != null) {
                  onAlterarMeses(valor);
                }
              },
            ),
          ],
          if (sugestao != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sugestao automatica: parece ${sugestao!.periodicidade}.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${sugestao!.ocorrencias} ocorrencias, dia ${sugestao!.diaPreferencial}, media ${AppFormatters.moeda(sugestao!.valorMedio)}.',
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  OutlinedButton.icon(
                    onPressed: onAplicarSugestao,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Aplicar sugestao'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NovoGastoDataSection extends StatelessWidget {
  const NovoGastoDataSection({
    super.key,
    required this.dataFormatada,
    required this.onSelecionarData,
  });

  final String dataFormatada;
  final VoidCallback onSelecionarData;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          FilledButton.tonalIcon(
            onPressed: onSelecionarData,
            icon: const Icon(Icons.calendar_month),
            label: Text(dataFormatada),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class NovoGastoCategoriaQuickChip extends StatelessWidget {
  const NovoGastoCategoriaQuickChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoMiniItem extends StatelessWidget {
  const _ResumoMiniItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<String>('${label}_$value'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 13, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NovaCategoriaTile extends StatelessWidget {
  const _NovaCategoriaTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Row(
            children: [
              CircleAvatar(radius: 14, child: Icon(Icons.add, size: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nova categoria',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriaOptionTile extends StatelessWidget {
  const _CategoriaOptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selecionada,
    required this.isFavorita,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selecionada;
  final bool isFavorita;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionada ? color.withValues(alpha: 0.15) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionada ? color : Colors.grey.shade200,
              width: selecionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selecionada ? color : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFavorita)
                Icon(Icons.star, size: 14, color: color.withValues(alpha: 0.9)),
              if (selecionada) Icon(Icons.check_circle, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
