import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/store_models.dart';
import '../../core/store_service.dart';

class AdminStoreView extends StatefulWidget {
  const AdminStoreView({super.key});

  @override
  State<AdminStoreView> createState() => _AdminStoreViewState();
}

class _AdminStoreViewState extends State<AdminStoreView> {
  final StoreService _storeService = StoreService();

  void _showAddEditDialog([Product? product]) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final priceCtrl = TextEditingController(text: product?.price.toString() ?? '');
    final assetCtrl = TextEditingController(text: product?.imageAsset ?? 'assets/store/');
    bool inStock = product?.inStock ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(product == null ? "ADD PRODUCT" : "EDIT PRODUCT", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Product Name", labelStyle: TextStyle(color: Colors.white38)),
                ),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white38)),
                  maxLines: 3,
                ),
                TextField(
                  controller: priceCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Price", labelStyle: TextStyle(color: Colors.white38)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: assetCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Asset Path (e.g. assets/store/item.png)", labelStyle: TextStyle(color: Colors.white38)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("In Stock", style: TextStyle(color: Colors.white)),
                    const Spacer(),
                    Switch(
                      value: inStock,
                      activeColor: const Color(0xFFD4AF37),
                      onChanged: (v) => setDialogState(() => inStock = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final newProduct = Product(
                  id: product?.id ?? '', // Service handles new ID for push
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  price: price,
                  imageAsset: assetCtrl.text,
                  inStock: inStock,
                );

                if (product == null) {
                  await _storeService.addProduct(newProduct);
                } else {
                  await _storeService.updateProduct(newProduct);
                }
                
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("STORE MANAGEMENT", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("ADD PRODUCT"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<Product>>(
            stream: _storeService.getProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text("No products found in the store.", style: GoogleFonts.montserrat(color: Colors.white38)),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return Container(
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
                                  child: p.imageAsset.isNotEmpty
                                      ? Image.asset(
                                          p.imageAsset,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 48),
                                        )
                                      : const Icon(Icons.image_not_supported, color: Colors.white24, size: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text("₹${p.price.toStringAsFixed(2)}", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(p.inStock ? "In Stock" : "Out of Stock", style: TextStyle(color: p.inStock ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                                          onPressed: () => _showAddEditDialog(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                          onPressed: () async {
                                            bool? confirm = await showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: const Color(0xFF1A1A1A),
                                                title: const Text("Delete Product?", style: TextStyle(color: Colors.white)),
                                                content: Text("Are you sure you want to delete ${p.name}?", style: const TextStyle(color: Colors.white70)),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("Delete")),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await _storeService.deleteProduct(p.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
