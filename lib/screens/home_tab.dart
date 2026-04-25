import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dance_style_model.dart';
import '../models/user_model.dart';
import '../models/studio_model.dart';
import '../services/studio_service.dart';
import '../models/dance_style_model.dart';
import '../services/dance_style_service.dart';
import 'package:dancekatta/utils/image_utils.dart';
import '../services/upload_service.dart';
import 'dart:math';
import '../constants.dart';

final DanceStyleService _danceStyleService = DanceStyleService();

class HomeTab extends StatefulWidget {
  final UserModel user;
  const HomeTab({super.key, required this.user});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  List<StudioModel> allStudios = [];
  List<StudioModel> featuredStudios = [];
  List<DanceStyleModel> popularStyles = [];
  bool isLoading = true;
  String? userCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchDanceStyles();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Calling location permission and fetching studios...');
      await _promptLocationAndFetchStudios();
      debugPrint('Finished fetching studios.');
    });
  }

  Future<void> _promptLocationAndFetchStudios() async {
    setState(() => isLoading = true);

    bool canUseLocation = false;
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        canUseLocation = true;
      }

      await fetchStudios();
      await filterStudiosByLocation(canUseLocation: canUseLocation);
    } catch (e, st) {
      debugPrint('Error during permission check or fetching studios: $e');
      debugPrint('Stack trace: $st');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStudios() async {
    try {
      final studiosFuture = StudioService().getAllStudios();
      final branchesResFuture = http.get(
        Uri.parse('http://147.93.19.17:5002/api/branches'),
      );
      final batchesResFuture = http.get(
        Uri.parse('http://147.93.19.17:5002/api/batches'),
      );

      final List<StudioModel> fetchedStudios = await studiosFuture;
      final branchesRes = await branchesResFuture;
      final batchesRes = await batchesResFuture;

      List branchList = [];
      List batchList = [];
      if (branchesRes.statusCode == 200) {
        branchList = jsonDecode(branchesRes.body);
      }
      if (batchesRes.statusCode == 200) {
        batchList = jsonDecode(batchesRes.body);
      }

      final Map<String, int> branchCountMap = {};
      for (var branch in branchList) {
        final studioId = branch['studioId'].toString();
        branchCountMap[studioId] = (branchCountMap[studioId] ?? 0) + 1;
      }

      final Map<String, int> batchCountMap = {};
      final now = DateTime.now();
      for (var batch in batchList) {
        final rawDate = batch['toDate'];
        bool isActive = true;
        if (rawDate != null) {
          DateTime? endDate;
          if (rawDate is String) {
            endDate = DateTime.tryParse(rawDate);
          }
          if (endDate != null && !endDate.isAfter(now.subtract(const Duration(days: 1)))) {
            isActive = false;
          }
        }
        
        if (isActive) {
          final studioId = batch['studioId'].toString();
          batchCountMap[studioId] = (batchCountMap[studioId] ?? 0) + 1;
        }
      }

      final updatedStudios = await Future.wait(
        fetchedStudios.map((studio) async {
          final studioOid = studio.id.oid.toString();
          final branchCount = branchCountMap[studioOid] ?? 0;
          final batchCount = batchCountMap[studioOid] ?? 0;

          String? ownerName;
          try {
            ownerName = await fetchOwnerName(studio.ownerId);
          } catch (e) {
            debugPrint('Error fetching owner for ${studio.studioName}: $e');
          }

          return studio.copyWith(
            ownerName: ownerName,
            branchCount: branchCount,
            batchCount: batchCount,
          );
        }),
      );

      setState(() {
        allStudios = updatedStudios;
      });
    } catch (e) {
      debugPrint('Error fetching studios: $e');
      setState(() {
        allStudios = [];
      });
    }
  }

  Future<void> filterStudiosByLocation({bool canUseLocation = false}) async {
    List<StudioModel> filteredStudios = [];
    try {
      if (canUseLocation) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        const radiusKm = 10.0;
        filteredStudios = allStudios.where((studio) {
          if (studio.latitude == null || studio.longitude == null) {
            return false;
          }
          final distance = calculateDistance(
            position.latitude,
            position.longitude,
            studio.latitude!,
            studio.longitude!,
          );
          return distance <= radiusKm &&
              (studio.status?.toLowerCase() ?? '') == 'approved';
        }).toList();

        if (filteredStudios.isEmpty) {
          filteredStudios = allStudios
              .where((studio) =>
                  (studio.status?.toLowerCase() ?? '') == 'approved')
              .toList();
        }
      } else {
        filteredStudios = allStudios
            .where((studio) =>
                (studio.status?.toLowerCase() ?? '') == 'approved')
            .toList();
      }
    } catch (e) {
      filteredStudios = allStudios
          .where((studio) =>
              (studio.status?.toLowerCase() ?? '') == 'approved')
          .toList();
    }

    setState(() {
      featuredStudios = filteredStudios;
      isLoading = false;
    });
  }

  Future<void> refreshStudios() async {
    setState(() {
      isLoading = true;
    });
    await fetchStudios();
    await filterStudiosByLocation(canUseLocation: false);
  }

  String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    const baseUrl = "http://147.93.19.17:5002";
    return relativePath.startsWith("/")
        ? "$baseUrl$relativePath"
        : "$baseUrl/$relativePath";
  }

  Future<void> fetchDanceStyles() async {
    try {
      final styles = await DanceStyleService().fetchDanceStyles();
      setState(() {
        popularStyles = styles;
      });
    } catch (e) {
      setState(() {
        popularStyles = [];
      });
    }
  }

  Future<String?> fetchOwnerName(dynamic ownerId) async {
    try {
      final idStr = ownerId is Map ? ownerId['\$oid'] : ownerId.toString();
      final res = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/users/$idStr'),
      );
      if (res.statusCode == 200) {
        final user = jsonDecode(res.body);
        return "${user['firstName'] ?? ''} ${user['lastName'] ?? ''}".trim();
      }
    } catch (e) {}
    return "N/A";
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop(); // ✅ exits the app
        return false;
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            await fetchDanceStyles();
            await _promptLocationAndFetchStudios();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Popular Styles',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 120,
                  child: FutureBuilder<List<DanceStyleModel>>(
                    future: _danceStyleService.fetchDanceStyles(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      } else if (!snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Center(child: Text("No styles found"));
                      }

                      final styles = snapshot.data!;

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: styles.length,
                        itemBuilder: (context, index) {
                          final style = styles[index];

                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.grey[200],
                                  child: ClipOval(
                                    child: style.imageUrl.isNotEmpty
                                        ? Image.network(
                                            style.imageUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(style.name),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Featured Studios',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (featuredStudios.isEmpty)
                  const Text('No featured studios available.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: featuredStudios.length,
                    itemBuilder: (context, index) {

                      final studio = featuredStudios[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/studio-detail',
                              arguments: studio,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: getFullImageUrl(studio.logoUrl).isNotEmpty
                                      ? Image.network(
                                          getFullImageUrl(studio.logoUrl),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey,
                                          child: const Icon(Icons.store),
                                        ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [

                                      Text(
                                        studio.studioName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      Text(
                                          'Locations: ${studio.branchCount ?? 0}'),

                                      Text(
                                          'Active Batches: ${studio.batchCount ?? 0}'),

                                      Text(
                                          'Owner: ${studio.ownerName ?? "N/A"}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}