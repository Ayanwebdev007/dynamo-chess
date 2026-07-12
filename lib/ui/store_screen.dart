import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/store_models.dart';
import '../core/store_service.dart';
import 'product_details_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final StoreService _storeService = StoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  void _showOrderDialog(Product product) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to place an order.')));
      return;
    }

    final addressCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Order ${product.name}", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Price: ₹${product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Full Name", labelStyle: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Shipping Address", labelStyle: TextStyle(color: Colors.white38)),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            const Text("We will process your order and contact you for payment details.", style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              if (addressCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                return;
              }
              final order = StoreOrder(
                id: '', // Service handles new ID
                userId: _currentUser!.uid,
                userName: _currentUser!.displayName ?? 'Player',
                userEmail: _currentUser!.email ?? '',
                productId: product.id,
                productName: product.name,
                amount: product.price,
                status: 'pending',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                shippingAddress: addressCtrl.text,
                shippingName: nameCtrl.text,
                shippingPhone: phoneCtrl.text,
              );
              await _storeService.placeOrder(order);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
            child: const Text("PLACE ORDER"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)), onPressed: () => Navigator.pop(context)),
        title: Text("DYNAMO STORE", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 2.0)),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _storeService.getProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(child: Text("No items available in the store right now.", style: GoogleFonts.montserrat(color: Colors.white38)));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final crossAxisCount = isMobile ? 2 : (constraints.maxWidth ~/ 280);
              final aspectRatio = isMobile ? 0.72 : 0.75;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailsScreen(product: p),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: AspectRatio(
                                  aspectRatio: 1.4,
                                  child: Container(
                                    color: Colors.black26,
                                    child: Hero(
                                      tag: 'product_image_${p.id}',
                                      child: p.imageAsset.isNotEmpty 
                                        ? Image.asset(p.imageAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Colors.white24, size: 40))
                                        : const Icon(Icons.inventory, color: Colors.white24, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name, 
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: isMobile ? 14 : 16
                                    ), 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.description, 
                                    style: TextStyle(
                                      color: Colors.white38, 
                                      fontSize: isMobile ? 11 : 12
                                    ), 
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          "₹${p.price.toStringAsFixed(2)}", 
                                          style: GoogleFonts.cinzel(
                                            color: const Color(0xFFD4AF37), 
                                            fontWeight: FontWeight.bold, 
                                            fontSize: isMobile ? 14 : 16
                                          ), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        onPressed: p.inStock ? () => _showOrderDialog(p) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD4AF37),
                                          foregroundColor: Colors.black,
                                          disabledBackgroundColor: Colors.white10,
                                          disabledForegroundColor: Colors.white24,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 10 : 16, 
                                            vertical: isMobile ? 6 : 12
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          p.inStock ? "BUY" : "OUT", 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: isMobile ? 11 : 13
                                          )
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
