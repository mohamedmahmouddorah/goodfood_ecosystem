import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/auth/data/model/user_model.dart';
import '../../data/repositories/chef_repository.dart';
import 'chef_state.dart';

class ChefCubit extends Cubit<ChefState> {
  final ChefRepository _repository;
  StreamSubscription<List<UserModel>>? _chefsSubscription;
  final TextEditingController searchController = TextEditingController();

  ChefCubit({ChefRepository? repository})
      : _repository = repository ?? ChefRepositoryImpl(),
        super(const ChefState()) {
    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (searchController.text != state.searchQuery) {
      emit(state.copyWith(searchQuery: searchController.text));
    }
  }

  void subscribeToChefs() {
    emit(state.copyWith(status: ChefStatus.loading));
    _chefsSubscription?.cancel();
    _chefsSubscription = _repository.getChefsStream().listen(
      (chefs) {
        emit(state.copyWith(
          allChefs: chefs,
          status: ChefStatus.success,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          status: ChefStatus.error,
          errorMessage: error.toString(),
        ));
      },
    );
  }

  void setSearchQuery(String query) {
    if (searchController.text != query) {
      searchController.text = query;
    }
    emit(state.copyWith(searchQuery: query));
  }

  void clearSearch() {
    searchController.clear();
    emit(state.copyWith(searchQuery: ''));
  }

  void setFilter(String filter) {
    emit(state.copyWith(selectedFilter: filter));
  }

  Future<void> addChef(UserModel chef) async {
    try {
      await _repository.addChef(chef);
      emit(state.copyWith(
        successMessage: 'Chef "${chef.name}" saved to Firebase',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to add chef: $e',
      ));
    }
  }

  Future<void> updateChef(UserModel updatedChef) async {
    try {
      await _repository.updateChef(updatedChef);
      emit(state.copyWith(
        successMessage: 'Updated "${updatedChef.name}" in Firebase',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to update chef: $e',
      ));
    }
  }

  Future<void> toggleStatus(UserModel chef) async {
    final newStatus =
        chef.status == AccountStatus.Active ? AccountStatus.Inactive : AccountStatus.Active;
    final uid = chef.uid;
    if (uid == null) return;

    try {
      await _repository.toggleStatus(uid, newStatus);
      emit(state.copyWith(
        successMessage: '${chef.name} is now ${newStatus.name}',
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to update status: $e',
      ));
    }
  }

  Future<void> deleteChef(UserModel chef) async {
    final uid = chef.uid;
    if (uid == null) return;

    try {
      await _repository.deleteChef(uid);
      emit(state.copyWith(
        successMessage: 'Removed "${chef.name}"',
        lastDeletedChef: chef,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to delete chef: $e',
      ));
    }
  }

  Future<void> undoDelete() async {
    final chef = state.lastDeletedChef;
    if (chef != null) {
      await _repository.addChef(chef);
      emit(state.copyWith(
        successMessage: 'Restored "${chef.name}"',
        clearMessages: true,
      ));
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearMessages: true));
  }

  @override
  Future<void> close() {
    _chefsSubscription?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    return super.close();
  }
}
