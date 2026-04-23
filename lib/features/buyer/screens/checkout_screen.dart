import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../../../core/utils/extensions.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _referralCtrl = TextEditingController();
  double _vendorDeliveryFee = 0;

  @override
  void initState() {
    super.initState();
    _loadDeliveryFee();
  }

  Future<void> _loadDeliveryFee() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(cart.first.vendorId)
        .get();
    if (mounted) {
      setState(() {
        _vendorDeliveryFee =
            (doc.data()?['deliveryFee'] as num?)?.toDouble() ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _referralCtrl.dispose();
    super.dispose();
  }

  double _getDeliveryFee() => _vendorDeliveryFee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = ref.watch(cartProvider);
    final cartLoading = ref.watch(cartLoadingProvider);
    final deliveryType = ref.watch(deliveryTypeProvider);
    final address = ref.watch(selectedAddressProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    final deliveryFee = deliveryType == 'delivery' ? _getDeliveryFee() : 0.0;
    final subtotal = cartNotifier.subtotal;
    final total = subtotal + deliveryFee;

    if (cartLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (cart.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/buyer/cart'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final vendorName = cart.first.vendorBrandName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order summary
          Text('Order Summary',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.store_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(vendorName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary)),
                  ]),
                  const Divider(height: 16),
                  ...cart.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(
                              child: Text('${item.foodName} × ${item.quantity}')),
                          Text((item.price * item.quantity).toCurrency(),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Delivery type toggle
          Text('Delivery Option',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _DeliveryOption(
              label: 'Pickup',
              subtitle: 'Free',
              icon: Icons.store_rounded,
              selected: deliveryType == 'pickup',
              onTap: () {
                ref.read(deliveryTypeProvider.notifier).state = 'pickup';
              },
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _DeliveryOption(
              label: 'Delivery',
              subtitle: _getDeliveryFee().toCurrency(),
              icon: Icons.delivery_dining_rounded,
              selected: deliveryType == 'delivery',
              onTap: () =>
                  ref.read(deliveryTypeProvider.notifier).state = 'delivery',
            )),
          ]),

          const SizedBox(height: 16),
          Text('Meet-up Location (Required)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              await context.push('/buyer/location');
              setState(() {});
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.location_on_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: address == null
                        ? Text('Tap to select where to meet the vendor',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(address.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(address.fullAddress,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Referral code
          Text('Referral Code (Optional)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _referralCtrl,
            decoration: InputDecoration(
              hintText: 'Enter referral code',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.qr_code),
            ),
          ),

          const SizedBox(height: 24),

          // Cost breakdown
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _SummaryRow('Subtotal', subtotal.toCurrency()),
                const SizedBox(height: 6),
                _SummaryRow(
                    'Delivery',
                    deliveryType == 'pickup'
                        ? 'Free'
                        : deliveryFee.toCurrency()),
                const Divider(height: 16),
                _SummaryRow('Total', total.toCurrency(), bold: true),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              if (address == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please select a meet-up location first')));
                return;
              }
              context.push('/buyer/payment', extra: {
                'deliveryType': deliveryType,
                'deliveryFee': deliveryFee,
                'total': total,
                'address': address,
                'referral': _referralCtrl.text.trim(),
              });
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Proceed to Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryOption({
    required this.label,
    required this.subtitle,
    required this.icon,
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
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.grey)),
        ]),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                fontSize: bold ? 16 : 14)),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontSize: bold ? 16 : 14,
                color: bold
                    ? Theme.of(context).colorScheme.primary
                    : null)),
      ],
    );
  }
}
