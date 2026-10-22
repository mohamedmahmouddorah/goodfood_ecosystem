import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:goodfood_ecosystem/core/constants/app_assets.dart';
import 'package:goodfood_ecosystem/core/constants/app_fonts.dart';

class CustomerDetailsView extends StatelessWidget {
  const CustomerDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(onPressed: (){}, icon: Icon(Icons.arrow_back_ios ,size: 30,color: Colors.white, )),
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
        child: Column(
          children: [
            
          ],
        ),
      ),
    );
  }
}