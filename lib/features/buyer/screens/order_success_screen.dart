import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../models/order_model.dart';
import '../../../core/utils/extensions.dart';

class OrderSuccessScreen extends StatelessWidget {
  final OrderModel? order;
  const OrderSuccessScreen({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = order?.id.substring(0, 8).toUpperCase() ?? '—';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/success.json',
                width: 200,
                height: 200,
                repeat: false,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.check_circle_rounded,
                  size: 100,
                  color: Color(0xFF32C573),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Order Placed! 🎉',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #$orderId is being prepared',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (order != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _Row('Vendor', order!.vendorBrandName),
                      const SizedBox(height: 6),
                      _Row('Total', order!.total.toCurrency()),
                      const SizedBox(height: 6),
                      _Row('Delivery',
                          order!.deliveryType == 'pickup' ? 'Pickup' : 'Delivery'),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go('/buyer/orders'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Track Order',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/buyer/home'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
