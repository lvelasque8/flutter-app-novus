class PaymentMethods {
  PaymentMethods._();

  static const String efectivoBs = 'efectivo_bs';
  static const String efectivoUsd = 'efectivo_usd';
  static const String pagoMovil = 'pago_movil';
  static const String transferencia = 'transferencia';
  static const String puntoVenta = 'punto_venta';
  static const String fiado = 'fiado';
  static const String mixto = 'mixto';
  static const String devolucion = 'devolucion';

  static const List<String> all = [
    efectivoBs,
    efectivoUsd,
    pagoMovil,
    transferencia,
    puntoVenta,
    fiado,
  ];

  static String label(String method) {
    switch (method) {
      case efectivoBs:
        return 'Efectivo Bs';
      case efectivoUsd:
        return 'Efectivo USD';
      case pagoMovil:
        return 'Pago Móvil';
      case transferencia:
        return 'Transferencia';
      case puntoVenta:
        return 'Punto de venta';
      case fiado:
        return 'Fiado';
      case mixto:
        return 'Pago mixto';
      case devolucion:
        return 'Devolución (cuenta)';
      default:
        return method;
    }
  }

  static bool isCredit(String method) => method == fiado;

  static bool requiresReference(String method) {
    return method == pagoMovil || method == transferencia;
  }
}

class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.unitCost = 0,
  });

  final String id;
  final String saleId;
  final String productId;
  final String name;
  final double price;
  final double unitCost;
  final int quantity;
  final double subtotal;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'name': name,
      'price': price,
      'unit_cost': unitCost,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, Object?> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: (map['sale_id'] as String?) ?? '',
      productId: (map['product_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      price: ((map['price'] as num?) ?? 0).toDouble(),
      unitCost: ((map['unit_cost'] as num?) ?? 0).toDouble(),
      quantity: ((map['quantity'] as num?) ?? 0).toInt(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
    );
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.rate,
    required this.totalBs,
    required this.paymentMethod,
    required this.reference,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.payments = const [],
    this.returns = const [],
    this.refunded = 0,
    this.refundedBs = 0,
    this.cancelled = false,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String number;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double rate;
  final double totalBs;
  final String paymentMethod;
  final String? reference;

  /// `pagada` o `pendiente` (fiado).
  final String status;
  final DateTime createdAt;
  final List<SaleItem> items;
  final List<SalePayment> payments;
  final List<SaleReturn> returns;

  /// Monto ya devuelto (parcial o total) de esta venta.
  final double refunded;
  final double refundedBs;

  /// Una venta anulada no suma en caja, reportes ni cuentas por cobrar.
  final bool cancelled;
  final DateTime? cancelledAt;
  final String? cancelReason;

  bool get isCredit => status == 'pendiente';
  bool get isCancelled => cancelled;
  bool get hasReturns => refunded > 0.005;
  bool get isFullyRefunded => refunded >= total - 0.01;

  double get netTotal => (total - refunded).clamp(0, double.infinity);
  double get netTotalBs => (totalBs - refundedBs).clamp(0, double.infinity);

  /// Cantidad ya devuelta de una línea de la venta.
  int returnedQuantity(String saleItemId) {
    return returns
        .expand((saleReturn) => saleReturn.items)
        .where((item) => item.saleItemId == saleItemId)
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Sale copyWith({
    List<SaleItem>? items,
    List<SalePayment>? payments,
    List<SaleReturn>? returns,
    double? refunded,
    double? refundedBs,
    bool? cancelled,
    DateTime? cancelledAt,
    String? cancelReason,
  }) {
    return Sale(
      id: id,
      number: number,
      customerId: customerId,
      customerName: customerName,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      rate: rate,
      totalBs: totalBs,
      paymentMethod: paymentMethod,
      reference: reference,
      status: status,
      createdAt: createdAt,
      items: items ?? this.items,
      payments: payments ?? this.payments,
      returns: returns ?? this.returns,
      refunded: refunded ?? this.refunded,
      refundedBs: refundedBs ?? this.refundedBs,
      cancelled: cancelled ?? this.cancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'number': number,
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'rate': rate,
      'total_bs': totalBs,
      'payment_method': paymentMethod,
      'reference': reference,
      'status': status,
      'cancelled': cancelled ? 1 : 0,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancel_reason': cancelReason,
      'refunded': refunded,
      'refunded_bs': refundedBs,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(
    Map<String, Object?> map, {
    List<SaleItem>? items,
    List<SalePayment>? payments,
    List<SaleReturn>? returns,
  }) {
    return Sale(
      id: map['id'] as String,
      number: (map['number'] as String?) ?? '',
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
      discount: ((map['discount'] as num?) ?? 0).toDouble(),
      tax: ((map['tax'] as num?) ?? 0).toDouble(),
      total: ((map['total'] as num?) ?? 0).toDouble(),
      rate: ((map['rate'] as num?) ?? 0).toDouble(),
      totalBs: ((map['total_bs'] as num?) ?? 0).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? '',
      reference: map['reference'] as String?,
      status: (map['status'] as String?) ?? 'pagada',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      items: items ?? const [],
      payments: payments ?? const [],
      returns: returns ?? const [],
      refunded: ((map['refunded'] as num?) ?? 0).toDouble(),
      refundedBs: ((map['refunded_bs'] as num?) ?? 0).toDouble(),
      cancelled: ((map['cancelled'] as num?) ?? 0) == 1,
      cancelledAt: DateTime.tryParse(
        (map['cancelled_at'] as String?) ?? '',
      ),
      cancelReason: map['cancel_reason'] as String?,
    );
  }
}

class SalePayment {
  const SalePayment({
    required this.id,
    required this.saleId,
    required this.method,
    required this.amount,
    required this.amountBs,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final String saleId;
  final String method;
  final double amount;
  final double amountBs;
  final String? reference;
  final DateTime createdAt;

  factory SalePayment.fromMap(Map<String, Object?> map) {
    return SalePayment(
      id: map['id'] as String,
      saleId: (map['sale_id'] as String?) ?? '',
      method: (map['method'] as String?) ?? '',
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      amountBs: ((map['amount_bs'] as num?) ?? 0).toDouble(),
      reference: map['reference'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class SaleReturnItem {
  const SaleReturnItem({
    required this.id,
    required this.returnId,
    required this.saleItemId,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  final String id;
  final String returnId;
  final String saleItemId;
  final String? productId;
  final String name;
  final double price;
  final int quantity;
  final double subtotal;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'return_id': returnId,
      'sale_item_id': saleItemId,
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleReturnItem.fromMap(Map<String, Object?> map) {
    return SaleReturnItem(
      id: map['id'] as String,
      returnId: (map['return_id'] as String?) ?? '',
      saleItemId: (map['sale_item_id'] as String?) ?? '',
      productId: map['product_id'] as String?,
      name: (map['name'] as String?) ?? '',
      price: ((map['price'] as num?) ?? 0).toDouble(),
      quantity: ((map['quantity'] as num?) ?? 0).toInt(),
      subtotal: ((map['subtotal'] as num?) ?? 0).toDouble(),
    );
  }
}

class SaleReturn {
  const SaleReturn({
    required this.id,
    required this.saleId,
    required this.method,
    required this.total,
    required this.totalBs,
    required this.rate,
    required this.createdAt,
    this.reason,
    this.items = const [],
  });

  final String id;
  final String saleId;
  final String method;
  final double total;
  final double totalBs;
  final double rate;
  final String? reason;
  final DateTime createdAt;
  final List<SaleReturnItem> items;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'method': method,
      'total': total,
      'total_bs': totalBs,
      'rate': rate,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SaleReturn.fromMap(
    Map<String, Object?> map, {
    List<SaleReturnItem>? items,
  }) {
    return SaleReturn(
      id: map['id'] as String,
      saleId: (map['sale_id'] as String?) ?? '',
      method: (map['method'] as String?) ?? '',
      total: ((map['total'] as num?) ?? 0).toDouble(),
      totalBs: ((map['total_bs'] as num?) ?? 0).toDouble(),
      rate: ((map['rate'] as num?) ?? 0).toDouble(),
      reason: map['reason'] as String?,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      items: items ?? const [],
    );
  }
}
