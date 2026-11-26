import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/chef_orders_source.dart';
import '../../data/services/chef_identity_service.dart';
import 'chef_orders_state.dart';

class ChefOrdersCubit extends Cubit<ChefOrdersState> {
  ChefOrdersCubit(this.source) : super(const ChefOrdersState());
  final ChefOrdersSource source;
  StreamSubscription<ChefOrderQueues>? _subscription;
  int _generation = 0;

  void load() {
    if (isClosed) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    emit(ChefOrdersState(section: state.section, noticeId: state.noticeId));
    try {
      _subscription = source.watch().listen(
        (queues) {
          if (isClosed || generation != _generation) return;
          final sameChef = state.queues?.chef.uid == queues.chef.uid;
          emit(
            ChefOrdersState(
              status: ChefOrdersStatus.loaded,
              section: state.section,
              queues: queues,
              busyIds: sameChef ? state.busyIds : const {},
              notice: sameChef ? state.notice : null,
              noticeId: state.noticeId,
            ),
          );
        },
        onError: (Object error, StackTrace stack) {
          if (!isClosed && generation == _generation) {
            emit(
              ChefOrdersState(
                section: state.section,
                status: error is ChefAccessDenied
                    ? ChefOrdersStatus.denied
                    : ChefOrdersStatus.error,
              ),
            );
          }
        },
      );
    } catch (_) {
      emit(
        ChefOrdersState(status: ChefOrdersStatus.error, section: state.section),
      );
    }
  }

  void select(ChefOrdersSection section) => emit(
    ChefOrdersState(
      status: state.status,
      section: section,
      queues: state.queues,
      busyIds: state.busyIds,
      notice: state.notice,
      noticeId: state.noticeId,
    ),
  );

  Future<void> accept(String id) =>
      _run(id, () => source.accept(id), ChefNotice.accepted);
  Future<void> markReady(String id) =>
      _run(id, () => source.markReady(id), ChefNotice.ready);

  Future<void> _run(
    String id,
    Future<void> Function() action,
    ChefNotice success,
  ) async {
    if (isClosed ||
        state.status != ChefOrdersStatus.loaded ||
        state.busyIds.contains(id)) {
      return;
    }
    final generation = _generation;
    final chefId = state.queues?.chef.uid;
    emit(
      ChefOrdersState(
        status: state.status,
        section: state.section,
        queues: state.queues,
        busyIds: Set.unmodifiable({...state.busyIds, id}),
        noticeId: state.noticeId,
      ),
    );
    ChefNotice notice;
    try {
      await action();
      notice = success;
    } on ChefOrderConflict {
      notice = ChefNotice.conflict;
    } catch (_) {
      notice = ChefNotice.error;
    }
    if (isClosed ||
        generation != _generation ||
        state.queues?.chef.uid != chefId) {
      return;
    }
    emit(
      ChefOrdersState(
        status: state.status,
        section: state.section,
        queues: state.queues,
        busyIds: Set.unmodifiable({...state.busyIds}..remove(id)),
        notice: notice,
        noticeId: state.noticeId + 1,
      ),
    );
    if (notice == ChefNotice.conflict) {
      // Reattach to the authoritative queues; never optimistically reassign.
      load();
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    await _subscription?.cancel();
    return super.close();
  }
}
