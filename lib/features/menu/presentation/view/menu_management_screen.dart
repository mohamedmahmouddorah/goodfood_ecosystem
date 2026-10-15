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
  const MenuManagementScreen({super.key, required this.repository});

  final MenuRepository repository;

  @override
  Widget build(BuildContext context) {
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
            'Menu Management',
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
            if (state.visible.isEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  CategoryChips(
                    selected: state.category,
                    onSelected: context
                        .read<MenuManagementCubit>()
                        .selectCategory,
                  ),
                  const Expanded(
                    child: _ManagementMessage(
                      icon: Icons.restaurant_menu,
                      message: 'No meals in this category yet.',
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                const SizedBox(height: 12),
                CategoryChips(
                  selected: state.category,
                  onSelected: context
                      .read<MenuManagementCubit>()
                      .selectCategory,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: state.visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
        bottomNavigationBar: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: MenuPalette.goldGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text(
                        'Add Meal',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mealTile(BuildContext context, MealModel meal) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(context, meal),
      child: AdminMealTile(
        meal: meal,
        onTap: () => _openEditor(context, meal),
        onToggle: (value) =>
            context.read<MenuManagementCubit>().toggle(meal.id, value),
      ),
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
