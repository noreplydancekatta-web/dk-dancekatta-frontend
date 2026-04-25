import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_select_flutter/multi_select_flutter.dart';

import '../models/user_model.dart';
import '../models/batch_model.dart';
import '../models/branch_model.dart';

import 'home_screen.dart';
import 'batch_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  final UserModel user;
  const ExploreScreen({super.key, required this.user});

  @override
  State createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isValidStudio(dynamic studioId) {
    if (studioId == null) return false;
    return _studioList.any((s) => s['_id']?.toString() == studioId.toString());
  }

  bool _isValidBranch(dynamic branch) {
    if (branch == null) return false;

    if (branch is Map && branch['_id'] != null) {
      return _branchIdMap.containsKey(branch['_id'].toString());
    }

    if (branch is String) {
      return _branchIdMap.containsKey(branch);
    }

    return false;
  }

  bool isValidObjectId(String id) {
    return id.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(id);
  }

  final Map<String, GlobalKey<FormFieldState>> _filterKeys = {
    "Style": GlobalKey<FormFieldState>(),
    "Level": GlobalKey<FormFieldState>(),
    "Studio": GlobalKey<FormFieldState>(),
    "Area": GlobalKey<FormFieldState>(),
    "Days": GlobalKey<FormFieldState>(),
  };

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<String> _selectedStyles = [];
  List<String> _selectedLevels = [];
  List<String> _selectedStudios = [];
  List<String> _selectedLocations = [];
  List<String> _selectedDays = [];
  List<String> _selectedAreas = [];

  List<Map<String, dynamic>> _styleList = [];
  List<Map<String, dynamic>> _levelList = [];
  List<Map<String, dynamic>> _studioList = [];
  List<Map<String, dynamic>> _branchList = [];
  Map<String, Map<String, dynamic>> _branchIdMap = {};

  List<String> _daysList = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];

  Future<List<DanceClass>> _danceClassesFuture = Future.value([]);

  final String baseUrl = 'http://147.93.19.17:5002';

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
    _fetchFilters().then((_) {
      fetchBranches().then((_) {
        setState(() {
          _danceClassesFuture = fetchDanceClasses();
        });
      });
    });
  }

  Future<void> _refreshAll() async {
    await _fetchFilters();
    await fetchBranches();
    setState(() {
      _danceClassesFuture = fetchDanceClasses();
    });
  }

  void updateBatchSeats(String batchId, int newSeatCount) {
    setState(() {
      _danceClassesFuture = _danceClassesFuture.then((classes) {
        return classes.map((cls) {
          if (cls.batchData['_id'] == batchId) {
            // Update enrolled_students length
            final updatedBatchData = Map<String, dynamic>.from(cls.batchData);
            updatedBatchData['enrolled_students'] = List.filled(
              newSeatCount,
              'dummy',
            ); // adjust as needed
            return DanceClass.fromJson(updatedBatchData);
          }
          return cls;
        }).toList();
      });
    });
  }

  Future _fetchFilters() async {
    try {
      print('🔄 Fetching filters...');
      final futures = await Future.wait([
        http.get(Uri.parse('$baseUrl/api/dance-styles')),
        http.get(Uri.parse('$baseUrl/api/filters/levels')),
        http.get(Uri.parse('$baseUrl/api/filters/studios')),
      ]);

      final styleRes = futures[0];
      final levelRes = futures[1];
      final studioRes = futures[2];

      if (styleRes.statusCode == 200) {
        _styleList = List<Map<String, dynamic>>.from(
          json.decode(styleRes.body),
        );
        print('✅ Fetched ${_styleList.length} styles');
        print(
          '📋 Available styles: ${_styleList.map((s) => s['name']).toList()}',
        );
      } else {
        print('❌ Style fetch failed: ${styleRes.statusCode}');
        _styleList = [];
      }

      if (levelRes.statusCode == 200) {
        _levelList = List<Map<String, dynamic>>.from(
          json.decode(levelRes.body),
        );
        print('✅ Fetched ${_levelList.length} levels');
        print(
          '📋 Available levels: ${_levelList.map((l) => l['name']).toList()}',
        );
      } else {
        print('❌ Level fetch failed: ${levelRes.statusCode}');
        _levelList = [];
      }

      if (studioRes.statusCode == 200) {
        _studioList = List<Map<String, dynamic>>.from(
          json.decode(studioRes.body),
        );
        print('✅ Fetched ${_studioList.length} studios');
        print(
          '📋 Available studios: ${_studioList.map((s) => s['studioName']).toList()}',
        );
      } else {
        print('❌ Studio fetch failed: ${studioRes.statusCode}');
        _studioList = [];
      }

      // Try to fetch days, fallback if error
      try {
        final daysRes = await http.get(Uri.parse('$baseUrl/api/filters/days'));
        if (daysRes.statusCode == 200) {
          _daysList = List<String>.from(json.decode(daysRes.body));
          print('✅ Fetched ${_daysList.length} days: $_daysList');
        } else {
          print('❌ Days fetch failed: ${daysRes.statusCode}');
          _daysList = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
        }
      } catch (e) {
        print('❌ Days fetch error: $e');
        _daysList = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
      }
    } catch (e) {
      print("❌ Failed to load filters: $e");
      _daysList = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
    }
  }

  Future fetchBranches() async {
    try {
      print('🔄 Fetching branches...');
      final response = await http.get(Uri.parse('$baseUrl/api/branches'));
      if (response.statusCode == 200) {
        final branches = List<Map<String, dynamic>>.from(
          json.decode(response.body),
        );
        setState(() {
          _branchList = branches;
          _branchIdMap = {for (var b in branches) b['_id']: b};
        });
        print('✅ Fetched ${_branchList.length} branches');
        print(
          '📋 Available branch areas: ${_branchList.map((b) => b['area']).toList()}',
        );
      } else {
        setState(() {
          _branchList = [];
          _branchIdMap = {};
        });
        print('❌ Branch fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _branchList = [];
        _branchIdMap = {};
      });
      print('❌ Branch fetch error: $e');
    }
  }

  String getBranchAddress(dynamic branchData) {
    try {
      if (branchData is String) {
        return branchData.isNotEmpty ? branchData : 'Unknown Location';
      }
      if (branchData is Map) {
        return branchData['branchAddress']?.toString() ?? 'Unknown Location';
      }
      if (branchData is String && branchData.isNotEmpty) {
        final branch = _branchList.firstWhere(
          (b) => b['_id'] == branchData || b['branchAddress'] == branchData,
          orElse: () => {},
        );
        return branch['branchAddress']?.toString() ?? branchData;
      }
      return 'Unknown Location';
    } catch (e) {
      print('⚠️ Error getting branch address: $e');
      return 'Unknown Location';
    }
  }

  String getBranchName(dynamic branchData) {
    try {
      if (branchData is String) {
        return branchData.isNotEmpty ? branchData : 'Unknown Branch';
      }
      if (branchData is Map) {
        return branchData['branchName']?.toString() ?? 'Unknown Branch';
      }
      if (branchData is String && branchData.isNotEmpty) {
        final branch = _branchList.firstWhere(
          (b) => b['_id'] == branchData || b['branchAddress'] == branchData,
          orElse: () => {},
        );
        return branch['branchName']?.toString() ?? 'Unknown Branch';
      }
      return 'Unknown Branch';
    } catch (e) {
      print('⚠️ Error getting branch name: $e');
      return 'Unknown Branch';
    }
  }

  Future<List<DanceClass>> fetchDanceClasses() async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/batches');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        debugPrint('📦 Total batches from API: ${data.length}');

        final now = DateTime.now();

        // Filter out only batches that have a toDate AND it's clearly in the past.
        // Batches with no toDate / unparseable toDate are shown (benefit of the doubt).
        data = data.where((batch) {
          final rawDate = batch['toDate'];

          if (rawDate == null) return true;

          DateTime? endDate;

          if (rawDate is String) {
            endDate = DateTime.tryParse(rawDate);
          }

          // If parsing fails → still show
          if (endDate == null) return true;

          // Allow even today's classes
          return endDate.isAfter(now.subtract(Duration(days: 1)));
        }).toList();

        debugPrint('✅ Batches after date filter: ${data.length}');

        return data.map((e) => DanceClass.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load batches');
      }
    } catch (e) {
      debugPrint("Error fetching dance classes: $e");
      return [];
    }
  }

  /// Helper to get initials for batch image placeholder
  String getBatchInitial(Map batchData) {
    String? styleName = batchData['style'] is Map ? batchData['style']['name']?.toString() : batchData['style']?.toString();
    if (styleName == null || styleName.isEmpty) {
      styleName = batchData['styleName']?.toString();
    }
    String? trainerName = batchData['trainerName']?.toString() ?? (batchData['trainer'] is Map ? batchData['trainer']['name']?.toString() ?? batchData['trainer']['firstName']?.toString() : batchData['trainer']?.toString());
    if (styleName != null && styleName.isNotEmpty) {
      return styleName.trim()[0].toUpperCase();
    } else if (trainerName != null && trainerName.isNotEmpty) {
      return trainerName.trim()[0].toUpperCase();
    }
    return '?';
  }

  Widget buildSelectedItemChips() {
    final combinedSelected = [
      ..._selectedStyles,
      ..._selectedLevels,
      ..._selectedStudios,
      ..._selectedLocations,
      ..._selectedDays,
      ..._selectedAreas,
    ];
    if (combinedSelected.isEmpty) return SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft, // Left-alignment of chips
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: combinedSelected.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: Text(item, style: TextStyle(fontSize: 14)),
                  shape: StadiumBorder(),
                  selected: true,
                  backgroundColor: Colors.white,
                  selectedColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    color: Theme.of(context).primaryColor,
                  ),
                  onDeleted: () {
                    setState(() {
                      // Determine which filter this item belongs to and reset its key
                      if (_selectedStyles.contains(item)) {
                        _selectedStyles.remove(item);
                        _filterKeys['Style'] = GlobalKey<FormFieldState>();
                      }
                      if (_selectedLevels.contains(item)) {
                        _selectedLevels.remove(item);
                        _filterKeys['Level'] = GlobalKey<FormFieldState>();
                      }
                      if (_selectedStudios.contains(item)) {
                        _selectedStudios.remove(item);
                        _filterKeys['Studio'] = GlobalKey<FormFieldState>();
                      }
                      if (_selectedLocations.contains(item)) {
                        _selectedLocations.remove(item);
                      }
                      if (_selectedDays.contains(item)) {
                        _selectedDays.remove(item);
                        _filterKeys['Days'] = GlobalKey<FormFieldState>();
                      }
                      if (_selectedAreas.contains(item)) {
                        _selectedAreas.remove(item);
                        _filterKeys['Area'] = GlobalKey<FormFieldState>();
                      }
                      _danceClassesFuture = fetchDanceClasses();
                    });
                  },
                  onSelected: (_) {}, // no-op
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectFilter(
    String label,
    List options,
    List selectedValues,
    ValueChanged<List<String>> onChanged,
  ) {
    final items = options
        .map((option) => MultiSelectItem(option.toString(), option.toString()))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selectedValues.isNotEmpty
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          // Remove ALL input decoration borders
          inputDecorationTheme: InputDecorationTheme(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            // Remove content padding to prevent extra spacing
            contentPadding: EdgeInsets.zero,
          ),
          // Remove divider to prevent any lines
          dividerColor: Colors.transparent,
        ),
        child: MultiSelectDialogField(
          key: _filterKeys[label],
          items: items,
          initialValue: selectedValues,
          searchable: true,
          dialogHeight: 300,
          // Remove any decoration from the field itself
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent, width: 0),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select $label',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear All'),
                onPressed: () {
                  setState(() {
                    if (label == 'Style') _selectedStyles.clear();
                    if (label == 'Level') _selectedLevels.clear();
                    if (label == 'Studio') _selectedStudios.clear();
                    if (label == 'Area') _selectedAreas.clear();
                    if (label == 'Days') _selectedDays.clear();
                    _filterKeys[label] = GlobalKey<FormFieldState>();
                    _danceClassesFuture = fetchDanceClasses();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          buttonText: Text(
            selectedValues.isEmpty
                ? label
                : '${selectedValues.length} selected',
            style: TextStyle(
              color: selectedValues.isNotEmpty
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade800,
              fontSize: 14,
              fontWeight: selectedValues.isNotEmpty
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          buttonIcon: Icon(
            Icons.arrow_drop_down,
            color: selectedValues.isNotEmpty
                ? Theme.of(context).primaryColor
                : Colors.grey.shade700,
          ),
          onConfirm: (values) {
            onChanged(values.cast<String>());
            setState(() {
              _danceClassesFuture = fetchDanceClasses();
            });
          },
          chipDisplay: MultiSelectChipDisplay.none(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Explore'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: widget.user),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for dance classes',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFE5EDF5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_styleList.isNotEmpty)
                  _buildMultiSelectFilter(
                    'Style',
                    _styleList.map((s) => s['name'].toString()).toList(),
                    _selectedStyles,
                    (values) {
                      setState(() {
                        _selectedStyles = values;
                      });
                    },
                  ),
                if (_styleList.isNotEmpty) const SizedBox(width: 8),
                if (_levelList.isNotEmpty)
                  _buildMultiSelectFilter(
                    'Level',
                    _levelList.map((l) => l['name'].toString()).toList(),
                    _selectedLevels,
                    (values) {
                      setState(() {
                        _selectedLevels = values;
                      });
                    },
                  ),
                if (_levelList.isNotEmpty) const SizedBox(width: 8),
                if (_studioList.isNotEmpty)
                  _buildMultiSelectFilter(
                    'Studio',
                    _studioList.map((s) => s['studioName'].toString()).toList(),
                    _selectedStudios,
                    (values) {
                      setState(() {
                        _selectedStudios = values;
                      });
                    },
                  ),
                if (_studioList.isNotEmpty) const SizedBox(width: 8),
                if (_branchList.isNotEmpty)
                  _buildMultiSelectFilter(
                    'Area',
                    _branchList
                        .map((b) => b['area']?.toString() ?? 'Unknown Location')
                        .toSet()
                        .toList(),
                    _selectedAreas,
                    (values) {
                      setState(() {
                        _selectedAreas = values;
                      });
                    },
                  ),
                if (_branchList.isNotEmpty) const SizedBox(width: 8),
                if (_daysList.isNotEmpty)
                  _buildMultiSelectFilter('Days', _daysList, _selectedDays, (
                    values,
                  ) {
                    setState(() {
                      _selectedDays = values;
                    });
                  }),
              ],
            ),
          ),
          buildSelectedItemChips(),
          if (_selectedStyles.isNotEmpty ||
              _selectedLevels.isNotEmpty ||
              _selectedStudios.isNotEmpty ||
              _selectedLocations.isNotEmpty ||
              _selectedDays.isNotEmpty ||
              _selectedAreas.isNotEmpty ||
              _searchQuery.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 4),
                child: TextButton.icon(
                  icon: Icon(Icons.clear_all, color: Colors.red),
                  label: Text(
                    'Clear All Filters',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedStyles.clear();
                      _selectedLevels.clear();
                      _selectedStudios.clear();
                      _selectedLocations.clear();
                      _selectedDays.clear();
                      _selectedAreas.clear();
                      _searchController.clear();
                      _searchQuery = '';
                      _filterKeys.forEach(
                        (k, v) => _filterKeys[k] = GlobalKey(),
                      );
                      _danceClassesFuture = fetchDanceClasses();
                    });
                  },
                ),
              ),
            ),
          if (_branchList.isEmpty && _daysList.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _branchList.isEmpty && _daysList.isEmpty
                          ? 'Location and Days filters are temporarily unavailable'
                          : _branchList.isEmpty
                          ? 'Location filter is temporarily unavailable'
                          : 'Days filter is temporarily unavailable',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<DanceClass>>(
              future: _danceClassesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  String errorMessage = 'Error loading classes';
                  String errorDetails = '${snapshot.error}';

                  if (errorDetails.contains('400')) {
                    errorMessage = 'Filter Error';
                    errorDetails =
                        'The selected filters may contain invalid data. Please try selecting different filters or refresh the page.';
                  } else if (errorDetails.contains('404')) {
                    errorMessage = 'Service Unavailable';
                    errorDetails =
                        'Some filter options are currently unavailable. Please try again later.';
                  } else if (errorDetails.contains(
                    'Failed to load dance classes',
                  )) {
                    errorMessage = 'Connection Error';
                    errorDetails =
                        'Unable to connect to the server. Please check your internet connection and try again.';
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            errorDetails,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _danceClassesFuture = fetchDanceClasses();
                                });
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStyles.clear();
                                  _selectedLevels.clear();
                                  _selectedStudios.clear();
                                  _selectedLocations.clear();
                                  _selectedDays.clear();
                                  _selectedAreas.clear();
                                  _danceClassesFuture = fetchDanceClasses();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No classes found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search terms',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                Future<void> refreshBatchSeats(String batchId) async {
                  try {
                    print('🔄 Refreshing batch seats for batch ID: $batchId');
                    final response = await http.get(
                      Uri.parse('$baseUrl/api/batches'),
                    );

                    if (response.statusCode == 200) {
                      final List<dynamic> batches = jsonDecode(response.body);

                      // Find the updated batch
                      final batchData = batches.firstWhere(
                        (b) => b['_id'] == batchId,
                        orElse: () => null,
                      );

                      if (batchData != null) {
                        setState(() async {
                          // Update the corresponding DanceClass in the Future
                          _danceClassesFuture = _danceClassesFuture.then((
                            classes,
                          ) {
                            return classes.map((cls) {
                              if (cls.batchData['_id'] == batchId) {
                                final updatedBatch =
                                    Map<String, dynamic>.from(cls.batchData)
                                      ..['enrolled_students'] =
                                          batchData['enrolled_students'] ?? [];
                                return DanceClass.fromJson(updatedBatch);
                              }
                              return cls;
                            }).toList();
                          });
                        });
                        print('✅ Updated seats for batch $batchId');
                      } else {
                        print('❌ Batch ID not found in batch list');
                      }
                    } else {
                      print(
                        '❌ Failed to fetch batches: ${response.statusCode}',
                      );
                    }
                  } catch (e) {
                    print('⚠️ Error refreshing batch seats: $e');
                  }
                }

                final filteredClasses = (snapshot.data ?? []).where((cls) {
                  final query = _searchQuery.toLowerCase();

                  final matchesSearch =
                      query.isEmpty ||
                      cls.title.toLowerCase().contains(query) ||
                      cls.studio.toLowerCase().contains(query) ||
                      cls.area.toLowerCase().contains(query);

                  final matchesArea =
                      _selectedAreas.isEmpty ||
                      _selectedAreas.any(
                        (a) => cls.area.toLowerCase().contains(a.toLowerCase()),
                      );

                  final matchesStudio =
                      _selectedStudios.isEmpty ||
                      _selectedStudios.any(
                        (s) =>
                            cls.studio.toLowerCase().contains(s.toLowerCase()),
                      );

                  final matchesDays =
                      _selectedDays.isEmpty ||
                      _selectedDays.any(
                        (d) => cls.days.toLowerCase().contains(d.toLowerCase()),
                      );

                  return matchesSearch &&
                      matchesArea &&
                      matchesStudio &&
                      matchesDays;
                }).toList();
                // ✅ ADD HERE
                print("API COUNT: ${snapshot.data?.length}");
                print("FILTERED COUNT: ${filteredClasses.length}");
                if (filteredClasses.isEmpty) {
                  if (_searchQuery.isNotEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No classes match your search',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try different search terms',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No classes found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      FocusScope.of(context).unfocus(); // hides keyboard
                      return false;
                    },
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredClasses.length,
                      itemBuilder: (context, index) {
                        final cls = filteredClasses[index];
                        final initial = getBatchInitial(cls.batchData);
                        final bgColor =
                            _initialColors[index % _initialColors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8,
                          ),

                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () async {
                                try {
                                  final validatedBatchData =
                                      Map<String, dynamic>.from(cls.batchData);

                                  final batchModel = BatchModel.fromJson(
                                    validatedBatchData,
                                  );

                                  final branchModel = BranchModel(
                                    id:
                                        (cls.batchData['branch'] is Map ? cls.batchData['branch']['_id']?.toString() : cls.batchData['branch']?.toString()) ??
                                        '',
                                    name:
                                        cls.batchData['branchName']
                                            ?.toString() ??
                                        'Unknown Branch',
                                    address:
                                        cls.batchData['branchAddress']
                                            ?.toString() ??
                                        'Unknown Location',
                                    area:
                                        cls.batchData['area']?.toString() ??
                                        'Unknown Location',
                                    mapLink: '',
                                    contactNo:
                                        cls.batchData['branchContactNo']
                                            ?.toString() ??
                                        '',
                                  );

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
                                    setState(() {});
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error loading batch details: ${e.toString()}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 16,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.bottomLeft,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: Colors.grey.shade300,
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (cls.batchData['image'] !=
                                                        null &&
                                                    cls
                                                        .batchData['image']
                                                        .isNotEmpty)
                                                  Image.network(
                                                    cls.batchData['image'],
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => Container(
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
                                                        ),
                                                  )
                                                else
                                                  Container(
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
                                                if (cls.batchData['capacity'] !=
                                                        null &&
                                                    cls.batchData['enrolled_students'] !=
                                                        null &&
                                                    (cls.batchData['capacity'] -
                                                            (cls.batchData['enrolled_students']
                                                                    as List)
                                                                .length) >
                                                        0)
                                                  Align(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    child: Container(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              bottom:
                                                                  Radius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Text(
                                                        // Calculate seats left and show "Full" if none remaining
                                                        (cls.batchData['capacity']
                                                                        as int) -
                                                                    (cls.batchData['enrolled_students']
                                                                            as List)
                                                                        .length >
                                                                0
                                                            ? '${(cls.batchData['capacity'] as int) - (cls.batchData['enrolled_students'] as List).length} seats left'
                                                            : 'Full',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cls.title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                cls.studio,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                cls.area,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                cls.days,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '₹ ${cls.price}/-',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ), // ← closes Row
                            ), // ← closes InkWell
                          ), // ← closes Container
                        ); // ← closes Padding
                      }, // ← closes itemBuilder
                    ), // ← closes ListView.builder
                  ), // ← closes NotificationListener
                ); // ← closes RefreshIndicator
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-level DanceClass model
class DanceClass {
  final String title;
  final String studio;
  final String location;
  final String days;
  final String price;
  final String area;
  final Map<String, dynamic> batchData;

  DanceClass({
    required this.title,
    required this.studio,
    required this.location,
    required this.days,
    required this.price,
    required this.area,
    required this.batchData,
  });

  factory DanceClass.fromJson(Map<String, dynamic> json) {
    return DanceClass(
      title: json['batchName'] ?? 'No Name',
      studio: json['studioName'] ?? 'Unknown Studio',
      location: json['branch'] is String ? json['branch'] : (json['branchName'] ?? 'Unknown Location'),
      days: json['days'] is List ? (json['days'] as List).join(', ') : (json['days']?.toString() ?? 'No days specified'),
      price: json['fee']?.toString() ?? '0',
      area: json['area'] ?? json['branchArea'] ?? 'Unknown Location',
      batchData: Map<String, dynamic>.from(json),
    );
  }
}
