import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/models/account.dart';
import '../../products/models/product.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(product: product, quantity: quantity ?? this.quantity);
  }
}

class CartState {
  const CartState({
    this.lines = const [],
    this.discount = 0,
    this.customer,
  });

  final List<CartLine> lines;
  final double discount;
  final Customer? customer;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => lines.fold(0, (sum, line) => sum + line.subtotal);

  double get taxableSubtotal => lines
      .where((line) => !line.product.taxExempt)
      .fold(0, (sum, line) => sum + line.subtotal);

  double tax(double ivaRate) => taxableSubtotal * (ivaRate / 100);

  double total(double ivaRate) {
    final value = subtotal - discount + tax(ivaRate);
    return value < 0 ? 0 : value;
  }

  CartState copyWith({
    List<CartLine>? lines,
    double? discount,
    Customer? customer,
    bool clearCustomer = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      discount: discount ?? this.discount,
      customer: clearCustomer ? null : (customer ?? this.customer),
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void add(Product product) {
    if (!product.hasStock) return;

    final index = state.lines.indexWhere(
      (line) => line.product.id == product.id,
    );

    if (index == -1) {
      state = state.copyWith(
        lines: [
          ...state.lines,
          CartLine(product: product, quantity: 1),
        ],
      );
      return;
    }

    final line = state.lines[index];
    if (line.quantity >= product.stock) return;

    final updated = [...state.lines];
    updated[index] = line.copyWith(quantity: line.quantity + 1);
    state = state.copyWith(lines: updated);
  }

  void increment(String productId) {
    final index = state.lines.indexWhere(
      (line) => line.product.id == productId,
    );
    if (index == -1) return;
    final line = state.lines[index];
    if (line.quantity >= line.product.stock) return;
    final updated = [...state.lines];
    updated[index] = line.copyWith(quantity: line.quantity + 1);
    state = state.copyWith(lines: updated);
  }

  void decrement(String productId) {
    final index = state.lines.indexWhere(
      (line) => line.product.id == productId,
    );
    if (index == -1) return;

    final line = state.lines[index];
    if (line.quantity <= 1) {
      remove(productId);
      return;
    }

    final updated = [...state.lines];
    updated[index] = line.copyWith(quantity: line.quantity - 1);
    state = state.copyWith(lines: updated);
  }

  void remove(String productId) {
    state = state.copyWith(
      lines: state.lines
          .where((line) => line.product.id != productId)
          .toList(),
    );
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    final index = state.lines.indexWhere(
      (line) => line.product.id == productId,
    );
    if (index == -1) return;
    final line = state.lines[index];
    final capped = quantity.clamp(0, line.product.stock);
    final updated = [...state.lines];
    updated[index] = line.copyWith(quantity: capped);
    state = state.copyWith(lines: updated);
  }

  void setDiscount(double discount) {
    state = state.copyWith(discount: discount < 0 ? 0 : discount);
  }

  void setCustomer(Customer? customer) {
    state = state.copyWith(
      customer: customer,
      clearCustomer: customer == null,
    );
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});
