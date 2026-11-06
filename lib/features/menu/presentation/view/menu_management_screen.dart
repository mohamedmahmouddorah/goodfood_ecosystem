import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/meal_model.dart';
import '../../data/repositories/menu_repository.dart';
import '../view_model/menu_management_cubit.dart';
import '../view_model/menu_management_state.dart';
import '../widgets/admin_meal_tile.dart';
import '../widgets/category_chips.dart';
import '../widgets/menu_message.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        final veryNarrow = constraints.maxWidth < 220;
        final horizontalPadding = veryNarrow ? 10.0 : 16.0;

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
              title: Text(
                veryNarrow ? 'Products' : 'Customer Menu Products',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _addProductButton(context),
                  )
                else if (veryNarrow)
                  IconButton(
                    tooltip: 'Add product',
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            body: BlocBuilder<MenuManagementCubit, MenuManagementState>(
              builder: (context, state) {
                if (state.status == ManagementStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: MenuPalette.gold),
                  );
                }
                if (state.status == ManagementStatus.failure) {
                  return MenuMessage(
                    icon: Icons.wifi_off_outlined,
                    message: state.loadError ?? 'Could not load meals.',
                    actionLabel: 'Try again',
                    onAction: context.read<MenuManagementCubit>().watch,
                  );
                }
                return Column(
                  children: [
                    if (compact && !veryNarrow) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: _addProductButton(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else
                      const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 728),
                        child: TextField(
                          key: const ValueKey('admin-product-search'),
                          onChanged: context.read<MenuManagementCubit>().search,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: veryNarrow
                                ? 'Search...'
                                : 'Search products...',
                            hintStyle: const TextStyle(
                              color: MenuPalette.muted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: MenuPalette.muted,
                            ),
                            prefixIconConstraints: veryNarrow
                                ? const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 48,
                                  )
                                : null,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
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
                          ? MenuMessage(
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
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontalPadding,
                                    0,
                                    horizontalPadding,
                                    12,
                                  ),
                                  itemCount: state.visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) => _mealTile(
                                    context,
                                    state.visible[index],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _addProductButton(BuildContext context) => AppButton(
    onPressed: () => _openEditor(context),
    icon: Icons.add,
    foregroundColor: Colors.black,
    backgroundColor: MenuPalette.gold,
    minimumHeight: 44,
    child: const Text(
      'Add product',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );

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
    final chips = [
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < chips.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    chips[index],
                  ],
                ],
              ),
            ),
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: chips,
        );
      },
    );
  }
}
