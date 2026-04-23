import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/referral_generator.dart';
import '../../../core/constants/app_strings.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role = AppStrings.buyer;
  String _referralPreview = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _brandCtrl.addListener(() {
      setState(() {
        _referralPreview =
            ReferralGenerator.fromBrandName(_brandCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _brandCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authActionsProvider).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: _role,
          brandName: _role == AppStrings.vendor ? _brandCtrl.text.trim() : null,
          contactNumber:
              _role == AppStrings.vendor ? _phoneCtrl.text.trim() : null,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    // Router handles redirect on Firebase auth state change
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who are you?',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _RoleCard(
                      icon: Icons.shopping_bag_outlined,
                      label: "I'm a Buyer",
                      selected: _role == AppStrings.buyer,
                      onTap: () =>
                          setState(() => _role = AppStrings.buyer),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _RoleCard(
                      icon: Icons.storefront_outlined,
                      label: "I'm a Seller",
                      selected: _role == AppStrings.vendor,
                      onTap: () =>
                          setState(() => _role = AppStrings.vendor),
                    )),
                  ],
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  validator: (v) => Validators.required(v, 'Name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscure: true,
                  validator: Validators.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmCtrl,
                  obscure: true,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                if (_role == AppStrings.vendor) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Store Information',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Brand / Store Name',
                    controller: _brandCtrl,
                    validator: (v) =>
                        Validators.required(v, 'Brand name'),
                    prefixIcon: const Icon(Icons.store_outlined),
                  ),
                  if (_brandCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.qr_code, size: 14,
                          color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Referral code: $_referralPreview',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Contact Number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ],
                const SizedBox(height: 32),
                AppButton(
                  label: 'Create Account',
                  onPressed: _register,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ',
                        style: theme.textTheme.bodyMedium),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
