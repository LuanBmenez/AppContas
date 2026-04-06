import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/conta_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_feedback.dart';
import '../../utils/app_formatters.dart';

class NovoRecebivelScreen extends StatefulWidget {
  const NovoRecebivelScreen({super.key, required this.db});

  final DatabaseService db;

  @override
  State<NovoRecebivelScreen> createState() => _NovoRecebivelScreenState();
}

class _NovoRecebivelScreenState extends State<NovoRecebivelScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _salvando = false;

  String _normalizarMensagemErro(Object error) {
    final String texto = error.toString();
    final String lower = texto.toLowerCase();

    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return 'Cloud Firestore desativado ou sem permissão no projeto.\n'
          'Ative o Firestore no Firebase Console e tente novamente.';
    }

    return 'Erro ao salvar: $texto';
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvarConta() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);

      try {
        final double valor = AppFormatters.parseMoedaInput(
          _valorController.text,
        );

        final Conta novaConta = Conta(
          id: '',
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          valor: valor,
          data: DateTime.now(),
        );

        await widget.db.adicionarRecebivel(novaConta);

        if (mounted) {
          Navigator.pop(context);
          AppFeedback.showSuccess(context, 'Item a receber salvo com sucesso!');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _salvando = false);
          AppFeedback.showError(context, _normalizarMensagemErro(e));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Item a Receber'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextFormField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome de quem deve',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite um nome.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                controller: _descricaoController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Descrição (Ex: Internet de Abril)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, descreva o que esta sendo cobrado.';
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
                  labelText: 'Valor (Ex: 45.50)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o valor.';
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
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvarConta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SALVAR ITEM A RECEBER',
                          style: TextStyle(fontSize: 16),
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
