import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../services/team_service.dart';
import '../services/poi_service.dart';
import '../services/route_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  String? _activeTeamId;
  String? _activeTeamName;
  bool _isSharing = false;
  bool _followMe = true;
  LatLng? _myLocation;
  double _accuracy = 0; // meters

  // Route planning
  List<LatLng> _routePolyline = [];
  List<Map<String, dynamic>> _routeWaypoints = []; // {name, lat, lng}
  double _routeDistKm = 0;
  double _routeDurMin = 0;
  bool _showRoutePanel = false;

  // Member colors
  static const List<Color> _memberColors = [
    Color(0xFF1A73E8), Color(0xFF00BFA5), Color(0xFFFF6D00),
    Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFFFFEB3B),
    Color(0xFF00E5FF), Color(0xFF76FF03),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
        _accuracy = pos.accuracy;
      });
      _mapController.move(_myLocation!, 15);
      if (_accuracy > 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location accuracy: ~${_accuracy.toInt()}m (GPS may be approximate on web)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow location access to see your position on the map'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    LocationService.stopBroadcasting();
    super.dispose();
  }

  void _showAddPoiDialog() {
    if (_activeTeamId == null || _myLocation == null) return;
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = 'food';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add POI', style: GoogleFonts.inter(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PoiService.categories.entries.map((e) {
                    final isSelected = selectedCategory == e.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedCategory = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFF6D00).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? const Color(0xFFFF6D00) : Colors.transparent),
                        ),
                        child: Text('${e.value} ${e.key}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style: GoogleFonts.inter(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await PoiService.addPoi(
                  teamId: _activeTeamId!,
                  lat: _myLocation!.latitude,
                  lng: _myLocation!.longitude,
                  title: titleCtrl.text,
                  category: selectedCategory,
                  notes: notesCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPoiDetail(String poiId, Map<String, dynamic> data) {
    final emoji = PoiService.categories[data['category'] ?? 'other'] ?? '📍';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$emoji ${data['title'] ?? ''}', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((data['notes'] ?? '').isNotEmpty)
              Text(data['notes'], style: GoogleFonts.inter(color: Colors.white54)),
            const SizedBox(height: 8),
            Text('Added by ${data['addedByName'] ?? 'Unknown'}', style: GoogleFonts.inter(color: Colors.white30, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { PoiService.deletePoi(_activeTeamId!, poiId); Navigator.pop(ctx); },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _toggleSharing() {
    if (_activeTeamId == null) {
      _showTeamPicker();
      return;
    }
    setState(() => _isSharing = !_isSharing);
    if (_isSharing) {
      LocationService.startBroadcasting(_activeTeamId!);
    } else {
      LocationService.stopBroadcasting();
    }
  }

  // ════════════════════════════════════
  // TEAM PICKER
  // ════════════════════════════════════
  void _showTeamPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: TeamService.getMyTeams(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Team to Share Location',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No teams yet. Create one first!',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.54)),
                        ),
                      ),
                    )
                  else
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final members = List.from(data['members'] ?? []);
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              (data['name'] ?? 'T')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          data['name'] ?? 'Team',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${members.length} members',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 12),
                        ),
                        onTap: () {
                          setState(() {
                            _activeTeamId = doc.id;
                            _activeTeamName = data['name'];
                          });
                          Navigator.pop(ctx);
                          // Auto-start sharing
                          setState(() => _isSharing = true);
                          LocationService.startBroadcasting(doc.id);
                        },
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════
  // ROUTE PLANNING
  // ════════════════════════════════════
  Future<void> _fetchRoute() async {
    if (_routeWaypoints.length < 2) return;
    final points = _routeWaypoints.map((w) => LatLng(w['lat'], w['lng'])).toList();
    final polyline = await RouteService.getDirections(points);
    final info = await RouteService.getRouteInfo(points);
    if (mounted) {
      setState(() {
        _routePolyline = polyline;
        _routeDistKm = info['distance'] ?? 0;
        _routeDurMin = info['duration'] ?? 0;
      });
    }
  }

  void _addWaypoint(String name, double lat, double lng) {
    setState(() {
      _routeWaypoints.add({'name': name, 'lat': lat, 'lng': lng});
    });
    _fetchRoute();
  }

  void _removeWaypoint(int index) {
    setState(() { _routeWaypoints.removeAt(index); });
    if (_routeWaypoints.length >= 2) { _fetchRoute(); }
    else { setState(() { _routePolyline = []; _routeDistKm = 0; _routeDurMin = 0; }); }
  }

  void _clearRoute() {
    setState(() {
      _routeWaypoints.clear(); _routePolyline = [];
      _routeDistKm = 0; _routeDurMin = 0; _showRoutePanel = false;
    });
  }

  /// Search places using Nominatim (free OpenStreetMap geocoder)
  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.trim().length < 3) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'TravelBuddy/1.0'});
      if (resp.statusCode == 200) {
        final results = json.decode(resp.body) as List;
        return results.map<Map<String, dynamic>>((r) => {
          'name': r['display_name'] ?? '',
          'lat': double.tryParse(r['lat']?.toString() ?? '') ?? 0.0,
          'lng': double.tryParse(r['lon']?.toString() ?? '') ?? 0.0,
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  void _showAddWaypointDialog({String label = 'Add Stop'}) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    String? selectedName;
    double? selectedLat;
    double? selectedLng;
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(label, style: GoogleFonts.inter(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Search field
              TextField(
                controller: searchCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search a place...',
                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: isSearching
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA5))))
                    : null,
                  filled: true, fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 500), () async {
                    if (val.trim().length < 3) { setDlgState(() => searchResults = []); return; }
                    setDlgState(() => isSearching = true);
                    final results = await _searchPlaces(val);
                    setDlgState(() { searchResults = results; isSearching = false; });
                  });
                },
              ),
              // Search results
              if (searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (_, i) {
                      final r = searchResults[i];
                      final isSelected = selectedLat == r['lat'] && selectedLng == r['lng'];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.location_on, size: 18,
                          color: isSelected ? const Color(0xFF00BFA5) : Colors.white30),
                        title: Text(r['name'], style: GoogleFonts.inter(
                          color: isSelected ? const Color(0xFF00BFA5) : Colors.white70, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 18) : null,
                        onTap: () {
                          setDlgState(() {
                            selectedName = (r['name'] as String).split(',').first;
                            selectedLat = r['lat']; selectedLng = r['lng'];
                          });
                        },
                      );
                    },
                  ),
                ),
              // Selected place info
              if (selectedName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(selectedName!, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              // Use my location fallback
              Align(alignment: Alignment.centerLeft,
                child: TextButton.icon(icon: const Icon(Icons.my_location, size: 16, color: Color(0xFF00BFA5)),
                  label: Text('Use my location', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 12)),
                  onPressed: () {
                    if (_myLocation != null) {
                      setDlgState(() {
                        selectedName = 'My Location';
                        selectedLat = _myLocation!.latitude;
                        selectedLng = _myLocation!.longitude;
                      });
                    }
                  })),
            ])),
          ),
          actions: [
            TextButton(onPressed: () { debounce?.cancel(); Navigator.pop(ctx); },
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: selectedLat != null && selectedLng != null ? () {
                _addWaypoint(selectedName ?? 'Stop ${_routeWaypoints.length + 1}', selectedLat!, selectedLng!);
                debounce?.cancel();
                Navigator.pop(ctx);
              } : null,
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Color _colorForMember(int index) => _memberColors[index % _memberColors.length];

  // ════════════════════════════════════
  // BUILD
  // ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? const LatLng(12.9716, 77.5946), // Default: Bangalore
              initialZoom: 14,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _followMe = false);
              },
            ),
            children: [
              // Map tiles (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travelbuddy.travel_buddy',
              ),

              // Team member markers (colored per member)
              if (_activeTeamId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: LocationService.getTeamLocations(_activeTeamId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const MarkerLayer(markers: []);
                    final docs = snapshot.data!.docs;
                    final markers = <Marker>[];
                    for (int i = 0; i < docs.length; i++) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final lat = (data['lat'] as num?)?.toDouble() ?? 0;
                      final lng = (data['lng'] as num?)?.toDouble() ?? 0;
                      final speedKmh = (data['speedKmh'] as num?)?.toDouble() ?? 0;
                      final userName = data['userName'] as String? ?? '?';
                      final userPhoto = data['userPhoto'] as String? ?? '';
                      final isMe = doc.id == currentUid;
                      final color = _colorForMember(i);

                      if (isMe && _followMe) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _myLocation = LatLng(lat, lng);
                            _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
                          }
                        });
                      }

                      markers.add(Marker(
                        point: LatLng(lat, lng),
                        width: 120, height: 70,
                        child: _memberMarker(name: userName, photo: userPhoto, speed: speedKmh, isMe: isMe, color: color),
                      ));
                    }
                    return MarkerLayer(markers: markers);
                  },
                ),

              // My location accuracy circle
              if (_activeTeamId == null && _myLocation != null && _accuracy > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _myLocation!,
                      radius: _accuracy,
                      useRadiusInMeter: true,
                      color: const Color(0xFF1A73E8).withOpacity(0.1),
                      borderColor: const Color(0xFF1A73E8).withOpacity(0.3),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // My location marker (when not sharing with team)
              if (_activeTeamId == null && _myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A73E8).withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // POI markers
              if (_activeTeamId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: PoiService.getTeamPois(_activeTeamId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const MarkerLayer(markers: []);
                    final poiMarkers = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lat = (data['lat'] as num?)?.toDouble() ?? 0;
                      final lng = (data['lng'] as num?)?.toDouble() ?? 0;
                      final title = data['title'] as String? ?? '';
                      final category = data['category'] as String? ?? 'other';
                      final emoji = PoiService.categories[category] ?? '📍';
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 80,
                        height: 48,
                        child: GestureDetector(
                          onLongPress: () => _showPoiDetail(doc.id, data),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.4)),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 16)),
                              ),
                              Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    }).toList();
                    return MarkerLayer(markers: poiMarkers);
                  },
                ),

              // ── ROUTE POLYLINE ──
              if (_routePolyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _routePolyline, strokeWidth: 4, color: const Color(0xFF1A73E8)),
                ]),

              // ── WAYPOINT MARKERS ──
              if (_routeWaypoints.isNotEmpty)
                MarkerLayer(markers: _routeWaypoints.asMap().entries.map((e) {
                  final i = e.key; final w = e.value;
                  final isStart = i == 0; final isEnd = i == _routeWaypoints.length - 1;
                  final markerColor = isStart ? const Color(0xFF00BFA5) : isEnd ? Colors.redAccent : const Color(0xFFFF6D00);
                  return Marker(point: LatLng(w['lat'], w['lng']), width: 90, height: 50,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(
                        color: markerColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(isStart ? Icons.play_arrow : isEnd ? Icons.flag : Icons.circle, color: Colors.white, size: 14)),
                      Text(w['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    ]));
                }).toList()),
            ],
          ),

          // ── TOP BAR ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // Team indicator
                  if (_activeTeamId != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTeamPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isSharing ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                                color: _isSharing ? const Color(0xFF00BFA5) : Colors.white.withOpacity(0.3),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _activeTeamName ?? 'Team',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _isSharing ? 'Sharing location...' : 'Not sharing',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: _isSharing ? const Color(0xFF00BFA5) : Colors.white.withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.3)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),

          // ── BOTTOM CONTROLS ──
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Follow me button
                _mapButton(
                  icon: _followMe ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: _followMe ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.54),
                  onTap: () async {
                    setState(() => _followMe = true);
                    final pos = await LocationService.getCurrentPosition();
                    if (pos != null && mounted) {
                      setState(() {
                        _myLocation = LatLng(pos.latitude, pos.longitude);
                        _accuracy = pos.accuracy;
                      });
                      _mapController.move(_myLocation!, 15);
                    }
                  },
                ),
                const Spacer(),
                // Share location toggle
                GestureDetector(
                  onTap: _toggleSharing,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _isSharing
                          ? const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSharing ? Colors.red : const Color(0xFF1A73E8))
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSharing ? Icons.stop_rounded : Icons.share_location_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSharing ? 'Stop Sharing' : 'Share Location',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add POI button
                if (_activeTeamId != null)
                  _mapButton(
                    icon: Icons.add_location_alt_rounded,
                    color: const Color(0xFFFF6D00),
                    onTap: () => _showAddPoiDialog(),
                  ),
                const SizedBox(width: 8),
                // Plan Tour button
                _mapButton(
                  icon: Icons.route_rounded,
                  color: _showRoutePanel ? const Color(0xFF00BFA5) : Colors.white.withOpacity(0.54),
                  onTap: () => setState(() => _showRoutePanel = !_showRoutePanel),
                ),
                const Spacer(),
                // Zoom controls
                Column(
                  children: [
                    _mapButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final zoom = _mapController.camera.zoom + 1;
                        _mapController.move(_mapController.camera.center, zoom);
                      },
                    ),
                    const SizedBox(height: 8),
                    _mapButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final zoom = _mapController.camera.zoom - 1;
                        _mapController.move(_mapController.camera.center, zoom);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── ROUTE PLANNING PANEL ──
          if (_showRoutePanel)
            Positioned(
              top: 80, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.route_rounded, color: Color(0xFF00BFA5), size: 20),
                    const SizedBox(width: 8),
                    Text('Plan Tour', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_routeWaypoints.isNotEmpty)
                      GestureDetector(onTap: _clearRoute, child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => setState(() => _showRoutePanel = false),
                      child: const Icon(Icons.close, color: Colors.white38, size: 20)),
                  ]),
                  const SizedBox(height: 10),
                  ..._routeWaypoints.asMap().entries.map((e) {
                    final i = e.key; final w = e.value;
                    final isStart = i == 0; final isEnd = i == _routeWaypoints.length - 1;
                    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                      Icon(isStart ? Icons.play_circle : isEnd ? Icons.flag_circle : Icons.circle,
                        color: isStart ? const Color(0xFF00BFA5) : isEnd ? Colors.redAccent : const Color(0xFFFF6D00), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w['name'] ?? 'Stop', style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
                      GestureDetector(onTap: () => _removeWaypoint(i),
                        child: const Icon(Icons.remove_circle_outline, color: Colors.white24, size: 18)),
                    ]));
                  }),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_location_rounded, size: 16),
                      label: Text(_routeWaypoints.isEmpty ? 'Set Start' : _routeWaypoints.length == 1 ? 'Set End' : 'Add Stop',
                        style: GoogleFonts.inter(fontSize: 12)),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00BFA5),
                        side: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => _showAddWaypointDialog(
                        label: _routeWaypoints.isEmpty ? 'Set Start Point' : _routeWaypoints.length == 1 ? 'Set End Point' : 'Add Stop'),
                    )),
                  ]),
                  if (_routeDistKm > 0)
                    Padding(padding: const EdgeInsets.only(top: 10), child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF1A73E8).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        Column(children: [
                          Text('${_routeDistKm.toStringAsFixed(1)} km', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Distance', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                        ]),
                        Container(width: 1, height: 30, color: Colors.white12),
                        Column(children: [
                          Text(_routeDurMin < 60 ? '${_routeDurMin.toStringAsFixed(0)} min' : '${(_routeDurMin / 60).toStringAsFixed(1)} hr',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Duration', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                        ]),
                        Container(width: 1, height: 30, color: Colors.white12),
                        Column(children: [
                          Text('${_routeWaypoints.length}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Stops', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                        ]),
                      ]),
                    )),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════
  // WIDGETS
  // ════════════════════════════════════
  Widget _memberMarker({
    required String name,
    required String photo,
    required double speed,
    required bool isMe,
    Color color = const Color(0xFF00BFA5),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: speed > 1
                ? const Color(0xFF00BFA5)
                : const Color(0xFF424242),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            LocationService.formatSpeed(speed),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            backgroundColor: const Color(0xFF161B22),
            child: photo.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
        ),
        // Name label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isMe ? 'You' : name.split(' ').first,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF161B22).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: color ?? Colors.white.withOpacity(0.7), size: 22),
      ),
    );
  }
}
