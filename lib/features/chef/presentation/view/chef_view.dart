import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';

class ChefView extends StatelessWidget {
  const ChefView({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    return Scaffold(
       body: Center(
         child: Column(
          mainAxisAlignment: .center,
            children: [
              Text("Welcome ${authCubit.currentUser!.name} , from Ched Page"),
              Text("دي سكرينة جديدة مش مغير النص يصيع" ,  textDirection: TextDirection.rtl,)
            ],
         ),
       ),
    );
  }
}