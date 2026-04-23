import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../features/buyer/providers/home_provider.dart';
import '../../../models/food_model.dart';
import '../../../core/services/write_log_service.dart';

class EditFoodScreen extends ConsumerStatefulWidget {
  final String foodId;
  const EditFoodScreen({super.key, required this.foodId});

  @override
  ConsumerState<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends ConsumerState<EditFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCategory;
  XFile? _newImageFile;
  String? _existingImageUrl;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadFood();
  }

  Future<void> _loadFood() async {
    final doc = await FirebaseFirestore.instance
        .collection('foods')
        .doc(widget.foodId)
        .get();
    if (!doc.exists || !mounted) return;

    final food = FoodModel.fromMap(doc.id, doc.data()!);
    setState(() {
      _nameCtrl.text = food.name;
      _priceCtrl.text = food.price.toString();
      _descCtrl.text = food.description;
      _selectedCategory = food.category;
      _existingImageUrl = food.imageUrl;
      _loaded = true;
    });
  }

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
      setState(() => _newImageFile = file);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      return;
    }
    if (_selectedCategory == null) return;
    setState(() => _saving = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_newImageFile != null) {
        try {
          final ref = FirebaseStorage.instance.ref('foods/${widget.foodId}.jpg');
          final bytes = await _newImageFile!.readAsBytes();

          await WriteLogService.capture(
            action: 'Upload food image',
            target: 'storage/foods/${widget.foodId}.jpg',
            task: () => ref.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            ),
          ).timeout(const Duration(seconds: 25));
          imageUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 20));
        } on TimeoutException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image upload timed out. Saving changes without new image.'),
              ),
            );
          }
        } on FirebaseException catch (e) {
          if (mounted) {
            final message = e.code == 'permission-denied'
                ? 'Image upload blocked by Storage rules. Saving changes without new image.'
                : 'Image upload failed (${e.code}). Saving changes without new image.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          }
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
        action: 'Update food item',
        target: 'foods/${widget.foodId}',
        task: () => FirebaseFirestore.instance.collection('foods').doc(widget.foodId).update({
          'name': _nameCtrl.text.trim(),
          'price': price,
          'category': _selectedCategory,
          'description': _descCtrl.text.trim(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        }),
      ).timeout(const Duration(seconds: 25));

      if (mounted) context.pop();
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
            ? 'Permission denied while saving changes. Check Firestore rules for /foods.'
            : 'Error: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget imageWidget;
    if (_newImageFile != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb
            ? Image.network(
                _newImageFile!.path,
                fit: BoxFit.cover,
                width: double.infinity,
              )
            : Image.file(
                File(_newImageFile!.path),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
      );
    } else if (_existingImageUrl != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _existingImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else {
      imageWidget = const Center(
        child: Icon(
          Icons.add_photo_alternate_rounded,
          size: 48,
          color: Colors.grey,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item'), centerTitle: true),
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
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Food Name',
              controller: _nameCtrl,
              validator: (v) => Validators.required(v, 'Food name'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Price (GHS)',
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.price,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCategory),
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
            ),
            const SizedBox(height: 32),
            AppButton(label: 'Save Changes', onPressed: _save, loading: _saving),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
