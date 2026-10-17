import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';

class ChefCard extends StatelessWidget {
  final UserModel chef;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const ChefCard({
    super.key,
    required this.chef,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar with status ring
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF232630),
                  border: Border.all(
                    color: const Color(0xFF2C303E),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _buildAvatar(chef),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: chef.isActive
                        ? AppColors.activeGreen
                        : AppColors.inactiveDot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cardBackground,
                      width: 2.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Chef Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chef.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (chef.role == Role.Admin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  chef.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (chef.phone != null && chef.phone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    chef.phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPlaceholder,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Status Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: chef.isActive
                        ? AppColors.activeGreenBg
                        : AppColors.inactiveRedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: chef.isActive
                          ? AppColors.activeGreenBorder
                          : AppColors.inactiveRedBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: chef.isActive
                              ? AppColors.activeGreen
                              : AppColors.inactiveRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chef.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: chef.isActive
                              ? AppColors.activeGreen
                              : AppColors.inactiveRed,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Edit Pencil & 3-dot Menu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.actionCircle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryGold,
                      size: 18,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF1E212B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggleStatus();
                  } else if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined,
                            color: AppColors.primaryGold, size: 18),
                        SizedBox(width: 10),
                        Text('Edit Chef',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          chef.isActive
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline,
                          color: chef.isActive
                              ? AppColors.inactiveRed
                              : AppColors.activeGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          chef.isActive ? 'Set Inactive' : 'Set Active',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline,
                            color: AppColors.inactiveRed, size: 18),
                        SizedBox(width: 10),
                        Text('Delete Chef',
                            style: TextStyle(
                                color: AppColors.inactiveRed, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel chef) {
    final avatar = chef.imgUrl;
    final hasValidAvatar = avatar != null &&
        avatar.trim().isNotEmpty &&
        avatar.trim().toLowerCase() != 'none';

    if (!hasValidAvatar) {
      return _buildPlaceholder(chef);
    }

    return Image.network(
      avatar,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(chef),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryGold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(UserModel chef) {
    final initial = chef.name.trim().isNotEmpty
        ? chef.name.trim()[0].toUpperCase()
        : '?';

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primaryGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
