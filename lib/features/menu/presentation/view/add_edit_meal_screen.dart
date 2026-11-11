import 'dart:async';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/services/meal_image_storage_service.dart';
import '../view_model/menu_management_cubit.dart';
import '../view_model/menu_management_state.dart';
import '../widgets/meal_image.dart';
import '../widgets/menu_palette.dart';
import 'menu_management_screen.dart';

enum _MealImageSource { camera, device }

class AddEditMealScreen extends StatefulWidget {
  const AddEditMealScreen({super.key, this.meal});

  final MealModel? meal;

  @override
  State<AddEditMealScreen> createState() => _AddEditMealScreenState();
}

class _AddEditMealScreenState extends State<AddEditMealScreen> {
  static const _minMealNameLength = 3;
  static const _maxMealNameLength = 60;
  static const _maxDescriptionLength = 500;
  static const _maxImageUrlLength = 2048;
  static const _maxPrice = 99999.99;
  static final _pricePattern = RegExp(r'^\d{0,5}(?:\.\d{0,2})?$');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;

  late MealCategory _category;
  late bool _isAvailable;
  String? _localImagePath;
  String? _localImageName;
  bool _hasManualImageUrlEdit = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

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
    _localImagePath = meal?.localImagePath;
    _localImageName = meal?.localImageName;
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
    try {
      context.read<MenuManagementCubit>();
    } catch (_) {
      return _buildScaffold();
    }
    return BlocListener<MenuManagementCubit, MenuManagementState>(
      listenWhen: (previous, current) => previous.meals != current.meals,
      listener: (context, state) {
        final meal = widget.meal;
        if (meal == null) return;
        for (final updatedMeal in state.meals) {
          if (updatedMeal.id == meal.id &&
              updatedMeal.localImagePath == null &&
              updatedMeal.imageUrl != _imageUrlController.text &&
              !_hasManualImageUrlEdit) {
            _imageUrlController.text = updatedMeal.imageUrl;
            _hasManualImageUrlEdit = false;
            setState(() {
              _localImagePath = null;
              _localImageName = null;
            });
            return;
          }
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
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
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      24,
                    ),
                    children: [
                      AppButton(
                        onPressed: _isSaving ? null : _viewProducts,
                        icon: Icons.inventory_2_outlined,
                        variant: AppButtonVariant.outlined,
                        foregroundColor: MenuPalette.gold,
                        borderColor: MenuPalette.goldDark,
                        minimumHeight: 46,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('View saved products'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _imageUrlCard(compact: compact),
                      const SizedBox(height: 14),
                      _fieldLabel('Meal Name'),
                      TextFormField(
                        key: const ValueKey('meal-name'),
                        controller: _nameController,
                        maxLength: _maxMealNameLength,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(_maxMealNameLength),
                        ],
                        textCapitalization: TextCapitalization.words,
                        style: _inputTextStyle,
                        decoration: _decoration(
                          hint: 'e.g. Grilled Chicken',
                          compact: compact,
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.length < _minMealNameLength) {
                            return 'Meal name must be at least 3 characters.';
                          }
                          if (name.length > _maxMealNameLength) {
                            return 'Meal name must be 60 characters or fewer.';
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
                        key: const ValueKey('meal-description'),
                        controller: _descriptionController,
                        maxLength: _maxDescriptionLength,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            _maxDescriptionLength,
                          ),
                        ],
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: _inputTextStyle,
                        decoration: _decoration(
                          hint: 'Enter meal description...',
                          compact: compact,
                        ),
                        validator: (value) {
                          if ((value?.length ?? 0) > _maxDescriptionLength) {
                            return 'Description must be 500 characters or fewer.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Price'),
                      TextFormField(
                        key: const ValueKey('meal-price'),
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return _pricePattern.hasMatch(newValue.text)
                                ? newValue
                                : oldValue;
                          }),
                        ],
                        style: _inputTextStyle,
                        decoration: _decoration(hint: '0.00', compact: compact),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final price = double.tryParse(
                            text.startsWith('.') ? '0$text' : text,
                          );
                          if (price == null || !price.isFinite || price < 0) {
                            return 'Enter a valid price.';
                          }
                          if (price > _maxPrice ||
                              !_pricePattern.hasMatch(text)) {
                            return 'Price must be at most 99,999.99.';
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
                            AppButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              variant: AppButtonVariant.outlined,
                              foregroundColor: MenuPalette.gold,
                              borderColor: MenuPalette.goldDark,
                              minimumHeight: 48,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Cancel'),
                              ),
                            ),
                            AppButton(
                              onPressed: _isSaving || _isUploadingImage
                                  ? null
                                  : _save,
                              foregroundColor: Colors.black,
                              backgroundColor: MenuPalette.gold,
                              minimumHeight: 48,
                              isLoading: _isSaving,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isEditing ? 'Save Changes' : 'Save Meal',
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
              maxLength: _maxImageUrlLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxImageUrlLength),
              ],
              keyboardType: TextInputType.url,
              style: _inputTextStyle,
              onChanged: (value) {
                _hasManualImageUrlEdit = true;
                if (_localImagePath != null &&
                    value.trim() != (widget.meal?.imageUrl ?? '')) {
                  setState(() {
                    _localImagePath = null;
                    _localImageName = null;
                  });
                }
              },
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
            SizedBox(height: compact ? 4 : 10),
            AppButton(
              onPressed: _isSaving || _isUploadingImage
                  ? null
                  : _pickAndUploadImage,
              icon: Icons.add_photo_alternate_outlined,
              variant: AppButtonVariant.outlined,
              foregroundColor: MenuPalette.gold,
              borderColor: MenuPalette.goldDark,
              minimumHeight: compact ? 32 : 44,
              isLoading: _isUploadingImage,
              tooltip: compact ? 'Choose image' : null,
              child: compact
                  ? const SizedBox.shrink()
                  : Text(
                      _isUploadingImage
                          ? 'Saving image locally...'
                          : 'Choose image',
                    ),
            ),
            SizedBox(height: compact ? 4 : 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _imageUrlController,
              builder: (context, value, _) {
                final imageUrl = value.text.trim();
                final localImagePath = _localImagePath;
                return SizedBox(
                  height: compact ? 64 : 104,
                  child: localImagePath == null && imageUrl.isEmpty
                      ? const Center(
                          child: Text(
                            'Image preview will appear here',
                            style: TextStyle(color: MenuPalette.muted),
                          ),
                        )
                      : MealImage(
                          key: const ValueKey('meal-image-preview'),
                          url: imageUrl,
                          localPath: localImagePath,
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
    if (text.length > _maxImageUrlLength) {
      return 'Image URL must be 2,048 characters or fewer.';
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid image URL starting with http:// or https://.';
    }
    return null;
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<_MealImageSource>(
      context: context,
      backgroundColor: MenuPalette.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_supportsCamera)
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: MenuPalette.gold,
                ),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, _MealImageSource.camera),
              ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: MenuPalette.gold,
              ),
              title: const Text(
                'Choose from device',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, _MealImageSource.device),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;

    setState(() => _isUploadingImage = true);
    try {
      late final PickedMealImage image;
      if (source == _MealImageSource.camera) {
        if (defaultTargetPlatform == TargetPlatform.windows && !kIsWeb) {
          final capturedImage = await Navigator.of(context)
              .push<PickedMealImage>(
                MaterialPageRoute(
                  builder: (_) =>
                      _WindowsCameraScreen(onPickFromDevice: _pickDeviceImage),
                ),
              );
          if (!mounted || capturedImage == null) return;
          image = capturedImage;
        } else {
          final photo = await ImagePicker().pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          if (!mounted || photo == null) return;
          final extension = _imageExtension(photo.name);
          final bytes = await photo.readAsBytes();
          if (!mounted) return;
          if (extension == null || bytes.isEmpty) {
            showAppSnackBar(
              context,
              message:
                  'The captured image could not be read. Please try again.',
            );
            return;
          }
          image = PickedMealImage(
            bytes: bytes,
            extension: extension,
            fileName: photo.name,
          );
        }
      } else {
        final deviceImage = await _pickDeviceImage();
        if (!mounted || deviceImage == null) return;
        image = deviceImage;
      }

      if (image.bytes.length > ImgBbMealImageStorageService.maxImageSize) {
        showAppSnackBar(context, message: 'Choose an image smaller than 5 MB.');
        return;
      }
      if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(image.extension)) {
        showAppSnackBar(
          context,
          message: 'The selected image could not be read. Please try again.',
        );
        return;
      }

      final cubit = context.read<MenuManagementCubit>();
      final localImagePath = await cubit.saveImageLocally(image);
      if (!mounted) return;
      setState(() {
        _localImagePath = localImagePath;
        _localImageName = image.fileName;
      });
      _hasManualImageUrlEdit = false;

      final meal = widget.meal;
      if (meal == null) {
        showAppSnackBar(
          context,
          message: 'Image selected. Save the meal to upload it.',
        );
        return;
      }

      final result = await cubit.stageMealImage(
        meal.id,
        localImagePath,
        fileName: image.fileName ?? 'meal.${image.extension}',
        meal: meal,
      );
      if (!mounted || result == MealSaveResult.failed) return;
      showAppSnackBar(
        context,
        message: result == MealSaveResult.saved
            ? 'Image uploaded and product updated successfully.'
            : cubit.syncErrorMessage ??
                  'Image saved on this device. It will upload when internet is available.',
      );
    } catch (error, stackTrace) {
      debugPrint('Meal image staging failed: $error\n$stackTrace');
      if (mounted) {
        showAppSnackBar(
          context,
          message: error is StateError || error is MenuFailure
              ? error.toString()
              : source == _MealImageSource.camera
              ? 'Could not capture the image. Check camera permission and try again.'
              : 'Could not save the image. Check device storage and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
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

  void _viewProducts() {
    final cubit = context.read<MenuManagementCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MenuManagementScreen(
          repository: cubit.repository,
          existingCubit: cubit,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isUploadingImage) return;
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
        localImagePath: _localImagePath,
        localImageName: _localImageName,
      );

      final saveResult = await menuManagementCubit.save(meal);
      if (saveResult != MealSaveResult.failed && mounted) {
        if (previous == null && saveResult == MealSaveResult.saved) {
          showAppSnackBar(context, message: 'Meal added successfully.');
        } else if (saveResult == MealSaveResult.pending) {
          showAppSnackBar(
            context,
            message:
                menuManagementCubit.syncErrorMessage ??
                'Saved on this device. It will sync when internet is available.',
          );
        }
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

  bool get _supportsCamera =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  Future<PickedMealImage?> _pickDeviceImage() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || file == null) return null;

    final size = await file.length();
    if (!mounted) return null;
    if (size == null || size == 0) {
      showAppSnackBar(
        context,
        message: 'The selected image could not be read. Please try again.',
      );
      return null;
    }
    if (size > ImgBbMealImageStorageService.maxImageSize) {
      showAppSnackBar(context, message: 'Choose an image smaller than 5 MB.');
      return null;
    }
    final extension = file.extension?.toLowerCase();
    final bytes = await file.readAsBytes();
    if (!mounted) return null;
    if (extension == null || bytes.isEmpty) {
      showAppSnackBar(
        context,
        message: 'The selected image could not be read. Please try again.',
      );
      return null;
    }
    return PickedMealImage(
      bytes: bytes,
      extension: extension,
      fileName: file.name,
    );
  }

  String? _imageExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1).toLowerCase();
  }
}

class _WindowsCameraScreen extends StatefulWidget {
  const _WindowsCameraScreen({required this.onPickFromDevice});

  final Future<PickedMealImage?> Function() onPickFromDevice;

  @override
  State<_WindowsCameraScreen> createState() => _WindowsCameraScreenState();
}

class _WindowsCameraScreenState extends State<_WindowsCameraScreen> {
  CameraController? _controller;
  String? _errorMessage;
  bool _cameraPermissionDenied = false;
  bool _isOpeningSettings = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    if (_controller != null) {
      final oldController = _controller;
      _controller = null;
      await oldController?.dispose();
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showCameraError('No camera was found on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } on CameraException catch (error) {
      _showCameraError(
        error.description ?? error.code,
        permissionDenied: _isCameraPermissionError(error),
      );
    } on Exception catch (error) {
      _showCameraError(error.toString());
    }
  }

  bool _isCameraPermissionError(CameraException error) =>
      error.code.toLowerCase() == 'cameraaccessdenied';

  void _showCameraError(String message, {bool permissionDenied = false}) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _cameraPermissionDenied = permissionDenied;
    });
  }

  Future<void> _openCameraSettings() async {
    if (_isOpeningSettings) return;
    setState(() => _isOpeningSettings = true);
    try {
      final opened = await launchUrl(
        Uri.parse('ms-settings:privacy-webcam'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showAppSnackBar(
          context,
          message:
              'Could not open Windows settings. Go to Settings > Privacy & security > Camera.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message:
              'Could not open Windows settings. Go to Settings > Privacy & security > Camera.',
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningSettings = false);
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPhoto) {
      return;
    }
    setState(() => _isTakingPhoto = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _showCameraError('The captured image could not be read.');
        return;
      }
      Navigator.of(context).pop(
        PickedMealImage(bytes: bytes, extension: 'jpg', fileName: photo.name),
      );
    } on CameraException catch (error) {
      _showCameraError(
        error.description ?? error.code,
        permissionDenied: _isCameraPermissionError(error),
      );
    } on Exception catch (error) {
      _showCameraError(error.toString());
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _chooseFromDevice() async {
    try {
      final image = await widget.onPickFromDevice();
      if (mounted && image != null) Navigator.of(context).pop(image);
    } on Exception catch (error) {
      _showCameraError(error.toString());
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take a photo'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // On narrow desktop windows, stack the controls instead of
            // forcing both buttons into a Row.
            final isCompact = constraints.maxWidth < 320;

            return Column(
              children: [
                // The preview receives only the space left after the controls.
                // This prevents the camera preview from pushing the controls
                // outside the available height.
                Expanded(
                  child: Center(
                    child: _errorMessage != null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _cameraPermissionDenied
                                      ? 'Camera permission is disabled. Allow camera access for desktop apps in Windows settings.'
                                      : 'Camera unavailable:\n$_errorMessage',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_cameraPermissionDenied)
                                  TextButton.icon(
                                    onPressed: _isOpeningSettings
                                        ? null
                                        : _openCameraSettings,
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                    ),
                                    label: const Text(
                                      'Open camera privacy settings',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: _isTakingPhoto
                                        ? null
                                        : _initializeCamera,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry Camera'),
                                  ),
                              ],
                            ),
                          )
                        : isReady && controller != null
                            ? LayoutBuilder(
                                builder: (context, previewConstraints) {
                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: previewConstraints.maxWidth,
                                        maxHeight: previewConstraints.maxHeight,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio:
                                            controller.value.aspectRatio,
                                        child: CameraPreview(controller),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const CircularProgressIndicator(),
                  ),
                ),

                // Controls stay inside the available width. On very narrow
                // windows they become vertical; otherwise the button label
                // gets flexible space and can ellipsize safely.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: isCompact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton.icon(
                              onPressed: _isTakingPhoto
                                  ? null
                                  : _chooseFromDevice,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                              ),
                              label: const Text(
                                'Choose from device',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: IconButton.filled(
                                onPressed: isReady && !_isTakingPhoto
                                    ? _takePhoto
                                    : null,
                                icon: _isTakingPhoto
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt),
                                iconSize: 26,
                                tooltip: 'Take photo',
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _isTakingPhoto
                                    ? null
                                    : _chooseFromDevice,
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                ),
                                label: const Text(
                                  'Choose from device',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: isReady && !_isTakingPhoto
                                  ? _takePhoto
                                  : null,
                              icon: _isTakingPhoto
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt),
                              iconSize: 26,
                              tooltip: 'Take photo',
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}