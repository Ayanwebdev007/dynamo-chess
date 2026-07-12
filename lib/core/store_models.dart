class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageAsset; // Path in assets, e.g., 'assets/store/kit_bag.png'
  final bool inStock;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageAsset,
    this.inStock = true,
  });

  factory Product.fromMap(String id, Map<dynamic, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageAsset: map['imageAsset'] ?? '',
      inStock: map['inStock'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageAsset': imageAsset,
      'inStock': inStock,
    };
  }
}

class StoreOrder {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String productId;
  final String productName;
  final double amount;
  final String status; // 'pending', 'shipped', 'completed', 'cancelled'
  final int createdAt;
  final String shippingAddress;
  final String shippingName;
  final String shippingPhone;

  StoreOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.productId,
    required this.productName,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.shippingAddress,
    required this.shippingName,
    required this.shippingPhone,
  });

  factory StoreOrder.fromMap(String id, Map<dynamic, dynamic> map) {
    return StoreOrder(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ?? 0,
      shippingAddress: map['shippingAddress'] ?? '',
      shippingName: map['shippingName'] ?? '',
      shippingPhone: map['shippingPhone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'productId': productId,
      'productName': productName,
      'amount': amount,
      'status': status,
      'createdAt': createdAt,
      'shippingAddress': shippingAddress,
      'shippingName': shippingName,
      'shippingPhone': shippingPhone,
    };
  }
}
