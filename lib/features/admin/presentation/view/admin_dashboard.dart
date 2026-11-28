import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/firebase/firebase_environment.dart';

import '../../../../core/localization/goodfood_localizations.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../chef_management/presentation/view/chef_management_screen.dart';
import '../../../customer_order_management/data/models/order_model.dart';
import '../../../menu/data/repositories/menu_repository.dart';
import '../../../menu/presentation/view/menu_management_screen.dart';
import '../../../menu/presentation/widgets/menu_palette.dart';
import '../view_model/admin_orders_cubit.dart';
import 'admin_orders_view.dart';
import '../widgets/admin_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.menu});

  final MenuRepository menu;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedPeriod = 'Today';
  int _selectedNavIndex = 0;

  void _onNavTap(int index) {
    if (index == _selectedNavIndex) return;
    setState(() => _selectedNavIndex = index);

    switch (index) {
      case 1:
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminOrdersView(),
              ),
            )
            .then((_) {
              if (mounted) setState(() => _selectedNavIndex = 0);
            });
        break;
      case 2:
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MenuManagementScreen(repository: widget.menu),
              ),
            )
            .then((_) {
              if (mounted) setState(() => _selectedNavIndex = 0);
            });
        break;
      case 3:
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const ChefManagementScreen(),
              ),
            )
            .then((_) {
              if (mounted) setState(() => _selectedNavIndex = 0);
            });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<String>();

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminBackground,
        elevation: 0,
        titleSpacing: 8,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A359),
                  width: 1.5,
                ),
                color: const Color(0xFF131922),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFFD4A359),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GoodFood',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RESTAURANT',
                    style: const TextStyle(
                      color: Color(0xFFD4A359),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [LanguageToggle(), AdminLogoutButton()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF101820),
          border: Border(top: BorderSide(color: Color(0xFF24313D))),
        ),
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
              _buildNavItem(2, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
              _buildNavItem(3, Icons.groups_outlined, Icons.groups, 'Chefs'),
            ],
          ),
        ),
      ),
      body: AdminPageWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Admin header label
              AppText(
                'GoodFood Admin Dashboard',
                style: const TextStyle(
                  color: Color(0xFF546373),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Greeting Section
              AppText(
                'Good Morning, Admin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                name.isEmpty
                    ? "Here's what's happening at your restaurant"
                    : "Welcome, $name",
                style: const TextStyle(
                  color: Color(0xFF7E8B9B),
                  fontSize: 14,
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 2),
                AppText(
                  "Here's what's happening at your restaurant",
                  style: const TextStyle(
                    color: Color(0xFF7E8B9B),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 3 Stat Cards (Total Orders, Prep Time, Avg. Rating)
              BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
                builder: (context, state) => AdminOrderContent(
                  state: state,
                  builder: (orders) =>
                      _buildStatCards(context, state, orders.length),
                ),
              ),
              const SizedBox(height: 20),

              // Orders Overview Card with Area Chart
              _buildOrdersOverviewCard(context),
              const SizedBox(height: 24),

              // Top Rated Meals Section
              _buildTopRatedMealsSection(context),
              const SizedBox(height: 24),

              // Quick Actions Section
              const AdminSectionTitle('Quick actions'),
              AdminTiles(
                minimumWidth: 200,
                children: [
                  _Action(
                    'Manage Orders',
                    Icons.receipt_long_outlined,
                    const AdminOrdersView(),
                  ),
                  _Action(
                    'Manage Menu',
                    Icons.restaurant_menu,
                    MenuManagementScreen(repository: widget.menu),
                  ),
                  _Action(
                    'Manage Chefs',
                    Icons.people_outline,
                    const ChefManagementScreen(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Orders & Kitchen Overview
              BlocBuilder<AdminOrdersCubit, AdminOrdersState>(
                builder: (context, state) {
                  if (state.orders == null) return const SizedBox.shrink();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final recent = _OrderSection(
                        title: 'Recent Orders',
                        orders: state.orders!.take(5),
                        empty: 'No orders yet.',
                      );
                      final kitchen = _OrderSection(
                        title: 'Kitchen Overview',
                        orders: state.kitchen,
                        empty: 'No orders in the kitchen queue.',
                        compact: true,
                      );
                      if (constraints.maxWidth < 840) {
                        return Column(
                          children: [
                            recent,
                            const SizedBox(height: 24),
                            kitchen,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: recent),
                          const SizedBox(width: 16),
                          Expanded(child: kitchen),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconOutline,
    IconData iconFilled,
    String label,
  ) {
    final isSelected = _selectedNavIndex == index;
    final color = isSelected
        ? const Color(0xFFE5A93C)
        : const Color(0xFF6B7888);

    return InkWell(
      onTap: () => _onNavTap(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? iconFilled : iconOutline, color: color, size: 22),
            const SizedBox(height: 2),
            AppText(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(
    BuildContext context,
    AdminOrdersState state,
    int total,
  ) {
    final displayTotal = (state.orders != null && state.orders!.isNotEmpty)
        ? total
        : (state.orders != null && state.orders!.isEmpty ? 0 : 124);

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 390;
      final completedOrders = (state.orders ?? const <OrderModel>[])
          .where((order) => order.acceptedAt != null && order.readyAt != null)
          .toList();
      final averagePrepMinutes = completedOrders.isEmpty
          ? null
          : completedOrders.fold<int>(0, (sum, order) =>
                sum + order.readyAt!.difference(order.acceptedAt!).inMinutes) /
              completedOrders.length;
      final prepValue = averagePrepMinutes == null
          ? '—'
          : '${averagePrepMinutes.round()} min';
      final cards = <Widget>[
        _StatCard(title: 'Total Orders', value: MaterialLocalizations.of(context).formatDecimal(displayTotal), trend: 'Live orders', valueColor: const Color(0xFF55D6B0), trendColor: const Color(0xFF8295A7)),
        _StatCard(title: 'Prep Time', value: prepValue, trend: '${completedOrders.length} completed', valueColor: const Color(0xFF55D6B0), trendColor: const Color(0xFF8295A7)),
      ];
      final ratingCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseEnvironment.store.collection('ratings').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final values = docs.map((doc) => doc.data()['overallRating']).whereType<num>().toList();
          final average = values.isEmpty ? '—' : (values.fold<double>(0, (sum, value) => sum + value) / values.length).toStringAsFixed(1);
          return _StatCard(title: 'Avg. Rating', value: average, trend: '${values.length} reviews', valueColor: const Color(0xFFFFC45C), trendColor: const Color(0xFF8295A7));
        },
      );
      return Row(children: [
        Expanded(child: cards[0]), SizedBox(width: compact ? 6 : 10),
        Expanded(child: cards[1]), SizedBox(width: compact ? 6 : 10),
        Expanded(child: ratingCard),
      ]);
    });
  }

  Widget _buildOrdersOverviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14212B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263744)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              AppText(
                'Orders Overview',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPeriodTab('Today'),
                  const SizedBox(width: 6),
                  _buildPeriodTab('Week'),
                  const SizedBox(width: 6),
                  _buildPeriodTab('Month'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _OrdersChartPainter(period: _selectedPeriod),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label) {
    final isSelected = _selectedPeriod == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2836) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: AppText(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF7E8B9B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTopRatedMealsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminSectionTitle('Recent Customer Feedback'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseEnvironment.store.collection('ratings')
              .orderBy('createdAt', descending: true).limit(4).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AdminPanel(child: AdminMessage(message: 'Feedback could not be loaded.'));
            }
            if (!snapshot.hasData) {
              return const AdminPanel(child: Center(child: CircularProgressIndicator()));
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const AdminPanel(child: AdminMessage(message: 'No customer feedback yet.'));
            }
            return AdminPanel(
              child: Column(
                children: [
                  for (var i = 0; i < docs.length; i++) ...[
                    if (i > 0) const Divider(color: Color(0xFF263744), height: 18),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFFFC45C).withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.rate_review_outlined, color: Color(0xFFFFC45C), size: 19)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Order #${docs[i].data()['orderId'] ?? docs[i].id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text((docs[i].data()['notes'] as String?)?.trim().isNotEmpty == true ? docs[i].data()['notes'] as String : 'No written comment', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF91A0AE), fontSize: 12)),
                      ])),
                      const SizedBox(width: 8),
                      Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, color: Color(0xFFFFC45C), size: 15), Text('${docs[i].data()['overallRating'] ?? '—'}/5', style: const TextStyle(color: Color(0xFFFFC45C), fontWeight: FontWeight.w700))]),
                    ]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMealTile({
    required String name,
    required String price,
    required String rating,
    required Color imageColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48,
              height: 48,
              color: imageColor.withOpacity(0.35),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/imgs/placeholder_img.png',
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.fastfood,
                      color: Color(0xFFE5A93C),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF7E8B9B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Color(0xFFF5A623), size: 16),
              const SizedBox(width: 2),
              const Icon(Icons.star, color: Color(0xFFF5A623), size: 16),
              const SizedBox(width: 4),
              Text(
                rating,
                style: const TextStyle(
                  color: Color(0xFFF5A623),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.valueColor,
    required this.trendColor,
  });

  final String title;
  final String value;
  final String trend;
  final Color valueColor;
  final Color trendColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2836)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7E8B9B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              trend,
              style: TextStyle(
                color: trendColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersChartPainter extends CustomPainter {
  final String period;

  const _OrdersChartPainter({required this.period});

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 26.0;
    const bottomMargin = 22.0;

    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final yLabels = ['10', '8', '6', '4', '2', '0'];
    final textStyle = const TextStyle(
      color: Color(0xFF546373),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < yLabels.length; i++) {
      final y = (chartHeight / (yLabels.length - 1)) * i;
      final span = TextSpan(text: yLabels[i], style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 6, y - tp.height / 2));
    }

    final points = switch (period) {
      'Week' => const [
        Offset(0.0, 0.2),
        Offset(0.2, 0.45),
        Offset(0.4, 0.35),
        Offset(0.6, 0.7),
        Offset(0.8, 0.65),
        Offset(1.0, 0.85),
      ],
      'Month' => const [
        Offset(0.0, 0.15),
        Offset(0.2, 0.3),
        Offset(0.4, 0.55),
        Offset(0.6, 0.5),
        Offset(0.8, 0.8),
        Offset(1.0, 0.9),
      ],
      _ => const [
        Offset(0.0, 0.08),
        Offset(0.18, 0.38),
        Offset(0.32, 0.28),
        Offset(0.48, 0.62),
        Offset(0.62, 0.52),
        Offset(0.78, 0.72),
        Offset(0.9, 0.68),
        Offset(1.0, 0.94),
      ],
    };

    final path = Path();
    final fillPath = Path();

    final actualPoints = points.map((p) {
      return Offset(
        leftMargin + p.dx * chartWidth,
        chartHeight - (p.dy * chartHeight),
      );
    }).toList();

    path.moveTo(actualPoints.first.dx, actualPoints.first.dy);
    fillPath.moveTo(actualPoints.first.dx, actualPoints.first.dy);

    for (int i = 0; i < actualPoints.length - 1; i++) {
      final p0 = actualPoints[i];
      final p1 = actualPoints[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(leftMargin + chartWidth, chartHeight);
    fillPath.lineTo(leftMargin, chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B6A4E),
          Color(0xFF134E3E),
          Color(0xFF0F362B),
        ],
      ).createShader(Rect.fromLTWH(leftMargin, 0, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final xLabels = switch (period) {
      'Week' => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      'Month' => ['W1', 'W2', 'W3', 'W4'],
      _ => ['9am', '10am', '11am', '12pm'],
    };

    for (int i = 0; i < xLabels.length; i++) {
      final x = leftMargin + (chartWidth / (xLabels.length - 1)) * i;
      final span = TextSpan(text: xLabels[i], style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _OrdersChartPainter oldDelegate) =>
      oldDelegate.period != period;
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.destination);
  final String label;
  final IconData icon;
  final Widget destination;

  @override
  Widget build(BuildContext context) => AdminPanel(
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination)),
    child: Row(
      children: [
        Icon(icon, color: MenuPalette.gold),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.arrow_forward, size: 18),
      ],
    ),
  );
}

class _OrderSection extends StatelessWidget {
  const _OrderSection({
    required this.title,
    required this.orders,
    required this.empty,
    this.compact = false,
  });
  final String title;
  final Iterable<OrderModel> orders;
  final String empty;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminSectionTitle(title),
      if (orders.isEmpty) AdminPanel(child: AdminMessage(message: empty)),
      for (final order in orders.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AdminOrderCard(order: order, compact: compact),
        ),
      if (compact && orders.skip(5).isNotEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminOrdersView(kitchenOnly: true),
            ),
          ),
          child: const AppText('View kitchen queue'),
        ),
    ],
  );
}
