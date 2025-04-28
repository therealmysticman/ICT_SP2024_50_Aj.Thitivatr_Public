import 'package:flutter/material.dart';

class AccessoriesDetailsPage extends StatelessWidget {
  final Map<String, dynamic> accessory;

  const AccessoriesDetailsPage({super.key, required this.accessory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(accessory['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                'assets/${accessory['image']}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported, size: 100), // Fallback image
              ),
            ),
            const SizedBox(height: 16),
            Text(
              accessory['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ${accessory['price']}',
              style: const TextStyle(fontSize: 20, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              accessory['description'],
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Future feature: Implement add-to-cart functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${accessory['name']} added to cart!')),
                );
              },
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }
}
