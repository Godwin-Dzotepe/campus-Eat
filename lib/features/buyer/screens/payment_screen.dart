import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/write_log_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/order_model.dart';
import '../../../models/address_model.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _method = 'card';
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  bool _validateCard() {
    final num = _cardCtrl.text.replaceAll(' ', '');
    if (num.length != 16) {
      _snack('Enter a valid 16-digit card number');
      return false;
    }
    if (_expiryCtrl.text.length < 5) {
      _snack('Enter a valid expiry (MM/YY)');
      return false;
    }
    if (_cvvCtrl.text.length < 3) {
      _snack('Enter a valid CVV');
      return false;
    }
    return true;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pay(Map<String, dynamic> args) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final total = (args['total'] as num).toDouble();

    if (_method == 'card' && !_validateCard()) return;
    if (_method == 'wallet') {
      final balance = (user.walletBalance ?? 0.0);
      if (balance < total) {
        _snack('Insufficient wallet balance');
        return;
      }
    }

    setState(() => _processing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      setState(() => _processing = false);
      _snack('Your cart is empty');
      return;
    }
    final deliveryType = args['deliveryType'] as String? ?? 'pickup';
    final deliveryFee = (args['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final address = args['address'] as AddressModel?;
    final referral = args['referral'] as String?;

    final orderId = const Uuid().v4();
    final order = OrderModel(
      id: orderId,
      buyerId: user.id,
      buyerName: user.name,
      vendorId: cart.first.vendorId,
      vendorBrandName: cart.first.vendorBrandName,
      items: List.from(cart),
      subtotal: ref.read(cartProvider.notifier).subtotal,
      deliveryFee: deliveryFee,
      total: total,
      deliveryType: deliveryType,
      status: AppStrings.placed,
      deliveryAddress: address?.fullAddress,
      deliveryLat: address?.lat,
      deliveryLng: address?.lng,
      paymentMethod: _method,
      isPaid: true,
      createdAt: DateTime.now(),
      referralCodeUsed: referral != null && referral.isNotEmpty ? referral : null,
    );

    final db = FirebaseFirestore.instance;
    await WriteLogService.capture(
      action: 'Create order',
      target: 'orders/$orderId',
      task: () => db.collection('orders').doc(orderId).set(order.toMap()),
    );

    if (_method == 'wallet') {
      await WriteLogService.capture(
        action: 'Update wallet balance',
        target: 'users/${user.id}',
        task: () => db.collection('users').doc(user.id).update({
          'walletBalance': FieldValue.increment(-total),
        }),
      );
    }

    ref.read(cartProvider.notifier).clear();
    ref.read(selectedAddressProvider.notifier).state = null;
    ref.read(deliveryTypeProvider.notifier).state = 'pickup';

    await NotificationService.orderPlaced(
        orderId.substring(0, 8).toUpperCase());

    setState(() => _processing = false);
    if (mounted) context.go('/buyer/success', extra: order);
  }

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            {};
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final total =
        (args['total'] as num?)?.toDouble() ??
            ref.read(cartProvider.notifier).subtotal;
    final walletBalance = user?.walletBalance ?? 0.0;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Payment'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text('Amount to Pay',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                    const SizedBox(height: 6),
                    Text(
                      total.toCurrency(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Text('Payment Method',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _MethodTile(
                icon: Icons.credit_card_rounded,
                label: 'Card Payment',
                subtitle: 'Debit / Credit card',
                selected: _method == 'card',
                onTap: () => setState(() => _method = 'card'),
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Campus Wallet',
                subtitle: 'Balance: ${walletBalance.toCurrency()}',
                selected: _method == 'wallet',
                onTap: () => setState(() => _method = 'wallet'),
              ),
              if (_method == 'card') ...[
                const SizedBox(height: 24),
                Text('Card Details',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CardNumberFormatter(),
                  ],
                  maxLength: 19,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    hintText: '0000 0000 0000 0000',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                      ],
                      maxLength: 5,
                      decoration: InputDecoration(
                        labelText: 'MM/YY',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      maxLength: 3,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _processing ? null : () => _pay(args),
                icon: const Icon(Icons.lock_rounded),
                label: Text('Pay ${total.toCurrency()}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('🔒 Secure simulated payment',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        if (_processing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing payment...',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? theme.colorScheme.primary : null)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
        ]),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length >= 2) {
      final formatted =
          '${digits.substring(0, 2)}/${digits.substring(2)}';
      return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return newValue;
  }
}
