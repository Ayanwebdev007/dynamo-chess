import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/store_models.dart';
import '../core/store_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final StoreService _storeService = StoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  void _showOrderDialog() {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Order ${widget.product.name}", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total: ₹${widget.product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Full Name", labelStyle: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Shipping Address", labelStyle: TextStyle(color: Colors.white38)),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text("We will process your order and contact you for payment details.", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
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
                productId: widget.product.id,
                productName: widget.product.name,
                amount: widget.product.price,
                status: 'pending',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                shippingAddress: addressCtrl.text,
                shippingName: nameCtrl.text,
                shippingPhone: phoneCtrl.text,
              );
              await _storeService.placeOrder(order);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("PLACE ORDER", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String title) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
          ),
          child: Icon(icon, color: const Color(0xFFD4AF37), size: 28),
        ),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildKitItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: const Color(0xFFD4AF37),
        collapsedIconColor: Colors.white54,
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(answer, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(String name, String date, String text, int rating) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                child: Text(name[0], style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) => Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: const Color(0xFFD4AF37),
              size: 16,
            )),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 450.0,
                pinned: true,
                backgroundColor: const Color(0xFF0A0E0A),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'product_image_${widget.product.id}',
                        child: Container(
                          color: Colors.black26,
                          child: widget.product.imageAsset.isNotEmpty
                              ? Image.asset(widget.product.imageAsset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Colors.white24, size: 100))
                              : const Icon(Icons.inventory, color: Colors.white24, size: 100),
                        ),
                      ),
                      // Gradient overlay for smooth transition
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, const Color(0xFF0A0E0A).withOpacity(0.8), const Color(0xFF0A0E0A)],
                            stops: const [0.6, 0.9, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TITLE & RATINGS
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product.name,
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                                    const Icon(Icons.star_half, color: Color(0xFFD4AF37), size: 18),
                                    const SizedBox(width: 8),
                                    const Text("4.8", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    const Text("(124 reviews)", style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.product.inStock ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.product.inStock ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                            ),
                            child: Text(
                              widget.product.inStock ? "IN STOCK" : "SOLD OUT",
                              style: TextStyle(
                                color: widget.product.inStock ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),

                      // FEATURES BAR
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildFeatureIcon(Icons.local_shipping, "Free\nShipping")),
                          Expanded(child: _buildFeatureIcon(Icons.verified, "Premium\nQuality")),
                          Expanded(child: _buildFeatureIcon(Icons.security, "Secure\nCheckout")),
                          Expanded(child: _buildFeatureIcon(Icons.support_agent, "24/7\nSupport")),
                        ],
                      ),

                      const SizedBox(height: 40),
                      
                      // DESCRIPTION
                      Text("Overview", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 16),
                      Text(
                        widget.product.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                      ),
                      
                      const SizedBox(height: 40),

                      // WHAT'S IN THE KIT
                      Text("What's in the kit?", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121512),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            _buildKitItem(Icons.grid_on, "10x10 Tournament Board", "Premium rollable vinyl board designed for Dynamo Chess rules."),
                            const Divider(color: Colors.white10, height: 1),
                            _buildKitItem(Icons.extension, "Custom Piece Set", "High-quality weighted pieces including the new Missile pieces."),
                            const Divider(color: Colors.white10, height: 1),
                            _buildKitItem(Icons.work, "Travel Carry Bag", "Durable woven bag to easily carry your set anywhere."),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // FAQ SECTION
                      Text("Frequently Asked Questions", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 16),
                      _buildFAQ("How long does shipping take?", "Standard shipping takes 5-7 business days within the country. International shipping may take up to 14 business days."),
                      _buildFAQ("Are the pieces weighted?", "Yes, the pieces are triple-weighted to provide a premium feel and prevent them from tipping over during intense games."),
                      _buildFAQ("Does it include a rulebook?", "Yes! Every kit comes with a detailed physical rulebook explaining all the unique mechanics of Dynamo Chess."),

                      const SizedBox(height: 40),

                      // REVIEWS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Customer Reviews", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 20)),
                          TextButton(onPressed: () {}, child: const Text("See All", style: TextStyle(color: Color(0xFFD4AF37)))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.05, 0.95, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.antiAlias,
                            children: [
                              _buildReview("Rahul S.", "Oct 12, 2025", "Absolutely incredible quality. The 10x10 board really changes the game, and the pieces feel fantastic in hand.", 5),
                              _buildReview("Priya M.", "Sep 28, 2025", "Bought this as a gift for a chess fanatic and they haven't stopped playing. Highly recommend!", 5),
                              _buildReview("Vikram K.", "Aug 15, 2025", "Great set. The bag is a nice touch. Shipping was slightly delayed but worth the wait.", 4),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 120), // Extra space for the bottom sticky bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // STICKY BOTTOM BAR
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E0A).withOpacity(0.7),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Total Price", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text("₹${widget.product.price.toStringAsFixed(2)}", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: widget.product.inStock ? _showOrderDialog : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: Colors.white10,
                                disabledForegroundColor: Colors.white24,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 8,
                                shadowColor: const Color(0xFFD4AF37).withOpacity(0.5),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.product.inStock ? "BUY NOW" : "OUT OF STOCK",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
