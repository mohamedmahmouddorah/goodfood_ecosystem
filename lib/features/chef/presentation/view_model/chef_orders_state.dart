import '../../data/repositories/chef_orders_source.dart';
import '../../../customer_order_management/data/models/order_model.dart';

enum ChefOrdersSection { incoming, active, ready }

enum ChefOrdersStatus { loading, loaded, error, denied }

enum ChefNotice { accepted, ready, conflict, error }

class ChefOrdersState {
  const ChefOrdersState({
    this.status = ChefOrdersStatus.loading,
    this.section = ChefOrdersSection.incoming,
    this.queues,
    this.busyIds = const {},
    this.notice,
    this.noticeId = 0,
  });

  final ChefOrdersStatus status;
  final ChefOrdersSection section;
  final ChefOrderQueues? queues;
  final Set<String> busyIds;
  final ChefNotice? notice;
  final int noticeId;

  List<OrderModel> get visibleOrders => switch (section) {
    ChefOrdersSection.incoming => queues?.incoming ?? const [],
    ChefOrdersSection.active => queues?.active ?? const [],
    ChefOrdersSection.ready => queues?.ready ?? const [],
  };
}
