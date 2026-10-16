import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../view_model/menu_management_cubit.dart';
import '../view_model/menu_management_state.dart';
import '../widgets/admin_meal_tile.dart';
import '../widgets/category_chips.dart';
import '../widgets/menu_palette.dart';
import 'add_edit_meal_screen.dart';

class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({
    super.key,
    required this.repository,
    this.existingCubit,
  });

  final MenuRepository repository;
  final MenuManagementCubit? existingCubit;

  @override
  Widget build(BuildContext context) {
    final cubit = existingCubit;
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit,
        child: const _MenuManagementView(),
      );
    }
    return BlocProvider(
      create: (_) => MenuManagementCubit(repository)..watch(),
      child: const _MenuManagementView(),
    );
  }
}

class _MenuManagementView extends StatelessWidget {
  const _MenuManagementView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<MenuManagementCubit, MenuManagementState>(
      listenWhen: (previous, current) => current.message != null,
      listener: (context, state) {
        showAppSnackBar(context, message: state.message!);
      },
      child: Scaffold(
        backgroundColor: MenuPalette.bg,
        appBar: AppBar(
          backgroundColor: MenuPalette.bg,
          foregroundColor: Colors.white,
          title: const Text(
            'Customer Menu Products',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: BlocBuilder<MenuManagementCubit, MenuManagementState>(
          builder: (context, state) {
            if (state.status == ManagementStatus.loading) {
              return const Center(
                child: CircularProgressIndicator(color: MenuPalette.gold),
              );
            }
            if (state.status == ManagementStatus.failure) {
              return _ManagementMessage(
                icon: Icons.wifi_off_outlined,
                message: state.loadError ?? 'Could not load meals.',
                actionLabel: 'Try again',
                onAction: context.read<MenuManagementCubit>().watch,
              );
            }
            return Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 728),
                    child: TextField(
                      key: const ValueKey('admin-product-search'),
                      onChanged: context.read<MenuManagementCubit>().search,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: const TextStyle(color: MenuPalette.muted),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: MenuPalette.muted,
                        ),
                        filled: true,
                        fillColor: MenuPalette.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: MenuPalette.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: MenuPalette.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 728),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _VisibilityFilters(
                        selected: state.visibilityFilter,
                        onSelected: context
                            .read<MenuManagementCubit>()
                            .selectVisibilityFilter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                CategoryChips(
                  selected: state.category,
                  onSelected: context
                      .read<MenuManagementCubit>()
                      .selectCategory,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: state.visible.isEmpty
                      ? _ManagementMessage(
                          icon: Icons.restaurant_menu,
                          message:
                              state.searchQuery.trim().isNotEmpty ||
                                  state.visibilityFilter !=
                                      MealVisibilityFilter.all ||
                                  state.category != null
                              ? 'No products match these filters.'
                              : 'No products yet. Connect to Firebase to refresh, or add a product below.',
                          actionLabel: state.meals.isEmpty ? 'Refresh' : null,
                          onAction: state.meals.isEmpty
                              ? context.read<MenuManagementCubit>().watch
                              : null,
                        )
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              itemCount: state.visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) =>
                                  _mealTile(context, state.visible[index]),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context),
          backgroundColor: MenuPalette.gold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _mealTile(BuildContext context, MealModel meal) {
    return AdminMealTile(
      meal: meal,
      onTap: () => _openEditor(context, meal),
      onToggle: (value) =>
          context.read<MenuManagementCubit>().toggle(meal.id, value),
      onDelete: () => _confirmDelete(context, meal),
    );
  }

  void _openEditor(BuildContext context, [MealModel? meal]) {
    final cubit = context.read<MenuManagementCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: AddEditMealScreen(meal: meal),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MealModel meal) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MenuPalette.surface,
        title: const Text(
          'Delete meal?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently remove ${meal.name}.',
          style: const TextStyle(color: MenuPalette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await context.read<MenuManagementCubit>().delete(meal.id);
    }
  }
}

class _VisibilityFilters extends StatelessWidget {
  const _VisibilityFilters({required this.selected, required this.onSelected});

  final MealVisibilityFilter selected;
  final ValueChanged<MealVisibilityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = [
      (MealVisibilityFilter.all, 'All products'),
      (MealVisibilityFilter.visible, 'Visible'),
      (MealVisibilityFilter.hidden, 'Hidden'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (filter, label) in filters)
          ChoiceChip(
            key: ValueKey('visibility-filter-${filter.name}'),
            label: Text(label),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected == filter ? Colors.black : MenuPalette.muted,
            ),
            selectedColor: MenuPalette.gold,
            backgroundColor: MenuPalette.surface,
            side: BorderSide(
              color: selected == filter ? MenuPalette.gold : MenuPalette.border,
            ),
          ),
      ],
    );
  }
}

class _ManagementMessage extends StatelessWidget {
  const _ManagementMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MenuPalette.muted, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MenuPalette.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: MenuPalette.gold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
