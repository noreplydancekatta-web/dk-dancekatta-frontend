import 'package:flutter/material.dart';
import 'dart:io';
import '../models/studio_model.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'batch_detail_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/branch_model.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';
import '../constants.dart';
import '../services/upload_service.dart';

class StudioDetailScreen extends StatefulWidget {
  final StudioModel studio;

  const StudioDetailScreen({super.key, required this.studio});

  @override
  State<StudioDetailScreen> createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends State<StudioDetailScreen> {
  int selectedBranchIndex = 0;
  List<BranchModel> branches = [];
  bool isLoadingBranches = true;
  String? errorBranches;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<BatchModel> batches = [];
  bool isLoadingBatches = false;
  String? errorBatches;

  Map<String, dynamic>? studioOwner;
  Set<String> uniqueDanceStyles = {};

  // Add a variable to hold the latest studio data
  late StudioModel currentStudio;

  void _openPhotoViewer(
    BuildContext context,
    List<String> photos,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  /// Pastel colors for initials placeholder
  final List<Color> _initialColors = [
    Color(0xFFE1BEE7), // pastel purple
    Color(0xFFB3E5FC), // pastel blue
    Color(0xFFFFCCBC), // pastel orange
    Color(0xFFC8E6C9), // pastel green
    Color(0xFFFFF8E1), // pastel cream
    Color(0xFFD1C4E9), // pastel lavender
    Color(0xFFFFCDD2), // pastel pink
    Color(0xFFFFECB3), // pastel light yellow
  ];

  @override
  void initState() {
    super.initState();
    currentStudio = widget.studio;
    fetchBranchesForStudio();
    fetchStudioOwner();
    fetchDanceStylesFromStudio();
    fetchLatestStudioData();
  }

  Future<void> fetchLatestStudioData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/studios/${widget.studio.id.oid}',
        ),
      );
      if (response.statusCode == 200) {
        final studioData = jsonDecode(response.body);
        setState(() {
          currentStudio = StudioModel.fromJson(studioData);
        });
      }
    } catch (e) {
      print('Error fetching latest studio data: $e');
    }
  }

  Future<void> fetchStudioOwner() async {
    try {
      final String ownerId = widget.studio.ownerId is Map
          ? widget.studio.ownerId['\$oid']
          : widget.studio.ownerId.toString();

      print("🔍 Fetching studio owner with ID: $ownerId");

      final res = await http.get(
        Uri.parse('http://147.93.19.17:5002/api/users/$ownerId'),
      );

      if (res.statusCode == 200) {
        setState(() {
          studioOwner = jsonDecode(res.body);
        });
      } else {
        throw Exception('Failed to load owner');
      }
    } catch (e) {
      print('❌ Error fetching studio owner: $e');
    }
  }

  Future<void> fetchDanceStylesFromStudio() async {
    try {
      final res = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/batches/studio/${widget.studio.id.oid}',
        ),
      );

      if (res.statusCode == 200) {
        final List<dynamic> batchList = jsonDecode(res.body);
        final styleIds = batchList
            .map((batch) => batch['style'])
            .where((id) => id != null)
            .toSet()
            .toList();

        print("📦 Sending styleIds: $styleIds");
        print("🟡 Requesting dance styles...");

        if (styleIds.isEmpty) {
          setState(() {
            uniqueDanceStyles = {};
          });
          return;
        }

        final client = http.Client();
        final request = http.Request(
          'POST',
          Uri.parse('http://147.93.19.17:5002/api/dance-styles/byIds'),
        );
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({'ids': styleIds});

        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final List<dynamic> styles = jsonDecode(response.body);
          final names = styles.map((s) => s['name'].toString()).toSet();
          setState(() {
            uniqueDanceStyles = names;
          });
        } else {
          print("❌ Status Code: ${response.statusCode}");
          print("❌ Response Body: ${response.body}");
          throw Exception("Failed to fetch styles");
        }
      } else {
        throw Exception("Failed to fetch batches");
      }
    } catch (e) {
      print('❌ Error fetching dance styles: $e');
    }
  }

  Future<void> fetchBranchesForStudio() async {
    try {
      print('🔄 Fetching branches for studio: ${widget.studio.id.oid}');

      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/branches/studio/${widget.studio.id.oid}',
        ),
      );

      print('📊 Branch response status: ${response.statusCode}');
      print('📄 Branch response body: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ BranchService: Successfully fetched ${data.length} branches');

        if (data.isNotEmpty && mounted) {
          setState(() {
            branches = data.map((e) => BranchModel.fromJson(e)).toList();
            isLoadingBranches = false;
          });
          fetchBatchesForBranch();
        } else if (mounted) {
          print('⚠️ No branches found for this studio');
          setState(() {
            branches = [];
            isLoadingBranches = false;
          });
        }
      } else {
        print('❌ Failed to fetch branches: ${response.statusCode}');
        setState(() {
          branches = [];
          isLoadingBranches = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching studio branches: $e');
      setState(() {
        errorBranches = e.toString();
        isLoadingBranches = false;
      });
    }
  }

  // Future<void> fetchAllBranches() async {
  //   try {
  //     print('🔄 Trying general branches endpoint...');
  //     final response = await http.get(
  //       Uri.parse('http://147.93.19.17:5002/api/branches'),
  //     );
  //
  //     print('📊 Branch response status: ${response.statusCode}');
  //     print('📄 Branch response body: ${response.body}');
  //
  //     if (response.statusCode == 200) {
  //       final List data = jsonDecode(response.body);
  //
  //       // 🔑 Safely extract studioId (handles ObjectId or string)
  //       final studioBranches = data.where((branch) {
  //         final id = branch['studioId'];
  //         final studioId = id is Map ? id['\$oid'] : id.toString();
  //         return studioId == widget.studio.id.oid;
  //       }).toList();
  //
  //       if (mounted) {
  //         setState(() {
  //           branches = studioBranches.map((e) => BranchModel.fromJson(e)).toList();
  //           isLoadingBranches = false;
  //         });
  //         if (branches.isNotEmpty) fetchBatchesForBranch();
  //       }
  //     } else {
  //       print('❌ Failed to fetch branches: ${response.statusCode}');
  //       setState(() {
  //         branches = [];
  //         isLoadingBranches = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('❌ Error fetching all branches: $e');
  //     setState(() {
  //       errorBranches = e.toString();
  //       isLoadingBranches = false;
  //     });
  //   }
  // }

  Future<void> fetchBatchesForBranch() async {
    setState(() {
      isLoadingBatches = true;
      errorBatches = null;
    });

    try {
      print(
        '🔄 Fetching batches for studio: ${widget.studio.id.oid}, branch: ${branches[selectedBranchIndex].id}',
      );

      // If using a default branch, fetch all batches for the studio
      if (branches[selectedBranchIndex].id.startsWith('default-')) {
        print('🔄 Using default branch, fetching all studio batches');
        await fetchBatchesForStudio();
        return;
      }

      // Try the batch service first
      final result = await BatchService.getBatchesByStudioAndBranch(
        widget.studio.id.oid,
        branches[selectedBranchIndex].id,
      );

      if (result.isNotEmpty) {
        setState(() {
          batches = result;
          isLoadingBatches = false;
        });
        print('✅ Fetched ${result.length} batches using BatchService');
      } else {
        print('⚠️ No batches found using BatchService, trying direct API call');
        // Fallback to direct API call
        await fetchBatchesDirectly();
      }
    } catch (e) {
      print('❌ BatchService failed: $e');
      // Fallback to direct API call
      await fetchBatchesDirectly();
    }
  }

  Future<void> fetchBatchesDirectly() async {
    try {
      print('🔄 Trying direct API call for batches...');
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/batches/filter?studioId=${widget.studio.id.oid}&branch=${branches[selectedBranchIndex].id}',
        ),
      );

      print('📊 Direct batch response status: ${response.statusCode}');
      print('📄 Direct batch response body: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ Fetched ${data.length} batches directly');

        if (data.isNotEmpty && mounted) {
          setState(() {
            batches = data.map((e) => BatchModel.fromJson(e)).toList();
            isLoadingBatches = false;
          });
        } else if (mounted) {
          print('⚠️ No batches found for this branch');
          setState(() {
            batches = [];
            isLoadingBatches = false;
          });
        }
      } else {
        print('❌ Direct batch fetch failed: ${response.statusCode}');
        print('📄 Response: ${response.body}');

        // Try without branch filter
        await fetchBatchesWithoutBranchFilter();
      }
    } catch (e) {
      print('❌ Error in direct batch fetch: $e');
      await fetchBatchesWithoutBranchFilter();
    }
  }

  Future<void> fetchBatchesWithoutBranchFilter() async {
    try {
      print('🔄 Trying to fetch batches without branch filter...');
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/batches/filter?studioId=${widget.studio.id.oid}',
        ),
      );

      print(
        '📊 No branch filter batch response status: ${response.statusCode}',
      );
      print('📄 No branch filter batch response body: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ Fetched ${data.length} batches without branch filter');

        if (data.isNotEmpty && mounted) {
          setState(() {
            batches = data.map((e) => BatchModel.fromJson(e)).toList();
            isLoadingBatches = false;
          });
        } else if (mounted) {
          print('⚠️ No batches found for this studio');
          setState(() {
            batches = [];
            isLoadingBatches = false;
          });
        }
      } else {
        throw Exception('Failed to load batches: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorBatches = e.toString();
          isLoadingBatches = false;
        });
      }
      print('❌ Error fetching batches without branch filter: $e');
    }
  }

  Future<void> fetchBatchesForStudio() async {
    try {
      print('🔄 Fetching all batches for studio: ${widget.studio.id.oid}');
      final response = await http.get(
        Uri.parse(
          'http://147.93.19.17:5002/api/batches/filter?studioId=${widget.studio.id.oid}',
        ),
      );

      print('📊 Studio batch response status: ${response.statusCode}');
      print('📄 Studio batch response body: ${response.body}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('✅ Fetched ${data.length} batches for studio');

        if (data.isNotEmpty && mounted) {
          setState(() {
            batches = data.map((e) => BatchModel.fromJson(e)).toList();
            isLoadingBatches = false;
          });
        } else if (mounted) {
          print('⚠️ No batches found for this studio');
          setState(() {
            batches = [];
            isLoadingBatches = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load studio batches: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorBatches = e.toString();
          isLoadingBatches = false;
        });
      }
      print('❌ Error fetching studio batches: $e');
    }
  }

  /// Helper to get initials for batch image placeholder
  String getBatchInitial(BatchModel batch) {
    String? styleName = batch.styleName;
    String? trainerName = batch.trainerName ?? batch.trainer;
    if (styleName != null && styleName.isNotEmpty) {
      return styleName.trim()[0].toUpperCase();
    } else if (trainerName != null && trainerName.isNotEmpty) {
      return trainerName.trim()[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final studio = currentStudio;

    return Scaffold(
      appBar: AppBar(
        title: Text(studio.studioName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await fetchLatestStudioData();
              await fetchBranchesForStudio();
              await fetchStudioOwner();
              await fetchDanceStylesFromStudio();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchLatestStudioData();
          await fetchBranchesForStudio();
          await fetchStudioOwner();
          await fetchDanceStylesFromStudio();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: studio.studioPhotos.isEmpty
                  ? Container(
                      height: 250,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.store,
                        size: 60,
                        color: Colors.grey,
                      ),
                    )
                  : SizedBox(
                      height: 250,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemCount: studio.studioPhotos.length,
                            itemBuilder: (context, index) {
                              final photoUrl = getFullImageUrl(
                                studio.studioPhotos[index],
                              );
                              return GestureDetector(
                                onTap: () => _openPhotoViewer(
                                  context,
                                  studio.studioPhotos
                                      .map((p) => getFullImageUrl(p))
                                      .toList(),
                                  index,
                                ),
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 40,
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                          // Dot indicators
                          if (studio.studioPhotos.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  studio.studioPhotos.length,
                                  (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: _currentPage == index ? 20 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _currentPage == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Left arrow button
                          if (studio.studioPhotos.length > 1)
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_currentPage > 0) {
                                      _pageController.previousPage(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Right arrow button
                          if (studio.studioPhotos.length > 1)
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_currentPage <
                                        studio.studioPhotos.length - 1) {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Studio Name + Rating
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Studio Name"),
                                  content: Text(studio.studioName),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Close"),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Text(
                              studio.studioName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                studio.averageRating.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // About & Contact
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(studio.studioIntroduction),
                    const SizedBox(height: 24),
                    const Text(
                      'Contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(studio.contactNumber),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(studio.registeredAddress),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(studio.contactEmail),
                    ),
                    if (studio.studioWebsite != null)
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(studio.studioWebsite!),
                      ),

                    const SizedBox(height: 24),
                    const Text(
                      'Branches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isLoadingBranches)
                      const Center(child: CircularProgressIndicator())
                    else if (errorBranches != null)
                      Text('Error: $errorBranches')
                    else if (branches.isEmpty)
                      const Center(
                        child: Text(
                          '⚠️ No branches found for this studio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else ...[
                      // 🔵 Branch Selection Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(branches.length, (index) {
                          final isSelected = selectedBranchIndex == index;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedBranchIndex = index;
                              });
                              fetchBatchesForBranch();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3A5ED4)
                                    : const Color(0xFFE5EDF5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                branches[index].name,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // Branch info rows
                      _branchInfoRow(
                        icon: Icons.location_city_outlined,
                        text: branches[selectedBranchIndex].address,
                      ),
                      const SizedBox(height: 10),
                      _branchInfoRow(
                        icon: Icons.phone_outlined,
                        text:
                            branches[selectedBranchIndex].contactNo ??
                            'Not available',
                      ),
                      const SizedBox(height: 10),
                      branches[selectedBranchIndex].mapLink.isNotEmpty
                          ? GestureDetector(
                              onTap: () async {
                                final url =
                                    branches[selectedBranchIndex].mapLink;
                                final uri = Uri.parse(url);
                                if (await launcher.canLaunchUrl(uri)) {
                                  await launcher.launchUrl(uri);
                                }
                              },
                              child: _branchInfoRow(
                                icon: Icons.map_outlined,
                                text: 'View on Map',
                                isLink: true,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],

                    const SizedBox(height: 24),
                    const Text(
                      'Dance Styles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: uniqueDanceStyles.isNotEmpty
                          ? Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: uniqueDanceStyles
                                  .map(
                                    (style) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE5EDF5,
                                        ), // subtle light background
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        style,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF222B45), // dark text
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : const Text(
                              "No styles yet",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Ratings Section (Design Match, star color #369EFF)
                    buildRatingsSection(studio),
                    const SizedBox(height: 24),

                    // Owner Section (leave as is)
                    const Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (studioOwner != null)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (studioOwner!['profilePhoto'] != null &&
                                  studioOwner!['profilePhoto']
                                      .toString()
                                      .isNotEmpty)
                              ? NetworkImage(
                                  UploadService.fullUrl(
                                    studioOwner!['profilePhoto'],
                                  ), // ✅ FIXED
                                )
                              : null,
                          child:
                              (studioOwner!['profilePhoto'] == null ||
                                  studioOwner!['profilePhoto']
                                      .toString()
                                      .isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          "${studioOwner!['firstName']} ${studioOwner!['lastName']}",
                        ),
                        subtitle: const Text('Owner'),
                      )
                    else
                      const Text('Loading owner info...'),

                    const SizedBox(height: 24),
                    const Text(
                      'Available Batches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoadingBatches)
                      const Center(child: CircularProgressIndicator())
                    else if (errorBatches != null)
                      Text("Error: $errorBatches")
                    else if (batches.isEmpty)
                      const Text("No batches available")
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: batches.length,
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          final initial = getBatchInitial(batch);
                          final bgColor =
                              _initialColors[index % _initialColors.length];
                          return GestureDetector(
                            onTap: () async {
                              try {
                                print(
                                  '🎯 Navigating to batch detail from studio screen...',
                                );
                                print('📦 Batch: ${batch.batchName}');
                                print(
                                  '🏢 Branch: ${branches[selectedBranchIndex].name}',
                                );

                                final batchModel = batch;

                                final branchModel =
                                    branches[selectedBranchIndex];

                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BatchDetailScreen(
                                      batch: batchModel,
                                      branch: branchModel,
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  setState(() {}); // 🔥 refresh UI
                                }
                              } catch (e) {
                                print('❌ Error navigating to batch detail: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error loading batch details: ${e.toString()}',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image Placeholder on the left with seats available label
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          child:
                                              (batch.branchObject != null &&
                                                  batch.branchObject!.image !=
                                                      null &&
                                                  batch
                                                      .branchObject!
                                                      .image!
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  'http://147.93.19.17:5002${batch.branchObject!.image}',
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          width: 100,
                                                          height: 100,
                                                          color: bgColor,
                                                          child: Center(
                                                            child: Text(
                                                              initial,
                                                              style: const TextStyle(
                                                                fontSize: 40,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                )
                                              : Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: bgColor,
                                                  child: Center(
                                                    child: Text(
                                                      initial,
                                                      style: const TextStyle(
                                                        fontSize: 40,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        // Seats left label at the bottom with full width
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF3A5ED4),
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(
                                                  8.0,
                                                ),
                                                bottomRight: Radius.circular(
                                                  8.0,
                                                ),
                                              ),
                                            ),

                                            child: Center(
                                              child: Text(
                                                // Calculate seats left and show "Full" if none remaining
                                                batch.capacity -
                                                            batch
                                                                .enrolledStudents
                                                                .length >
                                                        0
                                                    ? '${batch.capacity - batch.enrolledStudents.length} seats left'
                                                    : 'Full',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Details on the right
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Dance Style and Level
                                          // Style + Level
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${batch.styleName} • ${batch.levelName}',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                                  softWrap: true,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines:
                                                      1, // keep this to 1 if you don’t want style+level wrapping
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Branch Name (Area)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  batch.branchObject?.name ??
                                                      'Unknown Branch',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                  softWrap: true,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines:
                                                      1, // 1 line with "..." if too long
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Days
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  batch.days.join(', '),
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                  softWrap:
                                                      true, // allows wrapping to next line
                                                  overflow: TextOverflow
                                                      .ellipsis, // adds "..." if still too long
                                                  maxLines:
                                                      2, // at most 2 lines
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Price
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.currency_rupee,
                                                size: 16,
                                                color: Color(0xFF3A5ED4),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${batch.fee}/-',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                              ),
                                            ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRatingsSection(StudioModel studio) {
    final rating = studio.averageRating.toDouble() ?? 0.0;
    final total = studio.totalReviews ?? 0;
    final breakdown = studio.ratingBreakdown ?? {};
    percent(int count) => total > 0 ? (count / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ratings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    final filled = rating >= index + 1;
                    final half =
                        !filled && rating > index && rating < index + 1;
                    return Icon(
                      filled
                          ? Icons.star
                          : half
                          ? Icons.star_half
                          : Icons.star_border,
                      color: Color(0xFF369EFF), // Updated star color
                      size: 28,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total reviews',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                children: [
                  for (int star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              '$star',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: total > 0
                                  ? (breakdown['$star'] ?? 0) / total
                                  : 0.0,
                              backgroundColor: const Color(0xFFE5EDF5),
                              color: const Color(0xFF369EFF),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${percent(breakdown['$star'] ?? 0)}%',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _branchInfoRow({
    required IconData icon,
    required String text,
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3A5ED4)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isLink ? const Color(0xFF3A5ED4) : Colors.black87,
              decoration: isLink
                  ? TextDecoration.underline
                  : TextDecoration.none,
              fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

// Photo viewer screen
class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});
  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.photos[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 60,
                    ),
                  ),
                ),
              );
            },
          ),
          // X close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Counter  e.g. "2 / 5"
          if (widget.photos.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          // Dot indicators
          if (widget.photos.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
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
