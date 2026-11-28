import 'package:goodfood_ecosystem/core/widgets/app_snack_bar.dart';
import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../view_model/chef_cubit.dart';
import '../view_model/chef_state.dart';
import '../widgets/add_edit_chef_dialog.dart';
import '../widgets/chef_card.dart';
import '../widgets/chef_hat_icon.dart';

class ChefManagementScreen extends StatelessWidget {
  const ChefManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChefCubit()..subscribeToChefs(),
      child: const _ChefManagementView(),
    );
  }
}

class _ChefManagementView extends StatelessWidget {
  const _ChefManagementView();

  void _showFilterMenu(BuildContext context, String currentFilter) {
    final cubit = context.read<ChefCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF171922),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF2B2F3D), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              const AppText(
                'Filter Chefs By Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...['All', 'Active', 'Inactive'].map((filter) {
                final isSelected = currentFilter == filter;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    filter == 'Active'
                        ? Icons.check_circle_outline
                        : filter == 'Inactive'
                        ? Icons.cancel_outlined
                        : Icons.people_outline,
                    color: isSelected
                        ? AppColors.primaryGold
                        : AppColors.textMuted,
                  ),
                  title: AppText(
                    filter,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryGold : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primaryGold)
                      : null,
                  onTap: () {
                    cubit.setFilter(filter);
                    Navigator.of(bottomSheetContext).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChefCubit, ChefState>(
      listenWhen: (previous, current) =>
          current.successMessage != null || current.errorMessage != null,
      listener: (context, state) {
        if (state.errorMessage != null) {
          if (ModalRoute.of(context)?.isCurrent == false) return;
          showAppSnackBar(
            context,
            message: state.errorMessage!,
            kind: FeedbackKind.error,
          );
          context.read<ChefCubit>().clearMessages();
        } else if (state.successMessage != null) {
          final isDelete =
              state.lastDeletedChef != null &&
              state.successMessage!.startsWith('Removed');
          showAppSnackBar(
            context,
            message: state.successMessage!,
            kind: FeedbackKind.success,
            duration: const Duration(seconds: 2),
            action: isDelete
                ? SnackBarAction(
                    label: 'UNDO',
                    textColor: AppColors.primaryGold,
                    onPressed: () => context.read<ChefCubit>().undoDelete(),
                  )
                : null,
          );
          context.read<ChefCubit>().clearMessages();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ChefCubit>();
        final chefsToShow = state.filteredChefs;

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: Padding(
            padding: EdgeInsetsDirectional.only(
              end: ((MediaQuery.sizeOf(context).width - 460) / 2).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AddEditChefDialog.show(
                    context,
                    onSave: (newChef, password) =>
                        _saveChef(cubit, () => cubit.addChef(newChef, password: password ?? '')) ,
                  );
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.addChefBtn,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.person_add_alt_outlined,
                        color: AppColors.addChefText,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      AppText(
                        'Add Chef',
                        style: TextStyle(
                          color: AppColors.addChefText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back Arrow Button
                          IconButton(
                            onPressed: Navigator.of(context).canPop()
                                ? () => Navigator.of(context).maybePop()
                                : null,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                            icon: const BackButtonIcon(),
                            color: AppColors.primaryGold,
                          ),
                          const SizedBox(width: 8),

                          // Header Title & Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: context.tr('Chef '),
                                        style: TextStyle(
                                          color: AppColors.textWhite,
                                        ),
                                      ),
                                      TextSpan(
                                        text: context.tr('Management'),
                                        style: TextStyle(
                                          color: AppColors.primaryGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const AppText(
                                  'Manage your kitchen team',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const LanguageToggle(),
                          // Top Right Chef Hat Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: const ChefHatIcon(
                              size: 28,
                              color: AppColors.primaryGold,
                              strokeWidth: 1.9,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar & Filter Dropdown Row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Search Field
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: cubit.searchController,
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: context.tr(
                                    'Search chef by name, email or phone...',
                                  ),
                                  hintStyle: const TextStyle(
                                    color: AppColors.textPlaceholder,
                                    fontSize: 13,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: AppColors.textPlaceholder,
                                    size: 21,
                                  ),
                                  suffixIcon: state.searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: AppColors.textPlaceholder,
                                            size: 18,
                                          ),
                                          onPressed: cubit.clearSearch,
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Filter Dropdown Button
                          GestureDetector(
                            onTap: () =>
                                _showFilterMenu(context, state.selectedFilter),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppText(
                                    state.selectedFilter,
                                    style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Chefs List View
                    Expanded(
                      child: Stack(
                        children: [
                          state.isLoading && state.allChefs.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryGold,
                                  ),
                                )
                              : chefsToShow.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_search_outlined,
                                        color: AppColors.textPlaceholder
                                            .withValues(alpha: 0.5),
                                        size: 64,
                                      ),
                                      const SizedBox(height: 12),
                                      const AppText(
                                        'No chefs found',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AppText(
                                        state.searchQuery.isNotEmpty
                                            ? 'Try adjusting your search criteria'
                                            : 'Tap "Add Chef" to add your first chef',
                                        style: const TextStyle(
                                          color: AppColors.textPlaceholder,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    90,
                                  ),
                                  itemCount: chefsToShow.length,
                                  itemBuilder: (context, index) {
                                    final chef = chefsToShow[index];
                                    return ChefCard(
                                      key: ValueKey(chef.uid ?? index),
                                      chef: chef,
                                      onEdit: () {
                                        AddEditChefDialog.show(
                                          context,
                                          chefToEdit: chef,
                                          onSave: (updated, _) => _saveChef(
                                            cubit,
                                            () => cubit.updateChef(updated),
                                          ),
                                        );
                                      },
                                      onToggleStatus: () =>
                                          cubit.toggleStatus(chef),
                                      onDelete: () => cubit.deleteChef(chef),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _saveChef(
    ChefCubit cubit,
    Future<void> Function() save,
  ) async {
    await save();
    final error = cubit.state.errorMessage;
    if (error != null) cubit.clearMessages();
    return error;
  }
}
