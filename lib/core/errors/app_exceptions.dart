class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;

  factory AppException.from(Object? error) {
    if (error is AppException) {
      return error;
    }

    final texto = error.toString();
    final lower = texto.toLowerCase();

    if (lower.contains('firestore.googleapis.com') ||
        lower.contains('permission_denied')) {
      return AppException(
        'Sem permissão de acesso ao banco de dados ou serviço desativado.',
      );
    }

    if (lower.contains('network_error') ||
        lower.contains('offline') ||
        lower.contains('socketexception')) {
      return AppException(
        'Parece que você está sem internet. Verifique sua conexão.',
      );
    }

    if (lower.contains('user-not-found')) {
      return AppException('Usuário não encontrado no sistema.');
    }

    return AppException(
      'Ocorreu um erro inesperado. Tente novamente mais tarde.',
    );
  }
}
