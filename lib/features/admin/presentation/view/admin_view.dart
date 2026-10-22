import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    return Scaffold(
       body: Center(
         child: Column(
          mainAxisAlignment: .center,
            children: [
              Text("Welcome ${authCubit.currentUser!.name} , from Admin Page")
            ],
         ),
       ),
    );
  }
}