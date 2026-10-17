import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';

class AddEditChefDialog extends StatefulWidget {
  final UserModel? chefToEdit;
  final ValueChanged<UserModel> onSave;

  const AddEditChefDialog({
    super.key,
    this.chefToEdit,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    UserModel? chefToEdit,
    required ValueChanged<UserModel> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditChefDialog(
        chefToEdit: chefToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditChefDialog> createState() => _AddEditChefDialogState();
}

class _AddEditChefDialogState extends State<AddEditChefDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.chefToEdit?.name ?? '');
    _emailController =
        TextEditingController(text: widget.chefToEdit?.email ?? '');
    _phoneController =
        TextEditingController(text: widget.chefToEdit?.phone ?? '');
    _isActive = widget.chefToEdit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedChef = UserModel(
        uid: widget.chefToEdit?.uid ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        role: Role.Chef, // Role is always Chef
        status: _isActive ? AccountStatus.Active : AccountStatus.Inactive,
        imgUrl: null, // No avatar photos
        startDate: widget.chefToEdit?.startDate ?? DateTime.now(),
      );

      widget.onSave(updatedChef);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.chefToEdit != null;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF2B2F3D), width: 1),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Chef' : 'Add New Chef',
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Chef Name
              const Text(
                'Full Name',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'e.g. Ahmed Hassan',
                  icon: Icons.person_outline,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter chef name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Chef Email
              const Text(
                'Email Address',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'e.g. ahmed.hassan@restaurant.com',
                  icon: Icons.mail_outline,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Chef Phone
              const Text(
                'Phone Number',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'e.g. +20 100 123 4567',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 18),

              // Status Switch
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isActive
                                ? AppColors.activeGreen
                                : AppColors.inactiveRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isActive ? 'Active Chef' : 'Inactive Chef',
                          style: TextStyle(
                            color: _isActive
                                ? AppColors.activeGreen
                                : AppColors.inactiveRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isActive,
                      activeTrackColor: AppColors.activeGreenBg,
                      activeThumbColor: AppColors.activeGreen,
                      inactiveThumbColor: AppColors.inactiveRed,
                      inactiveTrackColor: AppColors.inactiveRedBg,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.addChefText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Chef',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.inputBackground,
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.primaryGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.inactiveRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.inactiveRed, width: 1.5),
      ),
    );
  }
}
