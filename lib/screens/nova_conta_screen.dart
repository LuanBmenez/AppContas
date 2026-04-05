import 'package:flutter/material.dart';

import '../models/conta_model.dart';
import '../services/database_service.dart';

class NovoRecebivelScreen extends StatefulWidget {
  const NovoRecebivelScreen({super.key});

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
      return 'Cloud Firestore desativado ou sem permissao no projeto.\n'
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
        final String valorTexto = _valorController.text.replaceAll(',', '.');
        final double valor = double.parse(valorTexto);

        final Conta novaConta = Conta(
          id: '',
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          valor: valor,
          data: DateTime.now(),
        );

        await DatabaseService().adicionarRecebivel(novaConta);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item a receber salvo com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_normalizarMensagemErro(e)),
            backgroundColor: Colors.red,
          ),
        );
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
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
              const SizedBox(height: 16),

              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descricao (Ex: Internet de Abril)',
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
              const SizedBox(height: 16),

              TextFormField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor (Ex: 45.50)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o valor.';
                  }

                  final String normalizado = value.replaceAll(',', '.');
                  final double? valor = double.tryParse(normalizado);
                  if (valor == null || valor <= 0) {
                    return 'Informe um valor numerico maior que zero.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),

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
