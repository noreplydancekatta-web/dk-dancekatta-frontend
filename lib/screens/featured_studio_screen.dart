// 📁 lib/screens/featured_studio_screen.dart

import 'package:flutter/material.dart';
import 'package:dancekatta/models/studio_model.dart';
import 'package:dancekatta/services/studio_service.dart';
import 'studio_detail_screen.dart';

class FeaturedStudiosScreen extends StatefulWidget {
  const FeaturedStudiosScreen({super.key});

  @override
  State<FeaturedStudiosScreen> createState() => _FeaturedStudiosScreenState();
}

class _FeaturedStudiosScreenState extends State<FeaturedStudiosScreen> {
  late Future<List<StudioModel>> _studiosFuture;

  @override
  void initState() {
    super.initState();
    _studiosFuture = StudioService().getAllStudios();
  }

  void _refresh() {
    setState(() {
      _studiosFuture = StudioService().getAllStudios();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Featured Studios')),
      body: FutureBuilder<List<StudioModel>>(
        future: _studiosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load studios'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No studios found'));
          }

          final studios = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: studios.length,
              itemBuilder: (context, index) {
                final studio = studios[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudioDetailScreen(studio: studio),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                studio.logoUrl.isNotEmpty
                                    ? Image.network(
                                        studio.logoUrl,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 100,
                                                height: 100,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.store,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.store,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                // ⭐ Rating badge
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    color: Colors.green,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${studio.averageRating.toStringAsFixed(1)}'
                                          ' (${studio.totalReviews})',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studio.studioName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Owner: ${studio.ownerName ?? "N/A"}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Locations: ${studio.branchCount ?? 0}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Batches: ${studio.batchCount ?? 0}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ), // closes ListView.builder
          ); // closes RefreshIndicator
        },
      ),
    );
  }
}
