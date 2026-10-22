import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/core/constants/app_colors.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';
import 'package:goodfood_ecosystem/features/auth/presentation/view_model/auth_cubit.dart';

class RoleContainer extends StatelessWidget {
  const RoleContainer({super.key , required this.path , required this.desc , required this.type});
  final String path ;
  final String type;
  final String desc;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        context.read<AuthCubit>().selectRole(type);
      },
      child: Container(
        height: 330,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(25),
          border: BoxBorder.all(color: AppColors.goldenYellow),
        ),
        child: Padding(
      
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: .center,
            
              children: [
                   SizedBox(child: Image.asset(path) , height: 60,),
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 16.0),
                     child: SizedBox(height:40 , child:  Center(child: Text(type , style: AppFonts.subTitle.copyWith(color: Colors.white , fontSize:24 ),))),
                   ),
                  Text(desc , style:AppFonts.subTitle,textAlign: .center,)
              ],
          ),
        ),
      ),
    );
  }
}