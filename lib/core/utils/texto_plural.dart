/// Textos con cantidad en singular o plural.
///
/// Uso: `TextoPlural.de(1, 'venta', 'ventas')` devuelve `"1 venta"`.
class TextoPlural {
  TextoPlural._();

  /// Devuelve `"<cantidad> <singular>"` cuando la cantidad es 1 o -1,
  /// y `"<cantidad> <plural>"` en cualquier otro caso.
  static String de(int cantidad, String singular, String plural) {
    final palabra = cantidad == 1 || cantidad == -1 ? singular : plural;
    return '$cantidad $palabra';
  }
}
