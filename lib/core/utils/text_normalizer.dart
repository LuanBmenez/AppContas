class TextNormalizer {
  TextNormalizer._();

  static String normalizeForSearch(String text) {
    return _removeDiacritics(text)
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizeForHeader(String text) {
    return _removeDiacritics(text)
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _removeDiacritics(String text) {
    return text
        .replaceAll(RegExp('[ÁÀÃÂ]'), 'A')
        .replaceAll(RegExp('[ÉÈÊ]'), 'E')
        .replaceAll(RegExp('[ÍÌÎ]'), 'I')
        .replaceAll(RegExp('[ÓÒÕÔ]'), 'O')
        .replaceAll(RegExp('[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp('[áàãâ]'), 'a')
        .replaceAll(RegExp('[éèê]'), 'e')
        .replaceAll(RegExp('[íìî]'), 'i')
        .replaceAll(RegExp('[óòõô]'), 'o')
        .replaceAll(RegExp('[úùû]'), 'u')
        .replaceAll('ç', 'c');
  }
}
