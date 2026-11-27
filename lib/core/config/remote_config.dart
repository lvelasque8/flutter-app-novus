/// Configuración del panel remoto de solo lectura.
///
/// La clave `publishable` es pública por diseño: solo permite lo que las
/// políticas de seguridad (RLS) autoricen. Nunca colocar aquí la secret key.
class RemoteConfig {
  RemoteConfig._();

  static const String supabaseUrl =
      'https://roawcuxwxeredplaleod.supabase.co';

  static const String supabaseKey =
      'sb_publishable_z-S7Q4uHErZk6Q16e3uWeA_fsQo48pj';

  /// Se completa cuando el panel esté publicado.
  static const String panelUrl = '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
