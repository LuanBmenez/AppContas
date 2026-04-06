import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/app_confirm_dialog.dart';
import '../../components/app_form_submit_bar.dart';
import '../../components/app_section_card.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../models/categoria_personalizada_model.dart';
import '../../models/gasto_model.dart';
import '../../models/preferencias_novo_gasto_model.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_formatters.dart';
import '../../utils/text_normalizer.dart';

class NovoGastoScreen extends StatefulWidget {
  const NovoGastoScreen({super.key, required this.db});

  final FinanceRepository db;

  @override
  State<NovoGastoScreen> createState() => _NovoGastoScreenState();
}

class _NovoGastoScreenState extends State<NovoGastoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _buscaCategoriaController =
      TextEditingController();

  StreamSubscription<List<CategoriaPersonalizada>>? _categoriasSub;

  CategoriaGasto _categoriaSelecionada = CategoriaGasto.outros;
  String? _categoriaPersonalizadaSelecionadaId;
  CategoriaGasto? _categoriaSugerida;
  String? _categoriaPersonalizadaSugeridaId;
  TipoGasto _tipoSelecionado = TipoGasto.variavel;
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;
  bool _carregandoPreferencias = true;
  bool _selecaoCategoriaManual = false;

  PreferenciasNovoGasto _preferencias = const PreferenciasNovoGasto();
  List<CategoriaPersonalizada> _categoriasPersonalizadas =
      <CategoriaPersonalizada>[];

  static const List<Color> _coresCategoria = <Color>[
    Color(0xFF0D9488),
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFFB91C1C),
    Color(0xFF65A30D),
    Color(0xFF0891B2),
    Color(0xFF475569),
    Color(0xFF7C2D12),
    Color(0xFF0369A1),
    Color(0xFF4D7C0F),
  ];

  static const List<IconData> _iconesCategoria = <IconData>[
    Icons.shopping_cart_outlined,
    Icons.restaurant_outlined,
    Icons.local_gas_station_outlined,
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.health_and_safety_outlined,
    Icons.sports_esports_outlined,
    Icons.work_outline,
    Icons.pets_outlined,
    Icons.flight_takeoff_outlined,
    Icons.fastfood_outlined,
    Icons.store_outlined,
  ];

  static const Map<String, CategoriaGasto> _sugestoesPadrao =
      <String, CategoriaGasto>{
        'uber': CategoriaGasto.transporte,
        '99': CategoriaGasto.transporte,
        'ifood': CategoriaGasto.comida,
        'mercado': CategoriaGasto.comida,
        'farmacia': CategoriaGasto.saude,
        'drogaria': CategoriaGasto.saude,
        'aluguel': CategoriaGasto.moradia,
        'faculdade': CategoriaGasto.educacao,
        'curso': CategoriaGasto.educacao,
        'cinema': CategoriaGasto.entretenimento,
      };

  @override
  void initState() {
    super.initState();
    _tituloController.addListener(_onCamposAlterados);
    _tituloController.addListener(_onTituloAlteradoParaSugestao);
    _valorController.addListener(_onCamposAlterados);
    _buscaCategoriaController.addListener(_onCamposAlterados);
    _inicializarCategorias();
  }

  @override
  void dispose() {
    _categoriasSub?.cancel();
    _tituloController.removeListener(_onCamposAlterados);
    _tituloController.removeListener(_onTituloAlteradoParaSugestao);
    _valorController.removeListener(_onCamposAlterados);
    _buscaCategoriaController.removeListener(_onCamposAlterados);
    _tituloController.dispose();
    _valorController.dispose();
    _buscaCategoriaController.dispose();
    super.dispose();
  }

  Future<void> _inicializarCategorias() async {
    final PreferenciasNovoGasto preferencias = await widget.db
        .carregarPreferenciasNovoGasto();

    if (!mounted) {
      return;
    }

    setState(() {
      _preferencias = preferencias;
      _tipoSelecionado = preferencias.ultimoTipo ?? _tipoSelecionado;
      _categoriaSelecionada =
          preferencias.ultimaCategoriaPadrao ?? _categoriaSelecionada;
      _categoriaPersonalizadaSelecionadaId =
          preferencias.ultimaCategoriaPersonalizadaId;
      _carregandoPreferencias = false;
    });

    _categoriasSub = widget.db.categoriasPersonalizadas.listen((categorias) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categoriasPersonalizadas = categorias;
        if (_categoriaPersonalizadaSelecionadaId != null &&
            !_categoriasPersonalizadas.any(
              (c) => c.id == _categoriaPersonalizadaSelecionadaId,
            )) {
          _categoriaPersonalizadaSelecionadaId = null;
        }
      });

      _atualizarSugestaoPorTitulo(aplicarAutomaticamente: true);
    });
  }

  void _onCamposAlterados() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTituloAlteradoParaSugestao() {
    _atualizarSugestaoPorTitulo(
      aplicarAutomaticamente: !_selecaoCategoriaManual,
    );
  }

  void _atualizarSugestaoPorTitulo({required bool aplicarAutomaticamente}) {
    final String normalizado = TextNormalizer.normalizeForSearch(
      _tituloController.text,
    ).toLowerCase();

    if (normalizado.isEmpty) {
      setState(() {
        _categoriaSugerida = null;
        _categoriaPersonalizadaSugeridaId = null;
      });
      return;
    }

    String? customId;
    for (final CategoriaPersonalizada categoria in _categoriasAtivas) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      if (nome.isNotEmpty && normalizado.contains(nome)) {
        customId = categoria.id;
        break;
      }
    }

    CategoriaGasto? sugerida;
    if (customId == null) {
      for (final MapEntry<String, CategoriaGasto> entry
          in _sugestoesPadrao.entries) {
        if (normalizado.contains(entry.key)) {
          sugerida = entry.value;
          break;
        }
      }
    }

    setState(() {
      _categoriaSugerida = sugerida;
      _categoriaPersonalizadaSugeridaId = customId;

      if (!aplicarAutomaticamente) {
        return;
      }

      if (customId != null) {
        _categoriaPersonalizadaSelecionadaId = customId;
      } else if (sugerida != null) {
        _categoriaPersonalizadaSelecionadaId = null;
        _categoriaSelecionada = sugerida;
      }
    });
  }

  String _normalizarMensagemErro(Object error) {
    final String lower = error.toString().toLowerCase();
    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Erro no Firestore. Tente novamente.';
    }
    return 'Erro ao salvar gasto.';
  }

  String _formatarData(DateTime data) {
    return AppFormatters.dataCurta(data);
  }

  String _formatarValorPreview() {
    try {
      return AppFormatters.moeda(
        AppFormatters.parseMoedaInput(_valorController.text),
      );
    } catch (_) {
      return 'R\$ 0,00';
    }
  }

  List<CategoriaPersonalizada> get _categoriasAtivas {
    return _categoriasPersonalizadas
        .where((categoria) => !categoria.arquivada)
        .toList();
  }

  CategoriaPersonalizada? get _categoriaCustomSelecionada {
    final String? id = _categoriaPersonalizadaSelecionadaId;
    if (id == null) {
      return null;
    }
    for (final CategoriaPersonalizada categoria in _categoriasPersonalizadas) {
      if (categoria.id == id) {
        return categoria;
      }
    }
    return null;
  }

  Color get _categoriaCorPreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.cor;
    }
    return _categoriaSelecionada.color;
  }

  IconData get _categoriaIconePreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.icone;
    }
    return _categoriaSelecionada.icon;
  }

  String get _categoriaNomePreview {
    final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;
    if (custom != null) {
      return custom.nome;
    }
    return _categoriaSelecionada.label;
  }

  bool get _categoriaPersonalizadaAtiva => _categoriaCustomSelecionada != null;

  Future<void> _selecionarData() async {
    final DateTime? novaData = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Escolha a data do gasto',
    );

    if (novaData != null) {
      setState(() => _dataSelecionada = novaData);
    }
  }

  Future<void> _salvarGasto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _salvando = true);

    try {
      final double valor = AppFormatters.parseMoedaInput(_valorController.text);
      final CategoriaPersonalizada? custom = _categoriaCustomSelecionada;

      final Gasto novoGasto = Gasto(
        id: '',
        titulo: _tituloController.text.trim(),
        valor: valor,
        data: _dataSelecionada,
        categoria: custom == null
            ? _categoriaSelecionada
            : CategoriaGasto.outros,
        categoriaPersonalizadaId: custom?.id,
        categoriaPersonalizadaNome: custom?.nome,
        categoriaPersonalizadaCorValue: custom?.corValue,
        categoriaPersonalizadaIconeCodePoint: custom?.iconeCodePoint,
        tipo: _tipoSelecionado,
      );

      await widget.db.adicionarGasto(novoGasto);
      await widget.db.registrarUsoNovoGasto(
        categoriaPadrao: custom == null ? _categoriaSelecionada : null,
        categoriaPersonalizadaId: custom?.id,
        tipo: _tipoSelecionado,
      );

      if (mounted) {
        Navigator.pop(context);
        AppFeedback.showSuccess(context, 'Gasto salvo com sucesso.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, _normalizarMensagemErro(e));
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Widget _buildSectionCard({required Widget child}) {
    return AppSectionCard(child: child);
  }

  Widget _previewTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
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
      child: _ResumoMiniItem(
        key: ValueKey<String>('${label}_$value'),
        icon: icon,
        label: label,
        value: value,
        accent: accent,
      ),
    );
  }

  void _selecionarCategoriaPadrao(CategoriaGasto categoria) {
    setState(() {
      _selecaoCategoriaManual = true;
      _categoriaPersonalizadaSelecionadaId = null;
      _categoriaSelecionada = categoria;
    });
  }

  void _selecionarCategoriaPersonalizada(String id) {
    setState(() {
      _selecaoCategoriaManual = true;
      _categoriaPersonalizadaSelecionadaId = id;
    });
  }

  List<CategoriaGasto> _categoriasPadraoFiltradas() {
    final String busca = TextNormalizer.normalizeForSearch(
      _buscaCategoriaController.text,
    ).toLowerCase();
    if (busca.isEmpty) {
      return CategoriaGasto.values;
    }

    return CategoriaGasto.values.where((categoria) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.label,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  List<CategoriaPersonalizada> _categoriasPersonalizadasFiltradas() {
    final String busca = TextNormalizer.normalizeForSearch(
      _buscaCategoriaController.text,
    ).toLowerCase();
    final List<CategoriaPersonalizada> base = _categoriasAtivas;

    if (busca.isEmpty) {
      base.sort((a, b) {
        if (a.favorita != b.favorita) {
          return a.favorita ? -1 : 1;
        }
        return b.usoCount.compareTo(a.usoCount);
      });
      return base;
    }

    return base.where((categoria) {
      final String nome = TextNormalizer.normalizeForSearch(
        categoria.nome,
      ).toLowerCase();
      return nome.contains(busca);
    }).toList();
  }

  bool _nomeCategoriaDuplicado(String nome, {String? ignorarId}) {
    final String normalizado = TextNormalizer.normalizeForSearch(
      nome,
    ).trim().toLowerCase();
    if (normalizado.isEmpty) {
      return false;
    }

    for (final CategoriaGasto item in CategoriaGasto.values) {
      final String padrao = TextNormalizer.normalizeForSearch(
        item.label,
      ).toLowerCase();
      if (padrao == normalizado) {
        return true;
      }
    }

    for (final CategoriaPersonalizada item in _categoriasAtivas) {
      if (item.id == ignorarId) {
        continue;
      }
      final String existente = TextNormalizer.normalizeForSearch(
        item.nome,
      ).toLowerCase();
      if (existente == normalizado) {
        return true;
      }
    }

    return false;
  }

  double _contrastRatio(Color a, Color b) {
    final double l1 = a.computeLuminance();
    final double l2 = b.computeLuminance();
    final double claro = l1 > l2 ? l1 : l2;
    final double escuro = l1 > l2 ? l2 : l1;
    return (claro + 0.05) / (escuro + 0.05);
  }

  bool _temContrasteAcessivel(Color cor) {
    final double comBranco = _contrastRatio(cor, Colors.white);
    final double comPreto = _contrastRatio(cor, Colors.black);
    return comBranco >= 4.5 || comPreto >= 4.5;
  }

  Future<void> _abrirModalCategoria({CategoriaPersonalizada? categoria}) async {
    final TextEditingController nomeController = TextEditingController(
      text: categoria?.nome ?? '',
    );
    int corValue = categoria?.corValue ?? _coresCategoria.first.value;
    int iconeCodePoint =
        categoria?.iconeCodePoint ?? _iconesCategoria.first.codePoint;
    bool favorita = categoria?.favorita ?? false;

    final bool? salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Color corAtual = Color(corValue);
            final IconData iconeAtual = IconData(
              iconeCodePoint,
              fontFamily: 'MaterialIcons',
            );
            final Color texto = _contrastRatio(corAtual, Colors.white) >= 4.5
                ? Colors.white
                : Colors.black;

            return AlertDialog(
              title: Text(
                categoria == null ? 'Nova categoria' : 'Editar categoria',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nomeController,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: corAtual,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(iconeAtual, color: texto),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              nomeController.text.trim().isEmpty
                                  ? 'Prévia da categoria'
                                  : nomeController.text.trim(),
                              style: TextStyle(
                                color: texto,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Cor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _coresCategoria.map((cor) {
                        final bool selecionada = cor.value == corValue;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => corValue = cor.value),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selecionada
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Ícone',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _iconesCategoria.map((icone) {
                        final bool selecionado =
                            icone.codePoint == iconeCodePoint;
                        return InkWell(
                          onTap: () => setDialogState(
                            () => iconeCodePoint = icone.codePoint,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selecionado
                                  ? Color(corValue).withValues(alpha: 0.16)
                                  : Colors.transparent,
                              border: Border.all(
                                color: selecionado
                                    ? Color(corValue)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Icon(icone),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: favorita,
                      onChanged: (value) =>
                          setDialogState(() => favorita = value),
                      title: const Text('Favorita'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final String nome = nomeController.text.trim();
                    if (nome.length < 3) {
                      AppFeedback.showError(
                        context,
                        'Nome deve ter ao menos 3 caracteres.',
                      );
                      return;
                    }
                    if (_nomeCategoriaDuplicado(
                      nome,
                      ignorarId: categoria?.id,
                    )) {
                      AppFeedback.showError(
                        context,
                        'Já existe uma categoria com esse nome.',
                      );
                      return;
                    }
                    if (!_temContrasteAcessivel(Color(corValue))) {
                      AppFeedback.showError(
                        context,
                        'Escolha uma cor com melhor contraste.',
                      );
                      return;
                    }

                    final CategoriaPersonalizada nova = CategoriaPersonalizada(
                      id: categoria?.id ?? '',
                      nome: nome,
                      corValue: corValue,
                      iconeCodePoint: iconeCodePoint,
                      favorita: favorita,
                      arquivada: false,
                      usoCount: categoria?.usoCount ?? 0,
                      criadaEm: categoria?.criadaEm,
                    );

                    await widget.db.salvarCategoriaPersonalizada(nova);
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _selecaoCategoriaManual = true;
                      _categoriaPersonalizadaSelecionadaId =
                          categoria?.id ?? _categoriaPersonalizadaSelecionadaId;
                    });

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (salvar == true && mounted) {
      AppFeedback.showSuccess(context, 'Categoria salva com sucesso.');
    }
  }

  Future<void> _abrirAcoesCategoriaPersonalizada(
    CategoriaPersonalizada categoria,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Renomear / Trocar cor e ícone'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _abrirModalCategoria(categoria: categoria);
                },
              ),
              ListTile(
                leading: Icon(
                  categoria.favorita ? Icons.star : Icons.star_outline,
                ),
                title: Text(categoria.favorita ? 'Desfavoritar' : 'Favoritar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await widget.db.alternarFavoritaCategoriaPersonalizada(
                    categoria.id,
                    !categoria.favorita,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  categoria.arquivada
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(categoria.arquivada ? 'Desarquivar' : 'Arquivar'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await widget.db.arquivarCategoriaPersonalizada(
                    categoria.id,
                    !categoria.arquivada,
                  );
                  if (_categoriaPersonalizadaSelecionadaId == categoria.id &&
                      !categoria.arquivada) {
                    setState(() {
                      _categoriaPersonalizadaSelecionadaId = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final bool emUso = await widget.db
                      .categoriaPersonalizadaEmUso(categoria.id);
                  if (emUso) {
                    if (!mounted) return;
                    AppFeedback.showError(
                      context,
                      'Categoria em uso. Apenas arquivamento é permitido.',
                    );
                    await widget.db.arquivarCategoriaPersonalizada(
                      categoria.id,
                      true,
                    );
                    return;
                  }

                  if (!mounted) return;
                  final bool confirmar = await AppConfirmDialog.show(
                    context,
                    title: 'Excluir categoria',
                    message: 'Deseja excluir ${categoria.nome}?',
                  );
                  if (!confirmar) {
                    return;
                  }

                  await widget.db.deletarCategoriaPersonalizada(categoria.id);
                  if (_categoriaPersonalizadaSelecionadaId == categoria.id &&
                      mounted) {
                    setState(() {
                      _categoriaPersonalizadaSelecionadaId = null;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChipSugestao() {
    final String? customId = _categoriaPersonalizadaSugeridaId;
    final CategoriaGasto? padrao = _categoriaSugerida;
    if (customId == null && padrao == null) {
      return const SizedBox.shrink();
    }

    String label;
    if (customId != null) {
      final CategoriaPersonalizada? custom = _categoriasAtivas
          .where((c) {
            return c.id == customId;
          })
          .cast<CategoriaPersonalizada?>()
          .firstOrNull;
      label = custom?.nome ?? 'Categoria personalizada';
    } else {
      label = padrao!.label;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text('Sugestão: $label'),
          onPressed: () {
            if (customId != null) {
              _selecionarCategoriaPersonalizada(customId);
            } else if (padrao != null) {
              _selecionarCategoriaPadrao(padrao);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoriaSection() {
    final List<CategoriaGasto> padrao = _categoriasPadraoFiltradas();
    final List<CategoriaPersonalizada> personalizadas =
        _categoriasPersonalizadasFiltradas();
    final bool compact = MediaQuery.sizeOf(context).width < 420;
    final int colunas = compact ? 2 : 3;

    final List<Widget> recentes = <Widget>[];

    for (final String id in _preferencias.recentesPersonalizadas) {
      final CategoriaPersonalizada? item = _categoriasAtivas
          .where((c) {
            return c.id == id;
          })
          .cast<CategoriaPersonalizada?>()
          .firstOrNull;
      if (item == null) {
        continue;
      }
      recentes.add(
        _CategoriaQuickChip(
          label: item.nome,
          color: item.cor,
          icon: item.icone,
          onTap: () => _selecionarCategoriaPersonalizada(item.id),
        ),
      );
      if (recentes.length >= 5) {
        break;
      }
    }

    if (recentes.length < 5) {
      for (final CategoriaGasto item in _preferencias.recentesPadrao) {
        recentes.add(
          _CategoriaQuickChip(
            label: item.label,
            color: item.color,
            icon: item.icon,
            onTap: () => _selecionarCategoriaPadrao(item),
          ),
        );
        if (recentes.length >= 5) {
          break;
        }
      }
    }

    return _buildSectionCard(
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
              if (_categoriaPersonalizadaAtiva)
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
            controller: _buscaCategoriaController,
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
            children: padrao.map((categoria) {
              final bool selecionada =
                  _categoriaPersonalizadaSelecionadaId == null &&
                  categoria == _categoriaSelecionada;
              return _CategoriaOptionTile(
                label: categoria.label,
                icon: categoria.icon,
                color: categoria.color,
                selecionada: selecionada,
                isFavorita: false,
                onTap: () => _selecionarCategoriaPadrao(categoria),
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
              _NovaCategoriaTile(onTap: _abrirModalCategoria),
              ...personalizadas.map((categoria) {
                final bool selecionada =
                    categoria.id == _categoriaPersonalizadaSelecionadaId;
                return _CategoriaOptionTile(
                  label: categoria.nome,
                  icon: categoria.icone,
                  color: categoria.cor,
                  selecionada: selecionada,
                  isFavorita: categoria.favorita,
                  onTap: () => _selecionarCategoriaPersonalizada(categoria.id),
                  onLongPress: () =>
                      _abrirAcoesCategoriaPersonalizada(categoria),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String valorPreview = _formatarValorPreview();
    final Color previewAccent = _categoriaCorPreview;
    final Color previewSurface = Theme.of(context).colorScheme.primaryContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Gasto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      bottomNavigationBar: AppFormSubmitBar(
        onPressed: _salvarGasto,
        label: 'SALVAR GASTO',
        isLoading: _salvando,
      ),
      body: _carregandoPreferencias
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    _buildSectionCard(
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
                                'Prévia rápida',
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
                                colors: [
                                  previewSurface,
                                  previewAccent.withValues(alpha: 0.10),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: previewAccent.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _tituloController.text
                                                    .trim()
                                                    .isEmpty
                                                ? 'Sem título'
                                                : _tituloController.text.trim(),
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
                                                  _categoriaNomePreview,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (_categoriaPersonalizadaAtiva) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: previewAccent
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Custom',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                        color: previewAccent.withValues(
                                          alpha: 0.16,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _categoriaIconePreview,
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
                                  _tipoSelecionado == TipoGasto.fixo
                                      ? 'Despesa fixa'
                                      : 'Despesa variável',
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
                                      child: _previewTile(
                                        icon: Icons.calendar_month_outlined,
                                        label: 'Data',
                                        value: _formatarData(_dataSelecionada),
                                        accent: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: _previewTile(
                                        icon: _tipoSelecionado == TipoGasto.fixo
                                            ? Icons.lock_outline
                                            : Icons.auto_awesome_outlined,
                                        label: 'Tipo',
                                        value: _tipoSelecionado.label,
                                        accent: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSectionCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _tituloController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Título do gasto',
                              helperText: 'Ex: Mercado, Uber, aluguel',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.edit_note),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Título obrigatório.';
                              }
                              return null;
                            },
                          ),
                          _buildChipSugestao(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSectionCard(
                      child: TextFormField(
                        controller: _valorController,
                        textInputAction: TextInputAction.done,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          MoedaInputFormatter(),
                        ],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor do gasto',
                          helperText: 'Valor em reais',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payments_outlined),
                          prefixText: 'R\$ ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o valor.';
                          }

                          try {
                            final double valor = AppFormatters.parseMoedaInput(
                              value,
                            );
                            if (valor <= 0) {
                              return 'Valor inválido.';
                            }
                          } catch (_) {
                            return 'Valor inválido.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildCategoriaSection(),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSectionCard(
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
                              _tipoSelecionado == TipoGasto.fixo,
                              _tipoSelecionado == TipoGasto.variavel,
                            ],
                            onPressed: (index) {
                              setState(() {
                                _tipoSelecionado = index == 0
                                    ? TipoGasto.fixo
                                    : TipoGasto.variavel;
                              });
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
                                    Text('Variável'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildSectionCard(
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
                            onPressed: _selecionarData,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(_formatarData(_dataSelecionada)),
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
                    ),
                  ],
                ),
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
    return Container(
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
    );
  }
}

class _CategoriaQuickChip extends StatelessWidget {
  const _CategoriaQuickChip({
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

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
