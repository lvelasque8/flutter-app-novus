class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.document,
    required this.phone,
    required this.address,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String document;
  final String phone;
  final String address;
  final String notes;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'document': document,
      'phone': phone,
      'address': address,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      document: (map['document'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.customerId,
    required this.saleId,
    required this.total,
    required this.paid,
    required this.status,
    required this.createdAt,
    this.dueDate,
  });

  final String id;
  final String customerId;
  final String? saleId;
  final double total;
  final double paid;
  final String status;
  final DateTime createdAt;
  final DateTime? dueDate;

  double get balance => (total - paid).clamp(0, double.infinity);
  bool get isPaid => status == 'pagada' || balance <= 0.005;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'sale_id': saleId,
      'total': total,
      'paid': paid,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: map['id'] as String,
      customerId: (map['customer_id'] as String?) ?? '',
      saleId: map['sale_id'] as String?,
      total: ((map['total'] as num?) ?? 0).toDouble(),
      paid: ((map['paid'] as num?) ?? 0).toDouble(),
      status: (map['status'] as String?) ?? 'pendiente',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      dueDate: DateTime.tryParse((map['due_date'] as String?) ?? ''),
    );
  }
}

class AccountPayment {
  const AccountPayment({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.method,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String accountId;
  final double amount;
  final String method;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'method': method,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AccountPayment.fromMap(Map<String, Object?> map) {
    return AccountPayment(
      id: map['id'] as String,
      accountId: (map['account_id'] as String?) ?? '',
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      method: (map['method'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class AccountSummary {
  const AccountSummary({
    required this.customer,
    required this.balance,
    required this.openAccounts,
  });

  final Customer customer;
  final double balance;
  final int openAccounts;
}
