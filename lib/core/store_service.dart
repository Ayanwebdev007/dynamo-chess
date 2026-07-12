import 'package:firebase_database/firebase_database.dart';
import 'store_models.dart';

class StoreService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // --- Products ---

  Stream<List<Product>> getProducts() {
    return _db.child('store/products').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      
      final products = data.entries.map((e) {
        return Product.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>);
      }).toList();
      
      return products;
    });
  }

  Future<void> addProduct(Product product) async {
    final newRef = _db.child('store/products').push();
    await newRef.set(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _db.child('store/products/${product.id}').update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _db.child('store/products/$productId').remove();
  }

  // --- Orders ---

  Stream<List<StoreOrder>> getOrders() {
    return _db.child('store/orders').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      
      final orders = data.entries.map((e) {
        return StoreOrder.fromMap(e.key.toString(), e.value as Map<dynamic, dynamic>);
      }).toList();
      
      // Sort by newest first
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<void> placeOrder(StoreOrder order) async {
    final newRef = _db.child('store/orders').push();
    await newRef.set(order.toMap());
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.child('store/orders/$orderId').update({'status': status});
  }
}
