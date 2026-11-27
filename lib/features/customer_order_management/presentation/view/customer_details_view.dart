import 'package:goodfood_ecosystem/core/widgets/language_toggle.dart';
import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/widgets/app_text_fields.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_cubit.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/customer_order_state.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/widgets/guests_number.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view/menu_screen.dart';
import 'package:goodfood_ecosystem/features/menu/presentation/view_model/menu_cubit.dart';

class CustomerDetailsView extends StatefulWidget {
  const CustomerDetailsView({super.key, this.editMode = false});

  final bool editMode;

  @override
  State<CustomerDetailsView> createState() => _CustomerDetailsViewState();
}

class _CustomerDetailsViewState extends State<CustomerDetailsView> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController tableCont;
  final quantityKey = GlobalKey<FormFieldState<int>>();
  bool _initializedEditValues = false;
  late final TextEditingController nameCont;

  @override
  void initState() {
    super.initState();
    tableCont = TextEditingController();
    nameCont = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.editMode && !_initializedEditValues) {
      final customer = context.read<CustomerOrderCubit>();
      tableCont.text = customer.tableNo?.toString() ?? '';
      nameCont.text = customer.name ?? '';
      _initializedEditValues = true;
    }
  }

  @override
  void dispose() {
    tableCont.dispose();
    nameCont.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderCubit = context.read<CustomerOrderCubit>();
    final menuCubit = widget.editMode ? null : context.read<MenuCubit>();
    final cartCubit = widget.editMode ? null : context.read<CartCubit>();
    return BlocListener<CustomerOrderCubit, CustomerOrderState>(
      listener: (context, state) {
        if (state is CustomerDeatailsSuccessState && widget.editMode) {
          Navigator.of(context).pop();
        } else if (state is CustomerDeatailsSuccessState) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlocProvider.value(
                value: orderCubit,
                child: MenuScreen(repository: menuCubit!.repo, repo: cartCubit!.repo),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          actions: const [LanguageToggle()],
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: 27,
              color: Colors.white,
            ),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText('GoodFood', style: AppFonts.mainTitle.copyWith(fontSize: MediaQuery.sizeOf(context).width >= 800 ? 34 : 24)),
              AppText('RESTAURANT', style: AppFonts.smallGoldTiltle.copyWith(fontSize: MediaQuery.sizeOf(context).width >= 800 ? 14 : null)),
            ],
          ),
          centerTitle: true,
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('${AppAssets.path}login_background.png'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final scale = (constraints.maxWidth / 900).clamp(1.0, 1.35);
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 36 : 20,
                      vertical: wide ? 28 : 16,
                    ),
                    child: Container(
                      width: wide ? 900 : double.infinity,
                      constraints: const BoxConstraints(maxWidth: 900),
                      padding: EdgeInsets.all(wide ? 42 : 24),
                      decoration: BoxDecoration(
                        color: const Color(0xE6001014),
                        borderRadius: BorderRadius.circular(wide ? 30 : 22),
                        border: Border.all(color: AppColors.cardBorder.withOpacity(.75)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 28, offset: Offset(0, 12)),
                        ],
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              'Your Details',
                              style: AppFonts.mainTitle.copyWith(fontSize: 34 * scale),
                            ),
                            SizedBox(height: 8),
                            AppText(
                              widget.editMode ? 'Update your customer details.' : 'Please enter your table information to start ordering.',
                              style: AppFonts.subTitle.copyWith(fontSize: 16 * scale, color: Colors.white70),
                            ),
                            SizedBox(height: wide ? 34 : 24),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _tableField()),
                                  SizedBox(width: 24),
                                  Expanded(child: _guestsField()),
                                ],
                              )
                            else ...[
                              _tableField(),
                              SizedBox(height: 12),
                              _guestsField(),
                            ],
                            SizedBox(height: wide ? 12 : 4),
                            _nameField(),
                            SizedBox(height: wide ? 28 : 18),
                            SizedBox(
                              width: double.infinity,
                              height: 60 * scale,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    orderCubit.setCustomerDeyails(
                                      tableno: int.parse(tableCont.text),
                                      noofguests: quantityKey.currentState!.value!,
                                      custName: nameCont.text.trim().isEmpty
                                          ? null
                                          : nameCont.text.trim(),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldDark,
                                  foregroundColor: Colors.black,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AppText(
                                      widget.editMode ? 'Save Changes' : 'Continue',
                                      style: AppFonts.subTitle.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19 * scale,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 26 * scale),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Table Number', style: AppFonts.boldSubTitleWhite18.copyWith(fontSize: 18)),
          SizedBox(height: 8),
          AppTextFields(cont: tableCont, hintTxt: 'Enter table number', type: AppFieldsType.tableNo),
        ],
      );

  Widget _guestsField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Number of Guests', style: AppFonts.boldSubTitleWhite18.copyWith(fontSize: 18)),
          SizedBox(height: 8),
          GuestsNumber(quantityKey: quantityKey, initialValue: CustomerOrderCubit().noOfGuests ?? 1),
        ],
      );

  Widget _nameField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Your Name (Optional)', style: AppFonts.boldSubTitleWhite18.copyWith(fontSize: 18)),
          SizedBox(height: 8),
          AppTextFields(cont: nameCont, hintTxt: 'Enter your name', type: AppFieldsType.name),
        ],
      );
}
