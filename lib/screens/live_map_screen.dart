import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../services/team_service.dart';
import '../services/poi_service.dart';
import '../services/route_service.dart';
import '../services/nearby_service.dart';
import '../services/chat_service.dart';
import '../services/eta_service.dart';
import 'team_chat_screen.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _gMapController;
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
  bool _showRoutePanel = false; // kept for route info chip visibility

  // Member colors
  static const List<Color> _memberColors = [
    Color(0xFF1A73E8), Color(0xFF00BFA5), Color(0xFFFF6D00),
    Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFFFFEB3B),
    Color(0xFF00E5FF), Color(0xFF76FF03),
  ];

  // Nearby places (auto-loaded)
  List<NearbyPlace> _nearbyPlaces = [];
  bool _loadingNearby = false;

  // Unread messages
  bool _hasUnreadChat = false;
  StreamSubscription? _unreadSub;

  // Google Maps style
  int _mapTypeIndex = 0;
  static const List<MapType> _mapTypes = [
    MapType.normal,
    MapType.satellite,
    MapType.terrain,
    MapType.hybrid,
  ];
  static const List<Map<String, String>> _mapTypeLabels = [
    {'name': 'Normal', 'icon': '🗺️'},
    {'name': 'Satellite', 'icon': '🛰️'},
    {'name': 'Terrain', 'icon': '🏔️'},
    {'name': 'Hybrid', 'icon': '🌍'},
  ];

  // Team member tracking
  StreamSubscription? _teamLocationSub;
  Set<Marker> _teamMarkers = {};
  Set<Marker> _poiMarkers = {};

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
      _gMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_myLocation!, 15),
      );
      // Auto-load all nearby places within 10km
      _loadAllNearby();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow location access to see your position on the map'),
          duration: Duration(seconds: 4),
        ),
      );
    }
    // Auto-start team listeners if team is already active
    if (_activeTeamId != null) {
      _startTeamLocationListener();
      _startPoiListener();
      _startUnreadListener();
    }
  }

  /// Auto-load all nearby categories within 10km
  Future<void> _loadAllNearby() async {
    if (_myLocation == null) return;
    setState(() => _loadingNearby = true);
    final center = ll.LatLng(_myLocation!.latitude, _myLocation!.longitude);
    final allPlaces = <NearbyPlace>[];
    for (final key in NearbyService.categories.keys) {
      try {
        final places = await NearbyService.fetch(center: center, categoryKey: key, radiusMeters: 10000);
        allPlaces.addAll(places);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _nearbyPlaces = allPlaces;
        _loadingNearby = false;
      });
    }
  }

  @override
  void dispose() {
    LocationService.stopBroadcasting();
    _teamLocationSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }

  void _showAddPoiDialog({LatLng? presetLocation}) {
    if (_activeTeamId == null) return;
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedCategory = 'food';
    // Location can be preset (from long-press) or chosen via search
    double? poiLat = presetLocation?.latitude;
    double? poiLng = presetLocation?.longitude;
    String? poiLocationName = presetLocation != null ? 'Dropped pin' : null;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    final searchCtrl = TextEditingController();
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add POI', style: GoogleFonts.inter(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
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
                  // Location picker
                  TextField(
                    controller: searchCtrl,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      hintStyle: GoogleFonts.inter(color: Colors.white24),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      suffixIcon: isSearching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6D00))))
                        : null,
                      filled: true, fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 500), () async {
                        if (val.trim().length < 3) { setDialogState(() => searchResults = []); return; }
                        setDialogState(() => isSearching = true);
                        final results = await _searchPlaces(val);
                        setDialogState(() { searchResults = results; isSearching = false; });
                      });
                    },
                  ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (_, i) {
                          final r = searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, size: 16, color: Colors.white30),
                            title: Text(r['name'], style: GoogleFonts.inter(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              setDialogState(() {
                                poiLat = r['lat']; poiLng = r['lng'];
                                poiLocationName = (r['name'] as String).split(',').first;
                                searchResults = [];
                                searchCtrl.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  // Use my location button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.my_location, size: 14, color: Color(0xFF00BFA5)),
                      label: Text('Use my location', style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 11)),
                      onPressed: () {
                        if (_myLocation != null) {
                          setDialogState(() {
                            poiLat = _myLocation!.latitude;
                            poiLng = _myLocation!.longitude;
                            poiLocationName = 'My Location';
                          });
                        }
                      },
                    ),
                  ),
                  // Selected location indicator
                  if (poiLocationName != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFF6D00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Color(0xFFFF6D00), size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(poiLocationName!, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
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
          ),
          actions: [
            TextButton(onPressed: () { debounce?.cancel(); Navigator.pop(ctx); }, child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: poiLat != null && poiLng != null ? () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await PoiService.addPoi(
                  teamId: _activeTeamId!,
                  lat: poiLat!,
                  lng: poiLng!,
                  title: titleCtrl.text,
                  category: selectedCategory,
                  notes: notesCtrl.text,
                );
                debounce?.cancel();
                if (ctx.mounted) Navigator.pop(ctx);
              } : null,
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
  // ETA SHARING
  // ════════════════════════════════════
  void _showShareEtaDialog() {
    if (_activeTeamId == null) return;
    final destCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.access_time_rounded, color: Color(0xFF1A73E8), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Share ETA', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tell your team when you\'ll arrive',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: destCtrl,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Where are you going?',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.place_rounded, color: Colors.white38, size: 20),
                filled: true, fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minsCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Estimated minutes',
                labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.timer_rounded, color: Colors.white38, size: 20),
                filled: true, fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            label: Text('Share', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final dest = destCtrl.text.trim();
              final mins = int.tryParse(minsCtrl.text) ?? 30;
              if (dest.isEmpty) return;
              await EtaService.shareEta(
                teamId: _activeTeamId!,
                destinationName: dest,
                destLat: _myLocation?.latitude ?? 0,
                destLng: _myLocation?.longitude ?? 0,
                estimatedMinutes: mins,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ETA shared: arriving at $dest in ~$mins min'),
                    backgroundColor: const Color(0xFF1A73E8),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
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
                          // Auto-start sharing and listeners
                          setState(() => _isSharing = true);
                          LocationService.startBroadcasting(doc.id);
                          _startTeamLocationListener();
                          _startPoiListener();
                          _startUnreadListener();
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
    // RouteService uses latlong2.LatLng, convert from google_maps LatLng
    final llPoints = _routeWaypoints.map((w) => ll.LatLng(w['lat'], w['lng'])).toList();
    final polyline = await RouteService.getDirections(llPoints);
    final info = await RouteService.getRouteInfo(llPoints);
    if (mounted) {
      setState(() {
        // Convert latlong2 polyline back to google_maps LatLng
        _routePolyline = polyline.map((p) => LatLng(p.latitude, p.longitude)).toList();
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
      _routeDistKm = 0; _routeDurMin = 0;
    });
  }

  /// Opens the route planner as a draggable bottom sheet
  void _showRoutePlannerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void refreshAndRebuild() {
            setSheetState(() {}); // rebuild sheet
            setState(() {});      // rebuild map
          }
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                // Header
                Row(children: [
                  const Icon(Icons.route_rounded, color: Color(0xFF00BFA5), size: 22),
                  const SizedBox(width: 8),
                  Text('Plan Tour', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_routeWaypoints.isNotEmpty)
                    GestureDetector(onTap: () { _clearRoute(); refreshAndRebuild(); },
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22)),
                ]),
                const SizedBox(height: 16),
                // Start point
                _routeSlot(
                  label: _routeWaypoints.isNotEmpty ? _routeWaypoints.first['name'] ?? 'Start' : 'Set Start Point',
                  icon: Icons.play_circle_rounded,
                  color: const Color(0xFF00BFA5),
                  hasValue: _routeWaypoints.isNotEmpty,
                  onTap: () => _showAddWaypointDialog(label: 'Set Start Point', onAdd: (name, lat, lng) {
                    if (_routeWaypoints.isEmpty) { _routeWaypoints.add({'name': name, 'lat': lat, 'lng': lng}); }
                    else { _routeWaypoints[0] = {'name': name, 'lat': lat, 'lng': lng}; }
                    _fetchRoute(); refreshAndRebuild();
                  }),
                  onRemove: _routeWaypoints.isNotEmpty ? () { _removeWaypoint(0); refreshAndRebuild(); } : null,
                ),
                // Stops
                if (_routeWaypoints.length > 2)
                  ..._routeWaypoints.sublist(1, _routeWaypoints.length - 1).asMap().entries.map((e) {
                    final actualIdx = e.key + 1;
                    final w = e.value;
                    return Padding(padding: const EdgeInsets.only(top: 8), child: _routeSlot(
                      label: w['name'] ?? 'Stop',
                      icon: Icons.circle, color: const Color(0xFFFF6D00), hasValue: true,
                      onTap: () {}, onRemove: () { _removeWaypoint(actualIdx); refreshAndRebuild(); },
                    ));
                  }),
                // Add stop button
                if (_routeWaypoints.length >= 2)
                  Padding(padding: const EdgeInsets.only(top: 8), child: GestureDetector(
                    onTap: () => _showAddWaypointDialog(label: 'Add Stop', onAdd: (name, lat, lng) {
                      _routeWaypoints.insert(_routeWaypoints.length - 1, {'name': name, 'lat': lat, 'lng': lng});
                      _fetchRoute(); refreshAndRebuild();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3), style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_rounded, color: Color(0xFFFF6D00), size: 18),
                        const SizedBox(width: 6),
                        Text('Add Stop', style: GoogleFonts.inter(color: const Color(0xFFFF6D00), fontSize: 13)),
                      ]),
                    ),
                  )),
                const SizedBox(height: 8),
                // End point
                _routeSlot(
                  label: _routeWaypoints.length >= 2 ? _routeWaypoints.last['name'] ?? 'End' : 'Set End Point',
                  icon: Icons.flag_circle_rounded,
                  color: Colors.redAccent,
                  hasValue: _routeWaypoints.length >= 2,
                  onTap: () => _showAddWaypointDialog(label: 'Set End Point', onAdd: (name, lat, lng) {
                    if (_routeWaypoints.length < 2) { _routeWaypoints.add({'name': name, 'lat': lat, 'lng': lng}); }
                    else { _routeWaypoints[_routeWaypoints.length - 1] = {'name': name, 'lat': lat, 'lng': lng}; }
                    _fetchRoute(); refreshAndRebuild();
                  }),
                  onRemove: _routeWaypoints.length >= 2 ? () { _removeWaypoint(_routeWaypoints.length - 1); refreshAndRebuild(); } : null,
                ),
                // Route info
                if (_routeDistKm > 0)
                  Padding(padding: const EdgeInsets.only(top: 14), child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)]),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      Column(children: [
                        Text('${_routeDistKm.toStringAsFixed(1)} km', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Distance', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
                      ]),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Column(children: [
                        Text(_routeDurMin < 60 ? '${_routeDurMin.toStringAsFixed(0)} min' : '${(_routeDurMin / 60).toStringAsFixed(1)} hr',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Duration', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
                      ]),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Column(children: [
                        Text('${(_routeWaypoints.length - 2).clamp(0, 999)}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Stops', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
                      ]),
                    ]),
                  )),
              ]),
            ),
          );
        },
      ),
    );
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

  void _showAddWaypointDialog({String label = 'Add Stop', void Function(String name, double lat, double lng)? onAdd}) {
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
                if (onAdd != null) {
                  onAdd(selectedName ?? 'Stop ${_routeWaypoints.length + 1}', selectedLat!, selectedLng!);
                } else {
                  _addWaypoint(selectedName ?? 'Stop ${_routeWaypoints.length + 1}', selectedLat!, selectedLng!);
                }
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
  // NEARBY PLACES
  // ════════════════════════════════════


  void _showNearbyDetail(NearbyPlace place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text(place.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(place.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(NearbyService.categories[place.category]?['label']?.toString() ?? place.category,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
          if (place.address != null && place.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on, color: Color(0xFFFF6D00), size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(place.address!, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          if (place.openingHours != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.access_time, color: Color(0xFF00BFA5), size: 16),
              const SizedBox(width: 6),
              Text(place.openingHours!, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            ]),
          ],
          if (place.phone != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.phone, color: Color(0xFF1A73E8), size: 16),
              const SizedBox(width: 6),
              Text(place.phone!, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.directions, color: Colors.white, size: 18),
            label: Text('Set as Destination', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.pop(ctx);
              _showRoutePlannerSheet();
            },
          )),
        ]),
      ),
    );
  }

  void _showMapStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('Map Style', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Choose your preferred map view',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: _mapTypeLabels.asMap().entries.map((e) {
            final i = e.key;
            final style = e.value;
            final isActive = _mapTypeIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _mapTypeIndex = i);
                Navigator.pop(ctx);
              },
              child: Container(
                width: (MediaQuery.of(ctx).size.width - 62) / 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1A73E8).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isActive ? const Color(0xFF1A73E8) : Colors.white.withOpacity(0.08), width: isActive ? 2 : 1),
                ),
                child: Column(children: [
                  Text(style['icon'] ?? '', style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(style['name'] ?? '', style: GoogleFonts.inter(
                    color: isActive ? const Color(0xFF1A73E8) : Colors.white70,
                    fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            );
          }).toList()),
        ]),
      ),
    );
  }

  // ════════════════════════════════════
  // GOOGLE MAPS BUILDERS
  // ════════════════════════════════════
  Set<Marker> _buildAllMarkers() {
    final markers = <Marker>{};

    // Waypoint markers
    for (int i = 0; i < _routeWaypoints.length; i++) {
      final w = _routeWaypoints[i];
      final isStart = i == 0;
      final isEnd = i == _routeWaypoints.length - 1;
      final hue = isStart ? BitmapDescriptor.hueGreen : isEnd ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange;
      markers.add(Marker(
        markerId: MarkerId('waypoint_$i'),
        position: LatLng(w['lat'], w['lng']),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: w['name'] ?? (isStart ? 'Start' : isEnd ? 'End' : 'Stop')),
      ));
    }

    // Nearby place markers
    for (int i = 0; i < _nearbyPlaces.length; i++) {
      final p = _nearbyPlaces[i];
      markers.add(Marker(
        markerId: MarkerId('nearby_${p.category}_$i'),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(title: '${p.emoji} ${p.name}', snippet: p.address),
        onTap: () => _showNearbyDetail(p),
      ));
    }

    // Team member markers
    markers.addAll(_teamMarkers);

    // POI markers
    markers.addAll(_poiMarkers);

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePolyline.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePolyline,
        width: 5,
        color: const Color(0xFF1A73E8),
      ),
    };
  }

  Set<Circle> _buildCircles() {
    if (_myLocation == null || _accuracy <= 0) return {};
    return {
      Circle(
        circleId: const CircleId('accuracy'),
        center: _myLocation!,
        radius: _accuracy,
        fillColor: const Color(0xFF1A73E8).withOpacity(0.1),
        strokeColor: const Color(0xFF1A73E8).withOpacity(0.3),
        strokeWidth: 1,
      ),
    };
  }

  void _startTeamLocationListener() {
    _teamLocationSub?.cancel();
    if (_activeTeamId == null) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    _teamLocationSub = LocationService.getTeamLocations(_activeTeamId!).listen((snapshot) {
      if (!mounted) return;
      final markers = <Marker>{};
      final docs = snapshot.docs;
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final lat = (data['lat'] as num?)?.toDouble() ?? 0;
        final lng = (data['lng'] as num?)?.toDouble() ?? 0;
        final userName = data['userName'] as String? ?? '?';
        final isMe = doc.id == currentUid;

        if (isMe && _followMe) {
          _myLocation = LatLng(lat, lng);
          _gMapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
        }

        markers.add(Marker(
          markerId: MarkerId('member_${doc.id}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueCyan,
          ),
          infoWindow: InfoWindow(
            title: isMe ? 'You' : userName,
            snippet: '${LocationService.formatSpeed((data['speedKmh'] as num?)?.toDouble() ?? 0)}',
          ),
        ));
      }
      setState(() => _teamMarkers = markers);
    });
  }

  void _startPoiListener() {
    if (_activeTeamId == null) return;
    PoiService.getTeamPois(_activeTeamId!).listen((snapshot) {
      if (!mounted) return;
      final markers = <Marker>{};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = (data['lat'] as num?)?.toDouble() ?? 0;
        final lng = (data['lng'] as num?)?.toDouble() ?? 0;
        final title = data['title'] as String? ?? '';
        final emoji = PoiService.categories[data['category'] ?? 'other'] ?? '📍';
        markers.add(Marker(
          markerId: MarkerId('poi_${doc.id}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: '$emoji $title'),
          onTap: () => _showPoiDetail(doc.id, data),
        ));
      }
      setState(() => _poiMarkers = markers);
    });
  }

  // ════════════════════════════════════
  // BUILD
  // ════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Stack(
        children: [
          // ── GOOGLE MAP ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _myLocation ?? const LatLng(12.9716, 77.5946),
              zoom: 14,
            ),
            mapType: _mapTypes[_mapTypeIndex],
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _gMapController = controller;
              if (_myLocation != null) {
                controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 15));
              }
            },
            onCameraMoveStarted: () {
              if (_followMe) setState(() => _followMe = false);
            },
            onLongPress: (latLng) {
              if (_activeTeamId != null) {
                _showAddPoiDialog(presetLocation: latLng);
              }
            },
            markers: _buildAllMarkers(),
            polylines: _buildPolylines(),
            circles: _buildCircles(),
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
                  // ── TOP RIGHT ICONS ──
                  const SizedBox(width: 8),
                  // Message icon with red dot
                  if (_activeTeamId != null)
                    _badgeIcon(
                      icon: Icons.chat_bubble_rounded,
                      hasBadge: _hasUnreadChat,
                      onTap: () {
                        ChatService.markAsRead(_activeTeamId!);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TeamChatScreen(
                            teamId: _activeTeamId!,
                            teamName: _activeTeamName ?? 'Team',
                          ),
                        ));
                      },
                    ),
                  const SizedBox(width: 8),
                  // Notification bell
                  _badgeIcon(
                    icon: Icons.notifications_rounded,
                    hasBadge: false,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No new notifications'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
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
                      _gMapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_myLocation!, 15),
                      );
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
                // ETA share button
                if (_activeTeamId != null)
                  _mapButton(
                    icon: Icons.access_time_rounded,
                    color: Colors.white.withOpacity(0.54),
                    onTap: _showShareEtaDialog,
                  ),
                const Spacer(),
                // Map style button
                _mapButton(
                  icon: Icons.layers_rounded,
                  color: const Color(0xFF1A73E8),
                  onTap: _showMapStylePicker,
                ),
              ],
            ),
          ),


          // ── ROUTE PLANNER BUTTON (top right, below team bar) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: GestureDetector(
              onTap: _showRoutePlannerSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _routeWaypoints.isNotEmpty
                      ? const Color(0xFF00BFA5)
                      : const Color(0xFF161B22).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _routeWaypoints.isNotEmpty
                      ? const Color(0xFF00BFA5)
                      : Colors.white.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.route_rounded, color: _routeWaypoints.isNotEmpty ? Colors.white : Colors.white54, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _routeWaypoints.isNotEmpty
                        ? '${_routeDistKm.toStringAsFixed(1)} km · ${_routeDurMin < 60 ? '${_routeDurMin.toStringAsFixed(0)} min' : '${(_routeDurMin / 60).toStringAsFixed(1)} hr'}'
                        : 'Plan Route',
                    style: GoogleFonts.inter(
                      color: _routeWaypoints.isNotEmpty ? Colors.white : Colors.white54,
                      fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_routeWaypoints.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearRoute,
                      child: const Icon(Icons.close, color: Colors.white70, size: 16),
                    ),
                  ],
                ]),
              ),
            ),
          ),

          // ── LOADING NEARBY INDICATOR ──
          if (_loadingNearby)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6D00))),
                  const SizedBox(width: 8),
                  Text('Loading nearby...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
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

  Widget _badgeIcon({
    required IconData icon,
    required bool hasBadge,
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 22),
            if (hasBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF161B22), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startUnreadListener() {
    _unreadSub?.cancel();
    if (_activeTeamId == null) return;
    _unreadSub = ChatService.hasUnread(_activeTeamId!).listen((hasUnread) {
      if (mounted) setState(() => _hasUnreadChat = hasUnread);
    });
  }

  Widget _routeSlot({
    required String label,
    required IconData icon,
    required Color color,
    required bool hasValue,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue ? color.withOpacity(0.08) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasValue ? color.withOpacity(0.3) : Colors.white.withOpacity(0.08)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.inter(
            color: hasValue ? Colors.white : Colors.white38,
            fontSize: 14, fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal),
            overflow: TextOverflow.ellipsis)),
          if (onRemove != null)
            GestureDetector(onTap: onRemove,
              child: const Icon(Icons.close, color: Colors.white24, size: 18)),
          if (!hasValue)
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.2), size: 14),
        ]),
      ),
    );
  }
}
