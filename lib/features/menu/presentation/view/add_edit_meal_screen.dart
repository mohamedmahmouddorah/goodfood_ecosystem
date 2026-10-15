import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/meal_model.dart';
import '../view_model/menu_management_cubit.dart';
import '../widgets/meal_image.dart';
import '../widgets/menu_palette.dart';

class AddEditMealScreen extends StatefulWidget {
  const AddEditMealScreen({super.key, this.meal});

  final MealModel? meal;

  @override
  State<AddEditMealScreen> createState() => _AddEditMealScreenState();
}

class _AddEditMealScreenState extends State<AddEditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;

  late MealCategory _category;
  late bool _isAvailable;
  bool _isSaving = false;

  bool get _isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _nameController = TextEditingController(text: meal?.name ?? '');
    _descriptionController = TextEditingController(
      text: meal?.description ?? '',
    );
    _priceController = TextEditingController(
      text: meal == null ? '' : meal.price.toStringAsFixed(2),
    );
    _imageUrlController = TextEditingController(text: meal?.imageUrl ?? '');
    _category = meal?.category ?? MealCategory.mainCourse;
    _isAvailable = meal?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MenuPalette.bg,
      appBar: AppBar(
        backgroundColor: MenuPalette.bg,
        foregroundColor: Colors.white,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_isEditing ? 'Edit Meal' : 'Add New Meal'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 260;
            final horizontalPadding = constraints.maxWidth < 260
                ? 8.0
                : constraints.maxWidth < 400
                ? 12.0
                : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      24,
                    ),
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _viewProducts,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text('View added products'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MenuPalette.gold,
                          side: const BorderSide(color: MenuPalette.goldDark),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _imageUrlCard(compact: compact),
                      const SizedBox(height: 14),
                      _fieldLabel('Meal Name'),
                      TextFormField(
                        key: const ValueKey('meal-name'),
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: _inputTextStyle,
                        decoration: _decoration(
                          hint: 'e.g. Grilled Chicken',
                          compact: compact,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a meal name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Category'),
                      DropdownButtonFormField<MealCategory>(
                        initialValue: _category,
                        isExpanded: true,
                        dropdownColor: MenuPalette.surface,
                        style: _inputTextStyle,
                        decoration: _decoration(compact: compact),
                        iconEnabledColor: MenuPalette.muted,
                        items: MealCategory.values
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (category) {
                          if (category != null) {
                            setState(() => _category = category);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Description'),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: _inputTextStyle,
                        decoration: _decoration(
                          hint: 'Enter meal description...',
                          compact: compact,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Price'),
                      TextFormField(
                        key: const ValueKey('meal-price'),
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: _inputTextStyle,
                        decoration: _decoration(hint: '0.00', compact: compact),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          if (price == null || !price.isFinite || price < 0) {
                            return 'Enter a valid price.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _availabilitySelector(),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final buttons = [
                            OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MenuPalette.gold,
                                side: const BorderSide(
                                  color: MenuPalette.goldDark,
                                ),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Cancel'),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: MenuPalette.goldGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: FilledButton(
                                onPressed: _isSaving ? null : _save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.transparent,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _isEditing
                                              ? 'Save Changes'
                                              : 'Save Meal',
                                        ),
                                      ),
                              ),
                            ),
                          ];
                          if (constraints.maxWidth < 360) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buttons[1],
                                const SizedBox(height: 8),
                                buttons[0],
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 12),
                              Expanded(child: buttons[1]),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _imageUrlCard({required bool compact}) {
    return Material(
      color: MenuPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MenuPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('meal-image-url'),
              controller: _imageUrlController,
              keyboardType: TextInputType.url,
              style: _inputTextStyle,
              decoration:
                  _decoration(
                    hint: 'https://example.com/meal.jpg',
                    compact: compact,
                  ).copyWith(
                    prefixIcon: compact
                        ? null
                        : const Icon(Icons.link, color: MenuPalette.muted),
                    suffixIcon: IconButton(
                      tooltip: 'Clear image URL',
                      onPressed: () => setState(_imageUrlController.clear),
                      icon: const Icon(Icons.close, color: MenuPalette.muted),
                    ),
                  ),
              validator: _validateImageUrl,
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _imageUrlController,
              builder: (context, value, _) {
                final imageUrl = value.text.trim();
                return SizedBox(
                  height: 104,
                  child: imageUrl.isEmpty
                      ? const Center(
                          child: Text(
                            'Image preview will appear here',
                            style: TextStyle(color: MenuPalette.muted),
                          ),
                        )
                      : MealImage(
                          key: const ValueKey('meal-image-preview'),
                          url: imageUrl,
                          cacheWidth: 600,
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _validateImageUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid image URL starting with http:// or https://.';
    }
    return null;
  }

  Widget _availabilitySelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final options = [
          _availabilityOption(label: 'Visible', value: true),
          _availabilityOption(label: 'Hidden', value: false),
        ];
        if (constraints.maxWidth < 340) {
          return Column(
            children: [options[0], const SizedBox(height: 8), options[1]],
          );
        }
        return Row(
          children: [
            Expanded(child: options[0]),
            const SizedBox(width: 8),
            Expanded(child: options[1]),
          ],
        );
      },
    );
  }

  Widget _availabilityOption({required String label, required bool value}) {
    final selected = _isAvailable == value;
    return Material(
      color: MenuPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _isAvailable = value),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? MenuPalette.goldDark : MenuPalette.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? MenuPalette.success : MenuPalette.muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MenuPalette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 5),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );

  static const _inputTextStyle = TextStyle(color: Colors.white);

  InputDecoration _decoration({String? hint, bool compact = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: MenuPalette.muted),
        filled: true,
        fillColor: MenuPalette.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MenuPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MenuPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MenuPalette.gold),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      );

  bool get _hasUnsavedChanges {
    final meal = widget.meal;
    if (meal == null) {
      return _nameController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _priceController.text.trim().isNotEmpty ||
          _imageUrlController.text.trim().isNotEmpty ||
          _category != MealCategory.mainCourse ||
          !_isAvailable;
    }
    return _nameController.text.trim() != meal.name ||
        _descriptionController.text.trim() != meal.description ||
        _priceController.text.trim() != meal.price.toStringAsFixed(2) ||
        _imageUrlController.text.trim() != meal.imageUrl ||
        _category != meal.category ||
        _isAvailable != meal.isAvailable;
  }

  Future<void> _viewProducts() async {
    if (_hasUnsavedChanges) {
      final discardChanges = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: MenuPalette.surface,
          title: const Text(
            'Discard unsaved changes?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Your changes will be lost when you return to the product list.',
            style: TextStyle(color: MenuPalette.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay here'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard and view products'),
            ),
          ],
        ),
      );
      if (discardChanges != true || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.meal;
    final menuManagementCubit = context.read<MenuManagementCubit>();
    setState(() => _isSaving = true);

    try {
      final meal = MealModel(
        id: previous?.id ?? '',
        name: _nameController.text.trim(),
        category: _category,
        price: double.parse(_priceController.text.trim()),
        imageUrl: _imageUrlController.text.trim(),
        description: _descriptionController.text.trim(),
        isAvailable: _isAvailable,
      );

      final saveResult = await menuManagementCubit.save(meal);
      if (saveResult == MealSaveResult.saved && mounted) {
        Navigator.of(context).pop();
      }
    } catch (error, stackTrace) {
      debugPrint('Meal save failed: $error\n$stackTrace');
      if (mounted) {
        showAppSnackBar(
          context,
          message:
              'Could not save the meal. Check Firebase setup and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
