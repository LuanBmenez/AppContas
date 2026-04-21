class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;

  /// Construtor de Fábrica que converte um erro bruto em uma mensagem amigável
  factory AppException.from(Object? error) {
    final texto = error.toString();
    final lower = texto.toLowerCase();

    // Erros de Banco de Dados / Firebase
    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return AppException(
        'Sem permissão de acesso ao banco de dados ou serviço desativado.',
      );
    }

    // Erros de Internet
    if (lower.contains('network_error') ||
        lower.contains('offline') ||
        lower.contains('socketexception')) {
      return AppException(
        'Parece que você está sem internet. Verifique sua conexão.',
      );
    }

    // Outros erros mapeados...
    if (lower.contains('user-not-found')) {
      return AppException('Usuário não encontrado no sistema.');
    }

    // Fallback genérico para não mostrar rastros de código assustadores ao usuário
    return AppException(
      'Ocorreu um erro inesperado. Tente novamente mais tarde.',
    );
  }
}
