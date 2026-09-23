import 'package:flutter/material.dart';
import 'package:carcare_service/features/customers/presentation/screens/customer_search_tab.dart';
import 'package:carcare_service/features/vehicles/presentation/screens/vehicle_search_tab.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Хайлт'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.person_outline, size: 18),
                text: 'Үйлчлүүлэгч',
              ),
              Tab(
                icon: Icon(Icons.directions_car_outlined, size: 18),
                text: 'Машин',
              ),
            ],
          ),
        ),
        // Both tabs now live in their own feature folders and are driven by
        // their list controllers: the customer tab by P3-F2, the vehicle tab
        // by the P3-F3 follow-up. Neither reaches DiagnosticService any more.
        body: const TabBarView(
          children: [CustomerSearchTab(), VehicleSearchTab()],
        ),
      ),
    );
  }
}
