import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/models/order_item_model.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/data/repositry/cart_repo.dart';
import 'package:goodfood_ecosystem/features/customer_order_management/presentation/view_model/cart_state.dart';
import 'package:goodfood_ecosystem/features/menu/data/models/meal_model.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit({required this.repo}) : super(CartIntialState());
  final CartRepo repo;
  List<OrderItemModel> cartItems = [];
  Future<void> addToCart(MealModel meal) async {
    emit(AddToCartLoadingState(cartItems: cartItems));
    try {
      final OrderItemModel item = await repo.addtoCart(
        OrderItemModel(
          mealId: meal.id,
          mealName: meal.name,
          mealImage: meal.imageUrl,
          quantity: 1,
          unitPrice: meal.price,
        ),
      );
      int ind = cartItems.indexWhere((e) => e.mealId == item.mealId);
      if(ind == -1){
      cartItems.add(item);
      }
      emit(AddToCartSuccessState(item: item , cartItems:cartItems ));
    } catch (e) {
      emit(
        AddToCartFailState(
          msg: "An error occured while adding to cart, plase try again",
          cartItems: cartItems
        ),
      );
    }
  }
  Future<void> removeFromCart (OrderItemModel item)async {
    try{
       await repo.deleteFromCart(item.mealId);
       int ind = cartItems.indexWhere((e) => e.mealId == item.mealId);
       if(ind != -1){
       cartItems.removeAt(ind);
       }
       emit(RemoveFromCartSccessState(cartItems: cartItems , removedItem: item));
    }catch(e){
      emit(RemoveFromCartFailState(msg: e.toString() , cartItems: cartItems));
    }
  }
  void loadCartData (){
    emit(CartLoadDataLoadingState());
    try{
      cartItems = repo.getAllItems();
      emit(CartLoadDataSuccessState(cartItems: cartItems));
    } catch(e){
      emit(CartLoadDataFailState(msg: e.toString() , cartItems: cartItems));
    }
  }
  void updateQuantity(OrderItemModel item, int newQuan) {
    item.quantity = newQuan;
    repo.updateItem(item, newQuan);
    emit(CartUpdateQuantitySuccessState(newQuan: newQuan , cartItems: cartItems));
  }

  Future<void> clearCart() async {
    await repo.clearCart();
    cartItems.clear();
    emit(CartLoadDataSuccessState(cartItems: cartItems));
  }
  double get subTotal {
    double sub = 0;
    for(var i in cartItems){
      sub += i.unitPrice * i.quantity;
    }
    return sub;
  }
  double get tax  => subTotal*0.1;
  double get total => subTotal + tax;
}
