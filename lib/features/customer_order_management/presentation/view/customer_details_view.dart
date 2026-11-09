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
  const CustomerDetailsView({super.key});

  @override
  State<CustomerDetailsView> createState() => _CustomerDetailsViewState();
}

class _CustomerDetailsViewState extends State<CustomerDetailsView> {
  final  GlobalKey<FormState>  formKey = GlobalKey<FormState>() ;
  late final TextEditingController tableCont  ;
  final quantityKey = GlobalKey<FormFieldState<int>>();
  late final TextEditingController nameCont ;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    tableCont = TextEditingController();
    nameCont = TextEditingController();
  }
 @override
  void dispose() {
    // TODO: implement dispose
    tableCont.dispose();
    nameCont.dispose();
    super.dispose();

  }
  @override
  Widget build(BuildContext context) {
    final menuCubit = context.read<MenuCubit>();
    final cartCubit = context.read<CartCubit>();
    final orderCubit =  context.read<CustomerOrderCubit>();
    return BlocListener<CustomerOrderCubit, CustomerOrderState>(
      listener: (context, state) {
        if(state is CustomerDeatailsSuccessState){
        //print("Hello , ${orderCubit.name} , yout table Number is : ${orderCubit.tableNo} and there are ${orderCubit.noOfGuests}Guest on this table");
       Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BlocProvider.value(
      value: orderCubit,
      child: MenuScreen(
        repository: menuCubit.repo,
        repo: cartCubit.repo,
      ),
    ),
  ),
);
        }
      },
      child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(onPressed: (){
              Navigator.pop(context);
            }, icon: Icon(Icons.arrow_back_ios ,size: 30,color: Colors.white, )),
            title: Column(children: [
               Text("GoodFood", style: AppFonts.mainTitle.copyWith(fontSize: 24)),
                    Text("RESTAURANT", style: AppFonts.smallGoldTiltle),
            ],),
            centerTitle: true,
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("${AppAssets.path}login_background.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0 , horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text("Your Details", style: AppFonts.mainTitle.copyWith(fontSize: 30)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0 ),
                        child: Form(
                        key: formKey,
                        child: 
                        Column(
                          crossAxisAlignment: .start,
                          children: [
                             Text("Table Number" , style: AppFonts.boldSubTitleWhite18,),
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 8.0),
                               child: AppTextFields(cont: tableCont, hintTxt: "Enter table number", type: AppFieldsType.tableNo),
                             ),
                            Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text("Number of Guests" , style: AppFonts.boldSubTitleWhite18,),
                             ),
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 8.0),
                               child: GuestsNumber(quantityKey: quantityKey,)
                             ),
                             Padding(
                               padding: const EdgeInsets.only(top: 16.0),
                               child: Text("Your Name (Optional)" , style: AppFonts.boldSubTitleWhite18,),
                             ),
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 8.0),
                               child: AppTextFields(cont: nameCont, hintTxt: "Enter your name", type: AppFieldsType.name),
                             ),
                            Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: ElevatedButton(onPressed: (){
                              if(formKey.currentState!.validate()){
                                orderCubit.setCustomerDeyails(tableno: int.parse(tableCont.text), noofguests: quantityKey.currentState!.value! , custName: nameCont.text.trim().isEmpty ? null : nameCont.text.trim());
                              }
                            },
                             style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldDark,
                              minimumSize: Size(350, 55)
                             ),
                             child: Row(
                              mainAxisAlignment: .center,
                               children: [
                                 Text("Continue" , style: AppFonts.subTitle.copyWith(color: Colors.black , fontWeight: .bold),),
                                 SizedBox(width: 8,),
                                 Icon(Icons.arrow_forward , color: Colors.black, size: 28,)
                               ],
                             )
                             ),
                          ),
                        ],)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}