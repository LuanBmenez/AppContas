import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';
import 'package:paga_o_que_me_deve/core/utils/utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _entrando = false;
  bool _modoCadastro = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    if (_entrando) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _entrando = true);
    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final senha = _senhaController.text;
      final nomeBase = email.contains('@')
          ? email.split('@').first
          : 'Usuario';

      if (_modoCadastro) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );
        final novoUser = auth.currentUser;
        if (novoUser != null &&
            (novoUser.displayName == null ||
                novoUser.displayName!.trim().isEmpty)) {
          await novoUser.updateDisplayName(nomeBase);
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: senha);
      }

      final uid = auth.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).set({
        'email': email,
        'nome': nomeBase,
        'workspaceId': uid,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await firestore.collection('workspaces').doc(uid).set({
        'ownerUid': uid,
        'nome': 'Workspace de $email',
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      AppFeedback.showSuccess(
        context,
        _modoCadastro
            ? 'Conta criada com sucesso.'
            : 'Login realizado com sucesso.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, _mensagemErroAuth(e));
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(context, 'Falha na autenticação. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _entrando = false);
      }
    }
  }

  String _mensagemErroAuth(FirebaseAuthException e) {
    final mensagem = (e.message ?? '').toUpperCase();
    if (mensagem.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Configuração do Firebase Auth ausente para este app Android. Atualize o google-services.json e os SHA-1/SHA-256 no Firebase.';
    }

    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'weak-password':
        return 'A senha é fraca. Use pelo menos 6 caracteres.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'operation-not-allowed':
        return 'Login por e-mail/senha não está habilitado no Firebase.';
      case 'internal-error':
        return 'Falha interna de configuração no Firebase Auth. Verifique Email/Senha habilitado e configuração Android (SHA-1/SHA-256).';
      default:
        return e.message ?? 'Erro de autenticação.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s24,
            AppSpacing.s24,
            AppSpacing.s24 + tecladoAberto,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        _modoCadastro ? 'Criar conta' : 'Entrar no app',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        _modoCadastro
                            ? 'Crie sua conta para salvar seus dados no Firebase.'
                            : 'Faça login para acessar seus dados no Firebase.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (value) {
                                final email = (value ?? '').trim();
                                if (email.isEmpty) {
                                  return 'Informe o e-mail.';
                                }
                                if (!email.contains('@') ||
                                    !email.contains('.')) {
                                  return 'E-mail inválido.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            TextFormField(
                              controller: _senhaController,
                              textInputAction: _modoCadastro
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              obscureText: !_mostrarSenha,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _mostrarSenha = !_mostrarSenha;
                                    });
                                  },
                                  icon: Icon(
                                    _mostrarSenha
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final senha = value ?? '';
                                if (senha.isEmpty) {
                                  return 'Informe a senha.';
                                }
                                if (_modoCadastro && senha.length < 6) {
                                  return 'Use pelo menos 6 caracteres.';
                                }
                                return null;
                              },
                            ),
                            if (_modoCadastro) ...[
                              const SizedBox(height: AppSpacing.s12),
                              TextFormField(
                                controller: _confirmarSenhaController,
                                textInputAction: TextInputAction.done,
                                obscureText: !_mostrarSenha,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar senha',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_reset_outlined),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Confirme a senha.';
                                  }
                                  if (value != _senhaController.text) {
                                    return 'As senhas não conferem.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: AppSpacing.s16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _entrando ? null : _autenticar,
                                icon: _entrando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _modoCadastro
                                            ? Icons.person_add_alt_1
                                            : Icons.login,
                                      ),
                                label: Text(
                                  _entrando
                                      ? (_modoCadastro
                                            ? 'Criando conta...'
                                            : 'Entrando...')
                                      : (_modoCadastro
                                            ? 'Criar conta'
                                            : 'Entrar'),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            TextButton(
                              onPressed: _entrando
                                  ? null
                                  : () {
                                      setState(() {
                                        _modoCadastro = !_modoCadastro;
                                        _confirmarSenhaController.clear();
                                      });
                                    },
                              child: Text(
                                _modoCadastro
                                    ? 'Já tem conta? Entrar'
                                    : 'Não tem conta? Criar agora',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
