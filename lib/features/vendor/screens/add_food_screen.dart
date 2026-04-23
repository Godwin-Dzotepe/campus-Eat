import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../providers/vendor_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../features/buyer/providers/home_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/supabase_food_service.dart';
import '../../../core/services/write_log_service.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCategory;
  XFile? _imageFile;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🍔');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(labelText: 'Emoji (e.g. 🍕)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim().isEmpty ? '🍔' : emojiCtrl.text.trim();
              if (name.isEmpty) return;

              final id = name
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
                  .trim()
                  .replaceAll(RegExp(r'\s+'), '-');
              if (id.isEmpty) return;

              try {
                await FirebaseFirestore.instance.collection('categories').doc(id).set({
                  'id': id,
                  'name': name,
                  'emoji': emoji,
                });

                if (!mounted) return;
                setState(() => _selectedCategory = name);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "$name" added!')),
                  );
                }
              } on FirebaseException catch (e) {
                if (!context.mounted) return;
                final message = e.code == 'permission-denied'
                    ? 'Permission denied: deploy Firestore rules to allow vendor category creation.'
                    : 'Error adding category: ${e.message ?? e.code}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding category: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);

    if (file == null) return;

    if (!kIsWeb) {
      final permission = source == ImageSource.camera ? Permission.camera : Permission.photos;
      final status = await permission.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        // Respect permissions on mobile.
      }
    }

    if (mounted) {
      setState(() => _imageFile = file);
    }
  }

  Future<String?> _uploadImage(String foodId) async {
    if (_imageFile == null) return null;
    final mime = _imageFile!.mimeType ?? '';
    final extension = mime.contains('png') ? 'png' : 'jpg';
    final bytes = await _imageFile!.readAsBytes();

    return await WriteLogService.capture(
      action: 'Upload food image',
      target: 'cloudinary/campus_eat/foods/$foodId.$extension',
      task: () => CloudinaryService.uploadFoodImage(
        foodId: foodId,
        bytes: bytes,
        fileName: 'food.$extension',
      ),
    ).timeout(const Duration(seconds: 25));
  }

  Future<String> _uploadImageWithRetry(String foodId) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        final url = await _uploadImage(foodId);
        if (url != null && url.isNotEmpty) return url;
        throw FirebaseException(
          plugin: 'cloudinary',
          code: 'invalid-url',
          message: 'Upload completed but no download URL was returned.',
        );
      } catch (e) {
        lastError = e;
        if (attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Cloudinary upload failed');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _saving = true);

    final fbUser = FirebaseAuth.instance.currentUser;
    final vendor = ref.read(effectiveVendorProvider);
    final vendorId = vendor?.id ?? fbUser?.uid;
    final vendorName =
        vendor?.brandName ?? vendor?.name ?? fbUser?.displayName ?? fbUser?.email ?? 'Vendor';
    if (vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      setState(() => _saving = false);
      return;
    }

    try {
      final id = const Uuid().v4();
      String? imageUrl;
      if (_imageFile != null) {
        try {
          imageUrl = await _uploadImageWithRetry(id);
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Image upload timed out. Please retry; item was not saved.'),
              ),
            );
          }
          setState(() => _saving = false);
          return;
        } on Exception catch (e) {
          if (mounted) {
            final message = 'Cloudinary upload failed. ${e.toString()}';
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          }
          setState(() => _saving = false);
          return;
        }
      }

      final normalizedPrice =
          _priceCtrl.text.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '');
      final price = double.tryParse(normalizedPrice);
      if (price == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid price.')),
          );
        }
        setState(() => _saving = false);
        return;
      }

      await WriteLogService.capture(
        action: 'Create food item',
        target: 'foods/$id',
        task: () => FirebaseFirestore.instance.collection('foods').doc(id).set({
          'id': id,
          'vendorId': vendorId,
          'vendorBrandName': vendorName,
          'name': _nameCtrl.text.trim(),
          'price': price,
          'category': _selectedCategory,
          'description': _descCtrl.text.trim(),
          'imageUrl': imageUrl,
          'isAvailable': true,
          'averageRating': 0.0,
          'reviewCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      ).timeout(const Duration(seconds: 25));
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await SupabaseFoodService.saveFoodImageUrl(
          foodId: id,
          imageUrl: imageUrl,
          vendorId: vendorId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food item added!')),
        );
        context.pop();
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save timed out. Check internet/Firebase config and try again.'),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final message = e.code == 'permission-denied'
            ? 'Permission denied while saving product. Check Firestore rules for /foods.'
            : 'Error: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Menu Item'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_rounded),
                        title: const Text('Take Photo'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_rounded),
                        title: const Text('Choose from Gallery'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: kIsWeb
                            ? Image.network(
                                _imageFile!.path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Image.file(
                                File(_imageFile!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Food Name',
              controller: _nameCtrl,
              validator: (v) => Validators.required(v, 'Food name'),
              prefixIcon: const Icon(Icons.fastfood_outlined),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Price (GHS)',
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.price,
              prefixIcon: const Icon(Icons.attach_money_rounded),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('cat_$_selectedCategory'),
                    value: categories.any((c) => c.name == _selectedCategory)
                        ? _selectedCategory
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.name,
                            child: Text('${c.emoji} ${c.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    validator: (v) => v == null ? 'Please select a category' : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: IconButton.filledTonal(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add New Category',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Description',
              controller: _descCtrl,
              maxLines: 3,
              validator: (v) => Validators.required(v, 'Description'),
              prefixIcon: const Icon(Icons.description_outlined),
            ),
            const SizedBox(height: 32),
            AppButton(label: 'Add to Menu', onPressed: _save, loading: _saving),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
