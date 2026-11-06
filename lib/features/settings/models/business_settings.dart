class BusinessSettings {
  const BusinessSettings({
    required this.businessName,
    required this.rif,
    required this.address,
    required this.phone,
    required this.rateBs,
    required this.ivaRate,
    required this.onboarded,
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

  BusinessSettings copyWith({
    String? businessName,
    String? rif,
    String? address,
    String? phone,
    double? rateBs,
    double? ivaRate,
    bool? onboarded,
  }) {
    return BusinessSettings(
      businessName: businessName ?? this.businessName,
      rif: rif ?? this.rif,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      rateBs: rateBs ?? this.rateBs,
      ivaRate: ivaRate ?? this.ivaRate,
      onboarded: onboarded ?? this.onboarded,
    );
  }
}
