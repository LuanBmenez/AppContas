class TextNormalizer {
  TextNormalizer._();

  // Compilamos as expressões regulares apenas uma vez (ganho enorme de performance)
  static final _searchNonChars = RegExp('[^A-Z0-9 ]');
  static final _spaces = RegExp(r'\s+');
  static final _headerNonChars = RegExp('[^a-z0-9]+');
  static final _underscores = RegExp('_+');
  static final _edgeUnderscores = RegExp(r'^_|_$');

  // RegEx para remoção de acentos
  static final _regA = RegExp('[ÁÀÃÂ]');
  static final _regE = RegExp('[ÉÈÊ]');
  static final _regI = RegExp('[ÍÌÎ]');
  static final _regO = RegExp('[ÓÒÕÔ]');
  static final _regU = RegExp('[ÚÙÛ]');
  static final _regAm = RegExp('[áàãâ]');
  static final _regEm = RegExp('[éèê]');
  static final _regIm = RegExp('[íìî]');
  static final _regOm = RegExp('[óòõô]');
  static final _regUm = RegExp('[úùû]');

  static String normalizeForSearch(String text) {
    return _removeDiacritics(text)
        .toUpperCase()
        .replaceAll(_searchNonChars, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
  }

  static String normalizeForHeader(String text) {
    return _removeDiacritics(text)
        .toLowerCase()
        .replaceAll(_headerNonChars, '_')
        .replaceAll(_underscores, '_')
        .replaceAll(_edgeUnderscores, '');
  }

  static String _removeDiacritics(String text) {
    return text
        .replaceAll(_regA, 'A')
        .replaceAll(_regE, 'E')
        .replaceAll(_regI, 'I')
        .replaceAll(_regO, 'O')
        .replaceAll(_regU, 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(_regAm, 'a')
        .replaceAll(_regEm, 'e')
        .replaceAll(_regIm, 'i')
        .replaceAll(_regOm, 'o')
        .replaceAll(_regUm, 'u')
        .replaceAll('ç', 'c');
  }
}
