import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2;
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
import '../services/background_tracking_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/team_service.dart';
import '../services/poi_service.dart';
import '../services/route_service.dart';
import '../services/nearby_service.dart';
import '../services/chat_service.dart';
import '../services/eta_service.dart';
import '../services/trip_plan_service.dart';
import 'package:share_plus/share_plus.dart';
import 'team_chat_screen.dart';

class LiveMapScreen extends StatefulWidget {
  final String? loadPlanId;
  final List<Map<String, dynamic>>? loadPlanWaypoints;
  final String? loadPlanName;

  const LiveMapScreen({
    super.key,
    this.loadPlanId,
    this.loadPlanWaypoints,
    this.loadPlanName,
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _gMapController;
  String? _activeTeamId;
  String? _activeTeamName;
  bool _isSharing = false;
  bool _followMe = true;
  bool _is3DView = false;
  LatLng? _myLocation;
  double _accuracy = 0; // meters

  // Route planning
  List<LatLng> _routePolyline = [];
  List<Map<String, dynamic>> _routeWaypoints = []; // {name, lat, lng}
  double _routeDistKm = 0;
  double _routeDurMin = 0;
  bool _showRoutePanel = false; // kept for route info chip visibility
  bool _isRoundTrip = false;

  // Trip plan tracking
  String? _activePlanId;
  String? _activePlanTeamId;
  String? _activePlanStatus; // planned | active | completed
  String? _activePlanName;
  List<Map<String, dynamic>> _tripStops = []; // logged activity stops
  Set<Marker> _stopMarkers = {};

  // Live GPS tracking (Start/Stop)
  bool _isLiveTracking = false;
  List<LatLng> _trackPoints = [];
  DateTime? _trackStartTime;
  StreamSubscription<dynamic>? _trackGpsSub;
  double _trackDistanceKm = 0;
  String _trackElapsed = '00:00';
  Timer? _trackTimer;

  // Turn-by-turn navigation
  bool _isNavigating = false;
  NavigationRoute? _navRoute;
  int _currentStepIndex = 0;
  StreamSubscription<dynamic>? _navGpsSub;
  double _navRemainingKm = 0;
  double _navRemainingMin = 0;

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
    // Template plan is loaded in onMapCreated (needs map controller)
  }

  void _loadTemplatePlan() {
    final waypoints = widget.loadPlanWaypoints!;
    setState(() {
      _activePlanId = widget.loadPlanId;
      _activePlanTeamId = null;
      _activePlanStatus = 'planned';
      _activePlanName = widget.loadPlanName ?? 'Trip';
      _isRoundTrip = false;
      _routeWaypoints = waypoints.map((w) => <String, dynamic>{
        'name': w['name'] ?? 'Point',
        'lat': (w['lat'] as num).toDouble(),
        'lng': (w['lng'] as num).toDouble(),
      }).toList();
      _routePolyline = [];
      _routeDistKm = 0;
      _routeDurMin = 0;
    });

    // Auto-fetch route between all waypoints
    if (_routeWaypoints.length >= 2) {
      _fetchRoute();
    }

    // Zoom to first waypoint
    if (_routeWaypoints.isNotEmpty && _gMapController != null) {
      final first = _routeWaypoints.first;
      _gMapController!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(first['lat'], first['lng']), 8));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Loaded "${widget.loadPlanName}" with ${waypoints.length} stops',
          style: GoogleFonts.inter()),
      backgroundColor: const Color(0xFF1A73E8),
    ));
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
    // Pre-generate round emoji icons for each category
    final seenCats = <String>{};
    for (final p in allPlaces) {
      if (seenCats.contains(p.category)) continue;
      seenCats.add(p.category);
      final color = _categoryColors[p.category] ?? const Color(0xFF9E9E9E);
      await _createEmojiMarker(p.emoji, color);
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
    _trackGpsSub?.cancel();
    _trackTimer?.cancel();
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
      _isRoundTrip = false;
      _activePlanId = null;
      _activePlanTeamId = null;
      _activePlanStatus = null;
      _activePlanName = null;
      _tripStops = [];
      _stopMarkers = {};
    });
  }

  // ════════════════════════════════════
  // TRIP HISTORY
  // ════════════════════════════════════
  void _showTripHistorySheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sign in to view trip history', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: Color(0xFF7C4DFF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Trip History', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('Tap to view on map', style: GoogleFonts.inter(
                    color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.06)),
            // List of trips
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(uid).collection('recent_tracks')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading trips',
                        style: GoogleFonts.inter(color: Colors.white38)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, color: Colors.white.withOpacity(0.1), size: 64),
                          const SizedBox(height: 12),
                          Text('No trips yet', style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Start tracking to see your trips here!',
                              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final distKm = (data['distanceKm'] as num?)?.toDouble() ?? 0;
                      final duration = data['durationText'] as String? ?? data['duration'] as String? ?? '';
                      final pointCount = data['pointCount'] as int? ?? 0;
                      final name = data['name'] as String? ?? 'Trip';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final dateStr = createdAt != null
                          ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                          : '';
                      final docId = docs[index].id;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _loadTripOnMap(data, docId);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              // Route icon with gradient
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C4DFF), Color(0xFF00BFA5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.route_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              // Trip details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(
                                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.straighten_rounded, color: Colors.white30, size: 12),
                                        const SizedBox(width: 4),
                                        Text('${distKm.toStringAsFixed(1)} km',
                                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                        const SizedBox(width: 12),
                                        Icon(Icons.access_time_rounded, color: Colors.white30, size: 12),
                                        const SizedBox(width: 4),
                                        Text(duration,
                                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                        const SizedBox(width: 12),
                                        Icon(Icons.place_rounded, color: Colors.white30, size: 12),
                                        const SizedBox(width: 4),
                                        Text('$pointCount pts',
                                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Date + arrow
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(dateStr, style: GoogleFonts.inter(
                                      color: Colors.white24, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadTripOnMap(Map<String, dynamic> data, String docId) {
    final polylineStr = data['polyline'] as String?;
    if (polylineStr == null || polylineStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No route data for this trip', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    // Parse polyline points
    final points = <LatLng>[];
    for (final seg in polylineStr.split(';')) {
      final parts = seg.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) points.add(LatLng(lat, lng));
      }
    }

    if (points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Trip route too short to display', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final distKm = (data['distanceKm'] as num?)?.toDouble() ?? 0;
    final duration = data['durationText'] as String? ?? data['duration'] as String? ?? '';
    final name = data['name'] as String? ?? 'Trip';

    setState(() {
      // Clear existing route and load history trip
      _routePolyline = points;
      _routeDistKm = distKm;
      _routeDurMin = 0;
      _routeWaypoints = [
        {'name': 'Start', 'lat': points.first.latitude, 'lng': points.first.longitude},
        {'name': 'End', 'lat': points.last.latitude, 'lng': points.last.longitude},
      ];
      _trackPoints = points;
      _trackDistanceKm = distKm;
      _trackElapsed = duration;
    });

    // Zoom to fit the entire trip
    if (_gMapController != null && points.length >= 2) {
      double minLat = points.first.latitude, maxLat = points.first.latitude;
      double minLng = points.first.longitude, maxLng = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      _gMapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60, // padding
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📍 $name — ${distKm.toStringAsFixed(1)} km · $duration',
          style: GoogleFonts.inter()),
      backgroundColor: const Color(0xFF7C4DFF),
      duration: const Duration(seconds: 3),
    ));
  }

  // ════════════════════════════════════
  // TURN-BY-TURN NAVIGATION
  // ════════════════════════════════════
  Future<void> _startNavigation() async {
    if (_routeWaypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Add at least 2 waypoints first', style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    // Fetch route with steps
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Fetching navigation route...', style: GoogleFonts.inter()),
      backgroundColor: const Color(0xFF1A73E8),
      duration: const Duration(seconds: 1),
    ));

    final llPoints = _routeWaypoints.map((w) => ll.LatLng(w['lat'], w['lng'])).toList();
    final navRoute = await RouteService.getDirectionsWithSteps(llPoints);

    if (navRoute.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not fetch navigation route', style: GoogleFonts.inter()),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    setState(() {
      _isNavigating = true;
      _navRoute = navRoute;
      _currentStepIndex = 0;
      _navRemainingKm = navRoute.totalDistanceKm;
      _navRemainingMin = navRoute.totalDurationMin;
      _routePolyline = navRoute.polyline.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _routeDistKm = navRoute.totalDistanceKm;
      _routeDurMin = navRoute.totalDurationMin;
    });

    // Zoom to first step with tilt for navigation feel
    if (_gMapController != null && navRoute.steps.isNotEmpty) {
      final firstStep = navRoute.steps[0];
      _gMapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(firstStep.location.latitude, firstStep.location.longitude),
          zoom: 17,
          tilt: 50,
          bearing: 0,
        ),
      ));
    }

    // Start GPS stream to track progress
    _navGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted || !_isNavigating || _navRoute == null) return;

      final myPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = myPos;
        _accuracy = pos.accuracy;
      });

      // Check if we've reached the current step location
      final steps = _navRoute!.steps;
      if (_currentStepIndex < steps.length - 1) {
        final nextStep = steps[_currentStepIndex + 1];
        final distToNext = _haversine(myPos,
            LatLng(nextStep.location.latitude, nextStep.location.longitude));

        // Advance to next step when within 50m
        if (distToNext < 0.05) {
          setState(() {
            _currentStepIndex++;
            // Update remaining distance/time
            double remainDist = 0;
            double remainTime = 0;
            for (int i = _currentStepIndex; i < steps.length; i++) {
              remainDist += steps[i].distanceM;
              remainTime += steps[i].durationS;
            }
            _navRemainingKm = remainDist / 1000;
            _navRemainingMin = remainTime / 60;
          });
        }
      }

      // Check if arrived at final destination
      if (_currentStepIndex >= steps.length - 1) {
        final lastStep = steps.last;
        final distToEnd = _haversine(myPos,
            LatLng(lastStep.location.latitude, lastStep.location.longitude));
        if (distToEnd < 0.05) {
          _stopNavigation(arrived: true);
          return;
        }
      }

      // Keep camera following with forward-looking bearing
      if (_followMe) {
        _gMapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: myPos,
            zoom: 17,
            tilt: 50,
            bearing: pos.heading,
          ),
        ));
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🧭 Navigation started!', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF00BFA5),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _stopNavigation({bool arrived = false}) {
    _navGpsSub?.cancel();
    _navGpsSub = null;

    setState(() {
      _isNavigating = false;
      _navRoute = null;
      _currentStepIndex = 0;
      _navRemainingKm = 0;
      _navRemainingMin = 0;
    });

    // Reset camera tilt
    if (_gMapController != null && _myLocation != null) {
      _gMapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _myLocation!, zoom: 15, tilt: 0, bearing: 0),
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          arrived ? '🏁 You have arrived!' : 'Navigation stopped',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: arrived ? const Color(0xFF00BFA5) : const Color(0xFF161B22),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ════════════════════════════════════
  // LIVE GPS TRACKING (Start/Stop → Recents)
  // ════════════════════════════════════

  double _haversine(LatLng a, LatLng b) {
    const R = 6371.0; // km
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLng = (b.longitude - a.longitude) * 3.141592653589793 / 180;
    final lat1 = a.latitude * 3.141592653589793 / 180;
    final lat2 = b.latitude * 3.141592653589793 / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  void _startLiveTracking() async {
    final hasPermission = await LocationService.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission required', style: GoogleFonts.inter())),
        );
      }
      return;
    }

    // Start the background foreground service
    if (!kIsWeb) {
      await BackgroundTrackingService.startTracking();
    }

    setState(() {
      _isLiveTracking = true;
      _trackPoints = [];
      _trackDistanceKm = 0;
      _trackElapsed = '00:00';
      _trackStartTime = DateTime.now();
    });

    // UI sync timer — updates elapsed time every 2 seconds
    _trackTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_isLiveTracking) return;

      if (_trackStartTime == null) return;
      final diff = DateTime.now().difference(_trackStartTime!);
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final s = diff.inSeconds.remainder(60);
      setState(() {
        _trackElapsed = h > 0
            ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
            : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      });
    });

    // Always start foreground GPS stream for live trail rendering on the map
    // (Background service handles when app is minimized, but foreground stream
    // ensures the colored trail appears immediately)
    _trackGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted || !_isLiveTracking) return;
      final newPoint = LatLng(pos.latitude, pos.longitude);
      setState(() {
        if (_trackPoints.isNotEmpty) {
          _trackDistanceKm += _haversine(_trackPoints.last, newPoint);
        }
        _trackPoints.add(newPoint);
        _myLocation = newPoint;
        _accuracy = pos.accuracy;
      });
      if (_followMe) {
        _gMapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📍 Tracking started — works in background!', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF00BFA5),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _stopLiveTracking() async {
    // Stop background service
    if (!kIsWeb) {
      await BackgroundTrackingService.stopTracking();
    }

    _trackGpsSub?.cancel();
    _trackGpsSub = null;
    _trackTimer?.cancel();
    _trackTimer = null;

    // Use foreground GPS points directly (they're always available)
    List<LatLng> points = List<LatLng>.from(_trackPoints);
    double distKm = _trackDistanceKm;
    String elapsed = _trackElapsed;
    Duration duration = _trackStartTime != null
        ? DateTime.now().difference(_trackStartTime!)
        : Duration.zero;

    setState(() {
      _isLiveTracking = false;
      _trackPoints = points;
      _trackDistanceKm = distKm;
      _trackElapsed = elapsed;
    });

    if (points.length < 2) {
      setState(() {
        _trackPoints = [];
        _trackDistanceKm = 0;
        _trackElapsed = '00:00';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Too short to save — need at least 2 points', style: GoogleFonts.inter())),
        );
      }
      return;
    }

    // Save to Firestore → recent_tracks
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final startName = 'Track ${_trackStartTime?.hour.toString().padLeft(2, '0')}:${_trackStartTime?.minute.toString().padLeft(2, '0')}';
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('recent_tracks')
            .add({
          'name': startName,
          'distanceKm': double.parse(distKm.toStringAsFixed(2)),
          'durationSeconds': duration.inSeconds,
          'duration': elapsed,
          'durationText': elapsed,
          'pointCount': points.length,
          'startLat': points.first.latitude,
          'startLng': points.first.longitude,
          'endLat': points.last.latitude,
          'endLng': points.last.longitude,
          'polyline': points.map((p) => '${p.latitude},${p.longitude}').join(';'),
          'startTime': _trackStartTime != null
              ? Timestamp.fromDate(_trackStartTime!)
              : FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'userId': uid,
        });
      } catch (e) {
        debugPrint('Error saving track: $e');
      }
    }

    // Show summary
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00BFA5), size: 22),
          const SizedBox(width: 8),
          Text('Track Saved!', style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
        ]),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [
              Text(distKm.toStringAsFixed(1), style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('km', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ]),
            Container(width: 1, height: 32, color: Colors.white24),
            Column(children: [
              Text(elapsed, style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('time', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ]),
            Container(width: 1, height: 32, color: Colors.white24),
            Column(children: [
              Text('${points.length}', style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('points', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _trackPoints = [];
                _trackDistanceKm = 0;
                _trackElapsed = '00:00';
              });
            },
            child: Text('Clear Trail', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep on Map', style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════
  // TRIP PLAN: SAVE
  // ════════════════════════════════════
  void _savePlanDialog() {
    final nameCtrl = TextEditingController(text: _activePlanName ?? '');
    bool roundTrip = _isRoundTrip;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.save_rounded, color: Color(0xFF00BFA5), size: 20),
            ),
            const SizedBox(width: 10),
            Text(_activePlanId != null ? 'Update Plan' : 'Save Plan',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  hintText: 'e.g. Bangalore to Goa',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  setDlgState(() => roundTrip = !roundTrip);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: roundTrip ? const Color(0xFF1A73E8).withOpacity(0.12) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roundTrip ? const Color(0xFF1A73E8).withOpacity(0.4) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(children: [
                    Icon(Icons.loop_rounded, color: roundTrip ? const Color(0xFF1A73E8) : Colors.white38, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Round Trip', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Return to start point', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                    ])),
                    Icon(roundTrip ? Icons.check_circle : Icons.circle_outlined,
                        color: roundTrip ? const Color(0xFF1A73E8) : Colors.white24, size: 22),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              // Route summary
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _summaryChip(Icons.place, '${_routeWaypoints.length} pts'),
                  _summaryChip(Icons.straighten, '${_routeDistKm.toStringAsFixed(1)} km'),
                  _summaryChip(Icons.timer, _routeDurMin < 60
                      ? '${_routeDurMin.toStringAsFixed(0)} min'
                      : '${(_routeDurMin / 60).toStringAsFixed(1)} hr'),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check, color: Colors.white, size: 18),
              label: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                // Build waypoints with types
                final waypoints = <Map<String, dynamic>>[];
                for (int i = 0; i < _routeWaypoints.length; i++) {
                  final w = _routeWaypoints[i];
                  String type = 'stop';
                  if (i == 0) type = 'start';
                  else if (i == _routeWaypoints.length - 1) type = roundTrip ? 'start' : 'end';
                  waypoints.add({
                    'name': w['name'] ?? 'Point ${i + 1}',
                    'lat': w['lat'],
                    'lng': w['lng'],
                    'order': i,
                    'type': type,
                  });
                }
                // Encode polyline as JSON string for storage
                final polylineEncoded = _routePolyline.isNotEmpty
                    ? _routePolyline.map((p) => '${p.latitude},${p.longitude}').join(';')
                    : '';
                try {
                  final planId = await TripPlanService.savePlan(
                    teamId: _activePlanTeamId,
                    planId: _activePlanId,
                    name: nameCtrl.text.trim(),
                    waypoints: waypoints,
                    routeDistanceKm: _routeDistKm,
                    routeDurationMin: _routeDurMin,
                    routePolyline: polylineEncoded,
                    isRoundTrip: roundTrip,
                  );
                  if (mounted) {
                    if (planId != null) {
                      setState(() {
                        _activePlanId = planId;
                        _activePlanName = nameCtrl.text.trim();
                        _isRoundTrip = roundTrip;
                        _activePlanStatus = _activePlanStatus ?? 'planned';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Trip plan "${nameCtrl.text.trim()}" saved! ✓',
                            style: GoogleFonts.inter()),
                        backgroundColor: const Color(0xFF00BFA5),
                      ));
                    } else {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed to save — please sign in first',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.redAccent,
                      ));
                    }
                  }
                } catch (e) {
                  debugPrint('Save plan error: $e');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error saving: $e', style: GoogleFonts.inter()),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
    ]);
  }

  // ════════════════════════════════════
  // TRIP PLAN: LOAD
  // ════════════════════════════════════
  void _showLoadTripSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        // Show both personal and team plans
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Row(children: [
                const Icon(Icons.folder_open_rounded, color: Color(0xFF1A73E8), size: 22),
                const SizedBox(width: 8),
                Text('Load Trip Plan', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text('Tap a plan to load it on the map',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: TripPlanService.getPlans(_activeTeamId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8)));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 48, color: Colors.white.withOpacity(0.12)),
                          const SizedBox(height: 8),
                          Text('No saved plans yet', style: GoogleFonts.inter(color: Colors.white38)),
                          const SizedBox(height: 4),
                          Text('Plan a route and tap Save', style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                        ],
                      ));
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Trip';
                        final status = data['status'] as String? ?? 'planned';
                        final dist = (data['routeDistanceKm'] as num?)?.toStringAsFixed(1) ?? '0';
                        final dur = (data['routeDurationMin'] as num?)?.toDouble() ?? 0;
                        final durText = dur < 60
                            ? '${dur.toStringAsFixed(0)} min'
                            : '${(dur / 60).toStringAsFixed(1)} hr';
                        final waypoints = data['waypoints'] as List? ?? [];
                        final isRound = data['isRoundTrip'] == true;
                        final isActive = doc.id == _activePlanId;

                        Color statusColor;
                        String statusLabel;
                        IconData statusIcon;
                        switch (status) {
                          case 'active':
                            statusColor = const Color(0xFF00BFA5);
                            statusLabel = 'ACTIVE';
                            statusIcon = Icons.play_circle;
                            break;
                          case 'completed':
                            statusColor = Colors.white38;
                            statusLabel = 'DONE';
                            statusIcon = Icons.check_circle;
                            break;
                          default:
                            statusColor = const Color(0xFF1A73E8);
                            statusLabel = 'PLANNED';
                            statusIcon = Icons.map_rounded;
                        }

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadPlanOntoMap(doc.id, data);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF1A73E8).withOpacity(0.1)
                                  : const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isActive
                                  ? const Color(0xFF1A73E8).withOpacity(0.4)
                                  : Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(statusIcon, color: statusColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(name, style: GoogleFonts.inter(
                                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(statusLabel, style: GoogleFonts.inter(
                                      color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                _summaryChip(Icons.place, '${waypoints.length} pts'),
                                const SizedBox(width: 12),
                                _summaryChip(Icons.straighten, '$dist km'),
                                const SizedBox(width: 12),
                                _summaryChip(Icons.timer, durText),
                                if (isRound) ...[
                                  const SizedBox(width: 12),
                                  _summaryChip(Icons.loop, 'Round'),
                                ],
                              ]),
                            ]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// Load a saved plan onto the map
  void _loadPlanOntoMap(String planId, Map<String, dynamic> data) {
    final waypoints = (data['waypoints'] as List? ?? [])
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
    waypoints.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));

    final polylineStr = data['routePolyline'] as String? ?? '';
    List<LatLng> polyline = [];
    if (polylineStr.isNotEmpty) {
      polyline = polylineStr.split(';').map((p) {
        final parts = p.split(',');
        if (parts.length == 2) {
          return LatLng(double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0);
        }
        return const LatLng(0, 0);
      }).where((p) => p.latitude != 0 || p.longitude != 0).toList();
    }

    final stops = (data['stops'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    setState(() {
      _activePlanId = planId;
      _activePlanTeamId = _activeTeamId;
      _activePlanStatus = data['status'] as String? ?? 'planned';
      _activePlanName = data['name'] as String? ?? 'Trip';
      _isRoundTrip = data['isRoundTrip'] == true;
      _routeWaypoints = waypoints.map((w) => {
        'name': w['name'] ?? 'Point',
        'lat': (w['lat'] as num).toDouble(),
        'lng': (w['lng'] as num).toDouble(),
      }).toList();
      _routePolyline = polyline;
      _routeDistKm = (data['routeDistanceKm'] as num?)?.toDouble() ?? 0;
      _routeDurMin = (data['routeDurationMin'] as num?)?.toDouble() ?? 0;
      _tripStops = stops;
    });

    _buildStopMarkers();

    // If polyline empty but waypoints exist, refetch route
    if (_routePolyline.isEmpty && _routeWaypoints.length >= 2) {
      _fetchRoute();
    }

    // Zoom to fit the route
    if (_routeWaypoints.isNotEmpty) {
      final firstWp = _routeWaypoints.first;
      _gMapController?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(firstWp['lat'], firstWp['lng']), 10));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Loaded "$_activePlanName"', style: GoogleFonts.inter()),
      backgroundColor: const Color(0xFF1A73E8),
    ));
  }

  // ════════════════════════════════════
  // TRIP PLAN: START / COMPLETE
  // ════════════════════════════════════
  Future<void> _startTripFlow() async {
    if (_activePlanId == null) return;
    await TripPlanService.startTrip(_activePlanTeamId, _activePlanId!);
    setState(() => _activePlanStatus = 'active');

    // Start location sharing if team is set
    if (_activeTeamId != null && !_isSharing) {
      _toggleSharing();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🚗 Trip started! Your location is being shared.'),
        backgroundColor: Color(0xFF00BFA5),
      ));
    }
  }

  Future<void> _completeTripFlow() async {
    if (_activePlanId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Complete Trip?', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('This will mark "${_activePlanName}" as completed and stop location sharing.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Complete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await TripPlanService.completeTrip(_activePlanTeamId, _activePlanId!);
    setState(() => _activePlanStatus = 'completed');

    // Stop location sharing
    if (_isSharing) _toggleSharing();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Trip completed! All stops have been saved.'),
        backgroundColor: Color(0xFF1A73E8),
      ));
    }
  }

  // ════════════════════════════════════
  // TRIP PLAN: ADD STOP (during live trip)
  // ════════════════════════════════════
  void _showAddStopSheet() {
    if (_activePlanId == null) return;
    final notesCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedActivity = 'other';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Row(children: [
                const Icon(Icons.add_location_alt_rounded, color: Color(0xFFFF6D00), size: 22),
                const SizedBox(width: 8),
                Text('Add Stop', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text('Log what you did at this stop',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              // Activity picker
              Wrap(spacing: 8, runSpacing: 8,
                children: TripPlanService.activityTypes.entries.map((e) {
                  final isSelected = selectedActivity == e.key;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedActivity = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF6D00).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFFFF6D00) : Colors.transparent),
                      ),
                      child: Text(
                        '${e.value['emoji']} ${e.value['label']}',
                        style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white54, fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Stop Name',
                  hintText: 'e.g. HP Petrol Pump',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                style: GoogleFonts.inter(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Filled 20L diesel',
                  labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                  hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 6),
              // GPS auto-fill indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.my_location, color: Color(0xFF00BFA5), size: 14),
                  const SizedBox(width: 6),
                  Text('Using your current GPS location',
                      style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text('Add Stop', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final stopName = nameCtrl.text.trim().isEmpty
                        ? (TripPlanService.activityTypes[selectedActivity]?['label'] ?? 'Stop')
                        : nameCtrl.text.trim();
                    final lat = _myLocation?.latitude ?? 0;
                    final lng = _myLocation?.longitude ?? 0;

                    await TripPlanService.addStop(
                      teamId: _activePlanTeamId,
                      planId: _activePlanId!,
                      name: stopName,
                      lat: lat,
                      lng: lng,
                      activity: selectedActivity,
                      notes: notesCtrl.text,
                    );

                    // Add to local state
                    final newStop = {
                      'name': stopName,
                      'lat': lat,
                      'lng': lng,
                      'activity': selectedActivity,
                      'notes': notesCtrl.text.trim(),
                      'timestamp': DateTime.now().toIso8601String(),
                    };
                    setState(() => _tripStops.add(newStop));
                    _buildStopMarkers();

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      final emoji = TripPlanService.activityTypes[selectedActivity]?['emoji'] ?? '📍';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$emoji Stop added: $stopName'),
                        backgroundColor: const Color(0xFFFF6D00),
                      ));
                    }
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════
  // TRIP PLAN: SHARE
  // ════════════════════════════════════
  void _showSharePlanDialog() {
    if (_activePlanId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('Share Trip Plan', style: GoogleFonts.inter(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Share in-app (code)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.code_rounded, color: Color(0xFF1A73E8), size: 22),
            ),
            title: Text('Share Code', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: Text('Generate a code others can enter in the app', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
            onTap: () async {
              Navigator.pop(ctx);
              final code = await TripPlanService.sharePlan(_activePlanTeamId, _activePlanId!);
              if (code != null && mounted) {
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1C2128),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Share Code', style: GoogleFonts.inter(color: Colors.white)),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
                        ),
                        child: Text(code, style: GoogleFonts.inter(
                            color: const Color(0xFF00BFA5), fontSize: 24,
                            fontWeight: FontWeight.w900, letterSpacing: 3)),
                      ),
                    ]),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => Navigator.pop(c),
                        child: Text('Done', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          // Share via WhatsApp / external
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 22),
            ),
            title: Text('Share via WhatsApp', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: Text('Send trip details to anyone', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
            onTap: () async {
              Navigator.pop(ctx);
              // First generate a share code
              final code = await TripPlanService.sharePlan(_activePlanTeamId, _activePlanId!);
              if (code != null && mounted) {
                final planData = {
                  'name': _activePlanName,
                  'routeDistanceKm': _routeDistKm,
                  'routeDurationMin': _routeDurMin,
                  'waypoints': _routeWaypoints,
                  'isRoundTrip': _isRoundTrip,
                };
                final text = TripPlanService.getShareText(planData, code);
                await SharePlus.instance.share(ShareParams(text: text));
              }
            },
          ),
        ]),
      ),
    );
  }

  /// Build colored markers for logged activity stops
  Future<void> _buildStopMarkers() async {
    final markers = <Marker>{};
    for (int i = 0; i < _tripStops.length; i++) {
      final stop = _tripStops[i];
      final activity = stop['activity'] as String? ?? 'other';
      final emoji = TripPlanService.activityTypes[activity]?['emoji'] ?? '📍';
      final name = stop['name'] as String? ?? 'Stop';
      final lat = (stop['lat'] as num?)?.toDouble() ?? 0;
      final lng = (stop['lng'] as num?)?.toDouble() ?? 0;
      if (lat == 0 && lng == 0) continue;

      // Determine stop color by activity
      Color stopColor;
      switch (activity) {
        case 'fuel': stopColor = const Color(0xFFFF9800); break;
        case 'food': stopColor = const Color(0xFFFF5722); break;
        case 'tea': stopColor = const Color(0xFF795548); break;
        case 'hotel': stopColor = const Color(0xFF3F51B5); break;
        case 'viewpoint': stopColor = const Color(0xFF4CAF50); break;
        case 'suggestion': stopColor = const Color(0xFFFFEB3B); break;
        case 'rest': stopColor = const Color(0xFF607D8B); break;
        default: stopColor = const Color(0xFF9E9E9E);
      }

      final icon = await _createEmojiMarker(emoji, stopColor);
      markers.add(Marker(
        markerId: MarkerId('trip_stop_$i'),
        position: LatLng(lat, lng),
        icon: icon,
        infoWindow: InfoWindow(title: '$emoji $name', snippet: stop['notes'] as String? ?? ''),
      ));
    }
    if (mounted) setState(() => _stopMarkers = markers);
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
                // Save Plan button
                if (_routeWaypoints.length >= 2)
                  Padding(padding: const EdgeInsets.only(top: 12), child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(_activePlanId != null ? Icons.update : Icons.save_rounded, color: Colors.white, size: 20),
                      label: Text(_activePlanId != null ? 'Update Plan' : 'Save Plan',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _savePlanDialog();
                      },
                    ),
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
  // Cached nearby marker icons
  final Map<String, BitmapDescriptor> _nearbyIconCache = {};

  /// Create a round emoji marker icon
  Future<BitmapDescriptor> _createEmojiMarker(String emoji, Color bgColor) async {
    final cacheKey = '${emoji}_${bgColor.value}';
    if (_nearbyIconCache.containsKey(cacheKey)) return _nearbyIconCache[cacheKey]!;

    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow
    canvas.drawCircle(const Offset(size / 2, size / 2 + 2), size / 2 - 2,
      Paint()..color = Colors.black.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Background circle
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4,
      Paint()..color = bgColor);

    // White border
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);

    // Emoji text
    final textPainter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 36)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 40, height: 40);
    _nearbyIconCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Create a round member marker icon with initial letter
  Future<BitmapDescriptor> _createMemberIcon(String name, Color color, bool isMe) async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Glow
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2,
      Paint()..color = color.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Background
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6,
      Paint()..color = const Color(0xFF161B22));

    // Colored border
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 6,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4);

    // Initial letter
    final letter = isMe ? '★' : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final textPainter = TextPainter(
      text: TextSpan(text: letter, style: TextStyle(fontSize: isMe ? 30 : 32, color: color, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 40, height: 40);
  }

  // Category colors for nearby markers
  static const Map<String, Color> _categoryColors = {
    'fuel': Color(0xFFFF9800),
    'garage': Color(0xFF795548),
    'hospital': Color(0xFFE53935),
    'pharmacy': Color(0xFF4CAF50),
    'toll': Color(0xFF607D8B),
    'hotel': Color(0xFF3F51B5),
    'restaurant': Color(0xFFFF5722),
    'atm': Color(0xFF009688),
    'police': Color(0xFF1565C0),
    'parking': Color(0xFF9C27B0),
  };

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

    // Nearby place markers (round emoji icons)
    for (int i = 0; i < _nearbyPlaces.length; i++) {
      final p = _nearbyPlaces[i];
      final cacheKey = '${p.emoji}_${(_categoryColors[p.category] ?? const Color(0xFF9E9E9E)).value}';
      final icon = _nearbyIconCache[cacheKey] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      markers.add(Marker(
        markerId: MarkerId('nearby_${p.category}_$i'),
        position: LatLng(p.lat, p.lng),
        icon: icon,
        infoWindow: InfoWindow(title: '${p.emoji} ${p.name}', snippet: p.address),
        onTap: () => _showNearbyDetail(p),
      ));
    }

    // Team member markers
    markers.addAll(_teamMarkers);

    // POI markers
    markers.addAll(_poiMarkers);

    // Activity stop markers (from live trip)
    markers.addAll(_stopMarkers);

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    // Planned route polyline
    if (_routePolyline.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePolyline,
        width: 5,
        color: const Color(0xFF1A73E8),
      ));
    }
    // Live tracking trail
    if (_trackPoints.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('tracking'),
        points: _trackPoints,
        width: 5,
        color: const Color(0xFFE53935),
        patterns: [PatternItem.dot, PatternItem.gap(8)],
      ));
    }
    return polylines;
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
    _teamLocationSub = LocationService.getTeamLocations(_activeTeamId!).listen((snapshot) async {
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

        final memberColor = _colorForMember(i);
        final memberIcon = await _createMemberIcon(userName, memberColor, isMe);
        markers.add(Marker(
          markerId: MarkerId('member_${doc.id}'),
          position: LatLng(lat, lng),
          icon: memberIcon,
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
    PoiService.getTeamPois(_activeTeamId!).listen((snapshot) async {
      if (!mounted) return;
      final markers = <Marker>{};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = (data['lat'] as num?)?.toDouble() ?? 0;
        final lng = (data['lng'] as num?)?.toDouble() ?? 0;
        final title = data['title'] as String? ?? '';
        final emoji = PoiService.categories[data['category'] ?? 'other'] ?? '📍';
        final poiIcon = await _createEmojiMarker(emoji, const Color(0xFFFF6D00));
        markers.add(Marker(
          markerId: MarkerId('poi_${doc.id}'),
          position: LatLng(lat, lng),
          icon: poiIcon,
          infoWindow: InfoWindow(title: '$emoji $title'),
          onTap: () => _showPoiDetail(doc.id, data),
        ));
      }
      if (mounted) setState(() => _poiMarkers = markers);
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
            mapType: _is3DView ? MapType.terrain : _mapTypes[_mapTypeIndex],
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: _is3DView,
            mapToolbarEnabled: false,
            buildingsEnabled: _is3DView,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onMapCreated: (controller) {
              _gMapController = controller;
              if (widget.loadPlanWaypoints != null && widget.loadPlanWaypoints!.isNotEmpty) {
                // Load template plan once map is ready
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) _loadTemplatePlan();
                });
              } else if (_myLocation != null) {
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Active trip banner
              if (_activePlanId != null && _activePlanStatus == 'active')
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '🚗 ${_activePlanName ?? "Trip"} · ${_tripStops.length} stops',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showAddStopSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('+ Stop', style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _completeTripFlow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('End', style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                children: [
                // ── START / STOP tracking + navigation button ──
                GestureDetector(
                  onTap: () {
                    if (_isLiveTracking || _isNavigating) {
                      // Stop both
                      if (_isLiveTracking) _stopLiveTracking();
                      if (_isNavigating) _stopNavigation();
                    } else {
                      // Start tracking
                      _startLiveTracking();
                      // Also start navigation if route is loaded
                      if (_routeWaypoints.length >= 2) {
                        _startNavigation();
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: (_isLiveTracking || _isNavigating)
                          ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)])
                          : _routeWaypoints.length >= 2
                              ? const LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)])
                              : const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF009688)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ((_isLiveTracking || _isNavigating) ? const Color(0xFFE53935) : const Color(0xFF00BFA5)).withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        (_isLiveTracking || _isNavigating)
                            ? Icons.stop_rounded
                            : _routeWaypoints.length >= 2
                                ? Icons.navigation_rounded
                                : Icons.play_arrow_rounded,
                        color: Colors.white, size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (_isLiveTracking || _isNavigating)
                            ? 'Stop · $_trackElapsed'
                            : _routeWaypoints.length >= 2
                                ? 'Start & Navigate'
                                : 'Start',
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
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
                const SizedBox(width: 8),
                // 3D terrain toggle
                _mapButton(
                  icon: _is3DView ? Icons.threed_rotation_rounded : Icons.terrain_rounded,
                  color: _is3DView ? const Color(0xFF00BFA5) : Colors.white.withOpacity(0.54),
                  onTap: () {
                    setState(() => _is3DView = !_is3DView);
                    if (_gMapController != null) {
                      final target = _myLocation ?? const LatLng(20.5937, 78.9629);
                      _gMapController!.animateCamera(
                        CameraUpdate.newCameraPosition(CameraPosition(
                          target: target,
                          zoom: _is3DView ? 16 : 15,
                          tilt: _is3DView ? 60 : 0,
                          bearing: _is3DView ? 30 : 0,
                        )),
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        _is3DView ? '🏔️ 3D Terrain View' : '🗺️ Flat View',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: _is3DView ? const Color(0xFF00BFA5) : const Color(0xFF161B22),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                ),
                const SizedBox(width: 8),
                // Trip History button
                _mapButton(
                  icon: Icons.history_rounded,
                  color: const Color(0xFF7C4DFF),
                  onTap: _showTripHistorySheet,
                ),
                const SizedBox(width: 8),
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
                // Add POI button (always visible)
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
                const SizedBox(width: 8),
                // Map style button
                _mapButton(
                  icon: Icons.layers_rounded,
                  color: const Color(0xFF1A73E8),
                  onTap: _showMapStylePicker,
                ),
              ],
             ),
            ),
            ]),
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

          // ── NAVIGATION OVERLAY (turn-by-turn) ──
          if (_isNavigating && _navRoute != null) ...[
            // Top instruction banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A73E8), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current step
                    if (_currentStepIndex < _navRoute!.steps.length) ...[
                      Row(
                        children: [
                          // Direction icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                _navRoute!.steps[_currentStepIndex].directionIcon,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Instruction + distance
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _navRoute!.steps[_currentStepIndex].instruction,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _navRoute!.steps[_currentStepIndex].distanceText,
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Remaining distance, ETA, stop button
                    Row(
                      children: [
                        // Remaining
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.straighten_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_navRemainingKm.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.access_time_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _navRemainingMin < 60
                                  ? '${_navRemainingMin.toStringAsFixed(0)} min'
                                  : '${(_navRemainingMin / 60).toStringAsFixed(1)} hr',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        // Step counter
                        Text(
                          'Step ${_currentStepIndex + 1}/${_navRoute!.steps.length}',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                        const Spacer(),
                        // Stop navigation
                        GestureDetector(
                          onTap: () => _stopNavigation(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text('Stop', style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    // Next step preview
                    if (_currentStepIndex + 1 < _navRoute!.steps.length) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Text('Then ', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                          Text(
                            _navRoute!.steps[_currentStepIndex + 1].directionIcon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _navRoute!.steps[_currentStepIndex + 1].instruction,
                              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _navRoute!.steps[_currentStepIndex + 1].distanceText,
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── TRIP CONTROL BUTTONS (top left, below team bar) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Load Trip button
              GestureDetector(
                onTap: _showLoadTripSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.folder_open_rounded, color: Color(0xFF1A73E8), size: 18),
                    const SizedBox(width: 6),
                    Text('Load Trip', style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              // Start Trip / Share buttons (when a plan is loaded)
              if (_activePlanId != null) ...[
                const SizedBox(height: 8),
                if (_activePlanStatus == 'planned')
                  GestureDetector(
                    onTap: _startTripFlow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF009688)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Start Trip', style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showSharePlanDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 18),
                      const SizedBox(width: 6),
                      Text('Share', style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
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
