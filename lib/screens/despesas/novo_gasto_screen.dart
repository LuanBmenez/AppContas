import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/gasto_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_formatters.dart';

class NovoGastoScreen extends StatefulWidget {
  const NovoGastoScreen({super.key, required this.db});

  final DatabaseService db;

  @override
  State<NovoGastoScreen> createState() => _NovoGastoScreenState();
}

class _NovoGastoScreenState extends State<NovoGastoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  CategoriaGasto _categoriaSelecionada = CategoriaGasto.outros;
  TipoGasto _tipoSelecionado = TipoGasto.variavel;
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  String _normalizarMensagemErro(Object error) {
    final String texto = error.toString();
    final String lower = texto.toLowerCase();

    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Cloud Firestore desativado ou sem permissão no projeto.\n'
          'Ative o Firestore no Firebase Console e tente novamente.';
    }

    return 'Erro ao salvar gasto: $texto';
  }

  String _formatarData(DateTime data) {
    return AppFormatters.dataCurta(data);
  }

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

      final Gasto novoGasto = Gasto(
        id: '',
        titulo: _tituloController.text.trim(),
        valor: valor,
        data: _dataSelecionada,
        categoria: _categoriaSelecionada,
        tipo: _tipoSelecionado,
      );

      await widget.db.adicionarGasto(novoGasto);

      if (mounted) {
        Navigator.pop(context);
        AppFeedback.showSuccess(context, 'Gasto salvo com sucesso!');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Gasto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tituloController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Título (Ex: Mercado, Uber)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o título do gasto.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _valorController,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[MoedaInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o valor do gasto.';
                  }

                  try {
                    final double valor = AppFormatters.parseMoedaInput(value);
                    if (valor <= 0) {
                      return 'Informe um valor numérico maior que zero.';
                    }
                  } catch (_) {
                    return 'Informe um valor numérico maior que zero.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<CategoriaGasto>(
                      initialValue: _categoriaSelecionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: CategoriaGasto.values
                          .map(
                            (categoria) => DropdownMenuItem<CategoriaGasto>(
                              value: categoria,
                              child: Text(categoria.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoriaSelecionada = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<TipoGasto>(
                      initialValue: _tipoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: TipoGasto.values
                          .map(
                            (tipo) => DropdownMenuItem<TipoGasto>(
                              value: tipo,
                              child: Text(tipo.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tipoSelecionado = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              OutlinedButton.icon(
                onPressed: _selecionarData,
                icon: const Icon(Icons.calendar_month),
                label: Text('Data: ${_formatarData(_dataSelecionada)}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvarGasto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SALVAR GASTO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
