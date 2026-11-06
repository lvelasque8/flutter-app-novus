class BusinessSettings {
  const BusinessSettings({
    required this.businessName,
    required this.rif,
    required this.address,
    required this.phone,
    required this.rateBs,
    required this.ivaRate,
    required this.onboarded,
    this.rateUpdatedAt,
    this.rateSource = '',
    this.lastBackupAt,
  });

  final String businessName;
  final String rif;
  final String address;
  final String phone;

  /// Bolívares por dólar.
  final double rateBs;

  /// Porcentaje de IVA (16 = 16 %).
  final double ivaRate;

  final bool onboarded;

  /// Última vez que se actualizó la tasa.
  final DateTime? rateUpdatedAt;

  /// `bcv`, `api` o `manual`.
  final String rateSource;

  final DateTime? lastBackupAt;

  factory BusinessSettings.initial() {
    return const BusinessSettings(
      businessName: 'Mi negocio',
      rif: '',
      address: '',
      phone: '',
      rateBs: 0,
      ivaRate: 16,
      onboarded: false,
    );
  }

  bool get hasRate => rateBs > 0;

  BusinessSettings copyWith({
    String? businessName,
    String? rif,
    String? address,
    String? phone,
    double? rateBs,
    double? ivaRate,
    bool? onboarded,
    DateTime? rateUpdatedAt,
    String? rateSource,
    DateTime? lastBackupAt,
    bool clearRateUpdatedAt = false,
    bool clearLastBackupAt = false,
  }) {
    return BusinessSettings(
      businessName: businessName ?? this.businessName,
      rif: rif ?? this.rif,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      rateBs: rateBs ?? this.rateBs,
      ivaRate: ivaRate ?? this.ivaRate,
      onboarded: onboarded ?? this.onboarded,
      rateUpdatedAt:
          clearRateUpdatedAt ? null : (rateUpdatedAt ?? this.rateUpdatedAt),
      rateSource: rateSource ?? this.rateSource,
      lastBackupAt:
          clearLastBackupAt ? null : (lastBackupAt ?? this.lastBackupAt),
    );
  }
}
