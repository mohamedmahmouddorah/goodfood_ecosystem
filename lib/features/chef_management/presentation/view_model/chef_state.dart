import '../../data/models/user_model.dart';

enum ChefStatus { initial, loading, success, error }

class ChefState {
  final List<UserModel> allChefs;
  final String searchQuery;
  final String selectedFilter; // 'All', 'Active', 'Inactive'
  final ChefStatus status;
  final String? errorMessage;
  final String? successMessage;
  final UserModel? lastDeletedChef;

  const ChefState({
    this.allChefs = const [],
    this.searchQuery = '',
    this.selectedFilter = 'All',
    this.status = ChefStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.lastDeletedChef,
  });

  bool get isLoading => status == ChefStatus.loading;

  List<UserModel> get filteredChefs {
    return allChefs.where((chef) {
      if (selectedFilter == 'Active' && !chef.isActive) return false;
      if (selectedFilter == 'Inactive' && chef.isActive) return false;

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final nameMatches = chef.name.toLowerCase().contains(query);
        final emailMatches = chef.email.toLowerCase().contains(query);
        final phoneMatches =
            chef.phone?.toLowerCase().contains(query) ?? false;
        return nameMatches || emailMatches || phoneMatches;
      }

      return true;
    }).toList();
  }

  ChefState copyWith({
    List<UserModel>? allChefs,
    String? searchQuery,
    String? selectedFilter,
    ChefStatus? status,
    String? errorMessage,
    String? successMessage,
    UserModel? lastDeletedChef,
    bool clearMessages = false,
  }) {
    return ChefState(
      allChefs: allChefs ?? this.allChefs,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      status: status ?? this.status,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
      lastDeletedChef:
          clearMessages ? null : (lastDeletedChef ?? this.lastDeletedChef),
    );
  }
}
