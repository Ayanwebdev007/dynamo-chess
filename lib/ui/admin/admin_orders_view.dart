import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/store_models.dart';
import '../../core/store_service.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  final StoreService _storeService = StoreService();

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orangeAccent;
      case 'shipped': return Colors.blueAccent;
      case 'completed': return Colors.greenAccent;
      case 'cancelled': return Colors.redAccent;
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ORDERS MANAGEMENT", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          StreamBuilder<List<StoreOrder>>(
            stream: _storeService.getOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text("No orders found.", style: GoogleFonts.montserrat(color: Colors.white38)),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final date = DateTime.fromMillisecondsSinceEpoch(order.createdAt);
                  final formattedDate = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ORDER ID: ${order.id}", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(order.productName, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("₹${order.amount.toStringAsFixed(2)}", style: GoogleFonts.cinzel(color: const Color(0xFFD4AF37), fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CUSTOMER", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(order.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(order.userEmail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text("SHIPPING TO", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              if (order.shippingName.isNotEmpty) Text(order.shippingName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              if (order.shippingPhone.isNotEmpty) Text(order.shippingPhone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(order.shippingAddress, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getStatusColor(order.status).withOpacity(0.3)),
                                ),
                                child: Text(order.status.toUpperCase(), style: TextStyle(color: _getStatusColor(order.status), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 16),
                              DropdownButton<String>(
                                value: order.status,
                                dropdownColor: const Color(0xFF1A1A1A),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                underline: Container(height: 1, color: Colors.white24),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                                ],
                                onChanged: (newStatus) {
                                  if (newStatus != null) {
                                    _storeService.updateOrderStatus(order.id, newStatus);
                                  }
                                },
                              ),
                            ],
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
