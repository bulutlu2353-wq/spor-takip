/// Dile duyarlı büyük harf. Dart'ın `toUpperCase`'i dil bilmez; Türkçede
/// "i" → "İ", "ı" → "I" olmalı.
String upperCaseFor(String text, String languageCode) {
  if (languageCode != 'tr') return text.toUpperCase();
  return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
