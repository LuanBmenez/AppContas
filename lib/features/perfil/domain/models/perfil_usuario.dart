import 'package:firebase_auth/firebase_auth.dart';
import 'package:paga_o_que_me_deve/core/theme/theme.dart';

class PerfilUsuario {
  const PerfilUsuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.workspaceId,
    required this.mostrarValoresDashboard,
    required this.confirmarAcoesDestrutivas,
    required this.receberResumoMensal,
    required this.preferenciaTema,
    required this.displayNameSyncPending,
  });

  factory PerfilUsuario.fromSources({
    required User user,
    required Map<String, dynamic>? data,
  }) {
    final safeData = data ?? <String, dynamic>{};
    final preferencias =
        (safeData['preferencias'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return PerfilUsuario(
      uid: user.uid,
      nome: (safeData['nome'] ?? '').toString().trim(),
      email: _resolveEmail(user: user, data: safeData),
      workspaceId: (safeData['workspaceId'] ?? user.uid).toString(),
      mostrarValoresDashboard: preferencias['mostrarValoresDashboard'] is! bool || preferencias['mostrarValoresDashboard'] as bool,
      confirmarAcoesDestrutivas:
          preferencias['confirmarAcoesDestrutivas'] is! bool || preferencias['confirmarAcoesDestrutivas'] as bool,
      receberResumoMensal: preferencias['receberResumoMensal'] is bool && preferencias['receberResumoMensal'] as bool,
      preferenciaTema: AppThemePreference.fromValue(preferencias['tema']),
      displayNameSyncPending: safeData['displayNameSyncPending'] == true,
    );
  }

  final String uid;
  final String nome;
  final String email;
  final String workspaceId;
  final bool mostrarValoresDashboard;
  final bool confirmarAcoesDestrutivas;
  final bool receberResumoMensal;
  final AppThemePreference preferenciaTema;
  final bool displayNameSyncPending;

  String get nomeExibicao {
    if (nome.isNotEmpty) {
      return nome;
    }

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Usuario';
  }

  String get emailExibicao => email.isEmpty ? 'Sem e-mail' : email;

  String get iniciais {
    final partes = nomeExibicao
        .split(' ')
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) {
      return 'U';
    }

    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }

    final primeira = partes.first.substring(0, 1).toUpperCase();
    final ultima = partes.last.substring(0, 1).toUpperCase();

    return '$primeira$ultima';
  }

  static Map<String, dynamic> preferenciasIniciais() {
    return <String, dynamic>{
      'mostrarValoresDashboard': true,
      'confirmarAcoesDestrutivas': true,
      'receberResumoMensal': false,
      'tema': AppThemePreference.system.value,
    };
  }

  static String _resolveEmail({
    required User user,
    required Map<String, dynamic> data,
  }) {
    final emailDoc = (data['email'] ?? '').toString().trim();
    if (emailDoc.isNotEmpty) {
      return emailDoc;
    }

    return (user.email ?? '').trim();
  }
}
