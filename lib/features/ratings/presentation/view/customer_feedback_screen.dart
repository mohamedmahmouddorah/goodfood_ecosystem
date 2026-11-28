import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/firebase/firebase_environment.dart';
import '../../../menu/presentation/widgets/meal_image.dart';

class CustomerFeedbackScreen extends StatefulWidget {
  const CustomerFeedbackScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<CustomerFeedbackScreen> createState() => _CustomerFeedbackScreenState();
}

class _CustomerFeedbackScreenState extends State<CustomerFeedbackScreen> {
  static const _bg = Color(0xFF001014);
  static const _surface = Color(0xFF061A20);
  static const _gold = Color(0xFFFFB83F);
  final _notes = TextEditingController();
  final Map<String, int> _mealRatings = {};
  int _overall = 0;
  bool _loading = true;
  bool _saving = false;
  bool _alreadyRated = false;
  String? _error;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _meals = [];

  @override
  void initState() { super.initState(); _loadOrder(); }
  @override
  void dispose() { _notes.dispose(); super.dispose(); }

  Future<void> _loadOrder() async {
    try {
      final snap = await FirebaseEnvironment.store.collection('orders').doc(widget.orderId).get();
      if (!snap.exists) throw StateError('Order not found.');
      final data = snap.data()!;
      if (data['status'] != 'delivered') {
        throw StateError('Feedback is available after the order is delivered.');
      }
      final uid = FirebaseEnvironment.auth.currentUser?.uid;
      final customerId = data['customerId']?.toString();
      if (uid == null || customerId != uid) {
        throw StateError('Only the customer who placed this order can rate it.');
      }
      final previousRating = await FirebaseEnvironment.store
          .collection('ratings')
          .doc(widget.orderId)
          .get();
      final meals = (data['meals'] as List<dynamic>? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() { _order = data; _meals = meals; _alreadyRated = previousRating.exists; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_overall == 0 || _mealRatings.length != _meals.map((m) => (m['meal_id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet().length) {
      setState(() => _error = 'Please rate the restaurant and every meal.'); return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final uid = FirebaseEnvironment.auth.currentUser?.uid;
      final customerId = _order?['customerId']?.toString();
      if (uid == null || customerId != uid) {
        throw StateError('Only the customer who placed this order can submit feedback.');
      }
      final ratingRef = FirebaseEnvironment.store
          .collection('ratings')
          .doc(widget.orderId);
      await FirebaseEnvironment.store.runTransaction((transaction) async {
        final existing = await transaction.get(ratingRef);
        if (existing.exists) {
          throw StateError('Feedback has already been submitted for this order.');
        }
        transaction.set(ratingRef, {
          'orderId': widget.orderId,
          'customerId': uid,
          'overallRating': _overall,
          'mealRatings': _mealRatings.entries
              .map((e) => {'mealId': e.key, 'rating': e.value})
              .toList(),
          'notes': _notes.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Could not submit feedback. Please try again. ($e)'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, foregroundColor: Colors.white, elevation: 0, title: const Text('Customer Feedback', style: TextStyle(fontWeight: FontWeight.w600))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: _gold)) : _alreadyRated ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('You have already submitted feedback for this order.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)))) : _error != null && _order == null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))) : SafeArea(
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text('Order #${_order?['disp_id'] ?? widget.orderId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3), const Text('RESTAURANT', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 28), const Text('How was your experience?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 5), const Text('Your feedback helps us improve', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 15)),
            const SizedBox(height: 18),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Overall Rating', style: TextStyle(color: Colors.white, fontSize: 18)), const SizedBox(height: 8), Center(child: _stars(_overall, (v) => setState(() => _overall = v))), Center(child: Text(_overall == 0 ? 'Tap to rate' : '$_overall / 5', style: const TextStyle(color: Colors.white, fontSize: 18)))])),
            const SizedBox(height: 9),
            _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rate Your Meals', style: TextStyle(color: Colors.white, fontSize: 18)), const SizedBox(height: 8), ..._mealRows()])),
            const SizedBox(height: 22), const Text('Any suggestions or comments?', style: TextStyle(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 7), TextField(controller: _notes, maxLines: 3, maxLength: 500, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Tell us about your experience...', hintStyle: const TextStyle(color: Colors.blueGrey), filled: true, fillColor: _surface, counterStyle: const TextStyle(color: Colors.blueGrey), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF18323A))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold)))),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 8), SizedBox(height: 54, child: ElevatedButton(onPressed: _saving ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Submit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
          ],
        ))),
      ),
    );
  }

  List<Widget> _mealRows() {
    final unique = <String, Map<String, dynamic>>{};
    for (final meal in _meals) { final id = (meal['meal_id'] ?? '').toString(); if (id.isNotEmpty) unique.putIfAbsent(id, () => meal); }
    return unique.entries.map((entry) {
      final meal = entry.value; final rating = _mealRatings[entry.key] ?? 0;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(width: 48, height: 48, child: MealImage(url: (meal['meal_image'] ?? '').toString(), cacheWidth: 96))), const SizedBox(width: 12), Expanded(child: Text('${meal['meal_name'] ?? 'Meal'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))), _stars(rating, (v) => setState(() => _mealRatings[entry.key] = v), compact: true)]));
    }).toList();
  }

  Widget _stars(int value, ValueChanged<int> onChanged, {bool compact = false}) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => IconButton(padding: EdgeInsets.zero, constraints: BoxConstraints.tightFor(width: compact ? 22 : 42, height: compact ? 34 : 46), onPressed: () => onChanged(i + 1), icon: Icon(i < value ? Icons.star : Icons.star_border, color: _gold, size: compact ? 19 : 36))));
  Widget _panel({required Widget child}) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10)), child: child);
}
