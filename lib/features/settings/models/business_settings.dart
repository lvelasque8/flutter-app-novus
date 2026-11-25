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
    this.paymentInfoEnabled = false,
    this.paymentBank = '',
    this.paymentAccount = '',
    this.paymentHolder = '',
    this.paymentDocument = '',
    this.paymentMobilePhone = '',
    this.paymentNote = '',
    this.creditDueDays = 15,
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

  /// Si se incluyen los datos de pago en el estado de cuenta de WhatsApp.
  final bool paymentInfoEnabled;

  final String paymentBank;
  final String paymentAccount;
  final String paymentHolder;
  final String paymentDocument;
  final String paymentMobilePhone;
  final String paymentNote;

  /// Días de plazo para los fiados. `0` significa sin vencimiento.
  final int creditDueDays;

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

  bool get hasPaymentInfo =>
      paymentBank.trim().isNotEmpty ||
      paymentAccount.trim().isNotEmpty ||
      paymentHolder.trim().isNotEmpty ||
      paymentDocument.trim().isNotEmpty ||
      paymentMobilePhone.trim().isNotEmpty ||
      paymentNote.trim().isNotEmpty;

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
    bool? paymentInfoEnabled,
    String? paymentBank,
    String? paymentAccount,
    String? paymentHolder,
    String? paymentDocument,
    String? paymentMobilePhone,
    String? paymentNote,
    int? creditDueDays,
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
      paymentInfoEnabled:
          paymentInfoEnabled ?? this.paymentInfoEnabled,
      paymentBank: paymentBank ?? this.paymentBank,
      paymentAccount: paymentAccount ?? this.paymentAccount,
      paymentHolder: paymentHolder ?? this.paymentHolder,
      paymentDocument: paymentDocument ?? this.paymentDocument,
      paymentMobilePhone: paymentMobilePhone ?? this.paymentMobilePhone,
      paymentNote: paymentNote ?? this.paymentNote,
      creditDueDays: creditDueDays ?? this.creditDueDays,
    );
  }
}
