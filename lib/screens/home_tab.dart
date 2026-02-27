import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      // Step 1: Request permission using the native method.
      // This will trigger the popup shown in the screenshot.
      LocationPermission permission = await Geolocator.requestPermission();

      // The Geolocator.requestPermission() handles the OS-level prompt.
      // It returns the new permission status after the user's choice.
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        canUseLocation = true;
        debugPrint('Location permission granted.');
      } else {
        debugPrint('Location permission denied.');
      }

      // Step 2: Fetch all studios first.
      await fetchStudios();

      // Step 3: Filter studios based on the permission result.
      await filterStudiosByLocation(canUseLocation: canUseLocation);
    } catch (e, st) {
      debugPrint('Error during permission check or fetching studios: $e');
      debugPrint('Stack trace: $st');
      setState(() => isLoading = false);
    }
  }

  // This function fetches all studios, branches, and batches and correctly maps the counts.
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
      for (var batch in batchList) {
        final studioId = batch['studioId'].toString();
        batchCountMap[studioId] = (batchCountMap[studioId] ?? 0) + 1;
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

      debugPrint(
        'Successfully fetched and updated ${updatedStudios.length} studios.',
      );
    } catch (e, st) {
      debugPrint('Error fetching studios: $e');
      debugPrint('Stack trace: $st');
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
        debugPrint(
          'User location: ${position.latitude}, ${position.longitude}',
        );

        const radiusKm = 10.0;
        filteredStudios = allStudios.where((studio) {
          // Ensure studio has a valid location before calculating distance
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
          debugPrint(
            'No approved studios found within 10km radius. Displaying all approved studios.',
          );
          filteredStudios = allStudios
              .where(
                (studio) => (studio.status?.toLowerCase() ?? '') == 'approved',
              )
              .toList();
        }
      } else {
        // If permission is not granted, show all approved studios.
        filteredStudios = allStudios
            .where(
              (studio) => (studio.status?.toLowerCase() ?? '') == 'approved',
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching location or filtering: $e');
      // On any error, default to showing all approved studios.
      filteredStudios = allStudios
          .where((studio) => (studio.status?.toLowerCase() ?? '') == 'approved')
          .toList();
    }

    setState(() {
      featuredStudios = filteredStudios;
      isLoading = false;
    });

    debugPrint(
      'Featured studios count after filtering: ${featuredStudios.length}',
    );
  }

  // Refreshes the studio data.
  Future<void> refreshStudios() async {
    setState(() {
      isLoading = true;
    });
    await fetchStudios();
    await filterStudiosByLocation(canUseLocation: false);
  }

  String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    const baseUrl = "http://147.93.19.17:5002"; // your backend
    return relativePath.startsWith("/")
        ? "$baseUrl$relativePath"
        : "$baseUrl/$relativePath";
  }

  // Fetches dance styles from backend using the service
  Future<void> fetchDanceStyles() async {
    try {
      final styles = await DanceStyleService().fetchDanceStyles();
      setState(() {
        popularStyles = styles;
      });
    } catch (e) {
      debugPrint('Error fetching dance styles: $e');
      setState(() {
        popularStyles = [];
      });
    }
  }

  // Fetches the owner's name.
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
    } catch (e) {
      debugPrint('Error fetching owner name: $e');
    }
    return "N/A";
  }

  // Calculates the distance between two geographical points.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<bool> _checkAndRequestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Location'),
          content: const Text(
            'To see nearby studios, please enable your device location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) return true;
    if (status.isDenied) {
      status = await Permission.location.request();
      return status.isGranted;
    }
    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Please enable location permission in app settings to see nearby studios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
      return (await Permission.location.status).isGranted;
    }
    return false;
  }

  Future<void> getUserLocationAndFilterStudios() async {
    String? city;
    try {
      city = await _determinePositionAndGetCity();

      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => Position(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              headingAccuracy: 0,
              altitudeAccuracy: 0,
            ),
          );

      final userLat = position.latitude;
      final userLng = position.longitude;
      const radiusKm = 10.0;

      final filtered = allStudios.where((studio) {
        final distance = calculateDistance(
          userLat,
          userLng,
          studio.latitude ?? 0.0,
          studio.longitude ?? 0.0,
        );
        return distance <= radiusKm &&
            (studio.status ?? '').toLowerCase() == 'approved';
      }).toList();

      if (filtered.isNotEmpty) {
        featuredStudios = filtered;
      } else if (city != null) {
        userCity = city;
        final cityLower = city.toLowerCase();
        featuredStudios = allStudios
            .where(
              (studio) =>
                  (studio.city?.toLowerCase() ?? '') == cityLower &&
                  (studio.status?.toLowerCase() ?? '') == 'approved',
            )
            .toList();
      } else {
        featuredStudios = allStudios
            .where(
              (studio) => (studio.status ?? '').toLowerCase() == 'approved',
            )
            .toList();
      }
      debugPrint('Filtered featured studios count: ${featuredStudios.length}');
      if (featuredStudios.isEmpty) {
        featuredStudios = [];
        debugPrint('No approved studios found.');
      }
    } catch (e) {
      debugPrint('Error fetching location or filtering studios: $e');
      featuredStudios = allStudios
          .where((studio) => (studio.status ?? '').toLowerCase() == 'approved')
          .toList();
      if (city != null) userCity = city;
    }
    setState(() {});
  }

  Future<String?> _determinePositionAndGetCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => Position(
              latitude: 0.0,
              longitude: 0.0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              headingAccuracy: 0,
              altitudeAccuracy: 0,
            ),
          );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10), onTimeout: () => []);

      if (placemarks.isNotEmpty) {
        return placemarks.first.locality ??
            placemarks.first.subAdministrativeArea;
      }
    } catch (e) {
      debugPrint('Error during reverse geocoding: $e');
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshStudios();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Home'),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: refreshStudios,
      //       tooltip: 'Refresh',
      //     ),
      //   ],
      // ),
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
              // TextField(
              //   decoration: InputDecoration(
              //     hintText: 'Search for dance studios...',
              //     prefixIcon: const Icon(Icons.search),
              //     border: OutlineInputBorder(
              //       borderRadius: BorderRadius.circular(30),
              //     ),
              //     filled: true,
              //     fillColor: Colors.grey[200],
              //   ),
              // ),
              const Text(
                'Popular Styles',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 120,
                child: FutureBuilder<List<DanceStyleModel>>(
                  future: _danceStyleService
                      .fetchDanceStyles(), // ✅ Use service
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                print(
                                                  'Error loading image: $error',
                                                );
                                                return const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  size: 40,
                                                );
                                              },
                                        )
                                      : const Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 40,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                style.name,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                    // ✅ Ensure logoUrl is a non-null string
                    final logoPath = (studio.logoUrl ?? '');
                    final logoUrl = logoPath.isNotEmpty
                        ? UploadService.fullUrl(logoPath)
                        : null;

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                alignment: Alignment.bottomLeft,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        getFullImageUrl(
                                          studio.logoUrl,
                                        ).isNotEmpty
                                        ? Image.network(
                                            getFullImageUrl(studio.logoUrl),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.store,
                                                        size: 40,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.store,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),

                                  if (studio.averageRating != null &&
                                      studio.totalReviews != null)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF7FAFC,
                                        ), // Updated to the yellowish-orange color
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${studio.averageRating!.toStringAsFixed(1)}★(${studio.totalReviews})',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
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
                                      'Locations: ${studio.branchCount ?? 0}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Active Batches: ${studio.batchCount ?? 0}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Owner: ${studio.ownerName ?? "N/A"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: const Color(
                                          0xFF0D141C,
                                        ), // Gray color
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
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
                ),
            ],
          ),
        ),
      ), // closes RefreshIndicator
    );
  }
}
