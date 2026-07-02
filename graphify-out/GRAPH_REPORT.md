# Graph Report - .  (2026-07-02)

## Corpus Check
- 111 files · ~52,299 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1084 nodes · 1570 edges · 73 communities (64 shown, 9 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Live Map & Navigation|Live Map & Navigation]]
- [[_COMMUNITY_Screen Imports Hub|Screen Imports Hub]]
- [[_COMMUNITY_Community Feed & Posts|Community Feed & Posts]]
- [[_COMMUNITY_Document Wallet & Storage|Document Wallet & Storage]]
- [[_COMMUNITY_Nearby Places Service|Nearby Places Service]]
- [[_COMMUNITY_Emergency Info & Contacts|Emergency Info & Contacts]]
- [[_COMMUNITY_Trip Post Creation|Trip Post Creation]]
- [[_COMMUNITY_Expense Analytics|Expense Analytics]]
- [[_COMMUNITY_Project Config & Dependencies|Project Config & Dependencies]]
- [[_COMMUNITY_Location & Chat Services|Location & Chat Services]]
- [[_COMMUNITY_Currency Converter|Currency Converter]]
- [[_COMMUNITY_Blog & Media Upload|Blog & Media Upload]]
- [[_COMMUNITY_Discover Places|Discover Places]]
- [[_COMMUNITY_Route Optimization|Route Optimization]]
- [[_COMMUNITY_Smart Packing|Smart Packing]]
- [[_COMMUNITY_Vehicle Maintenance|Vehicle Maintenance]]
- [[_COMMUNITY_Group Expenses|Group Expenses]]
- [[_COMMUNITY_Trip Templates|Trip Templates]]
- [[_COMMUNITY_Mileage Calculator|Mileage Calculator]]
- [[_COMMUNITY_Speedometer & GPS|Speedometer & GPS]]
- [[_COMMUNITY_Travel Alerts|Travel Alerts]]
- [[_COMMUNITY_Trip Post Details|Trip Post Details]]
- [[_COMMUNITY_Travel Badges & Gamification|Travel Badges & Gamification]]
- [[_COMMUNITY_Toll Calculator|Toll Calculator]]
- [[_COMMUNITY_Team Management Service|Team Management Service]]
- [[_COMMUNITY_Fuel Tracking Screen|Fuel Tracking Screen]]
- [[_COMMUNITY_Fuel Price Comparison|Fuel Price Comparison]]
- [[_COMMUNITY_Trip Sharing|Trip Sharing]]
- [[_COMMUNITY_Expense Service|Expense Service]]
- [[_COMMUNITY_Trip Service|Trip Service]]
- [[_COMMUNITY_SOS Emergency Screen|SOS Emergency Screen]]
- [[_COMMUNITY_Checklist & Tasks|Checklist & Tasks]]
- [[_COMMUNITY_Splash & Auth Animation|Splash & Auth Animation]]
- [[_COMMUNITY_Trip Cost Tracking|Trip Cost Tracking]]
- [[_COMMUNITY_Screen State Management|Screen State Management]]
- [[_COMMUNITY_Budget Planner|Budget Planner]]
- [[_COMMUNITY_Expense Screen|Expense Screen]]
- [[_COMMUNITY_Teams Screen|Teams Screen]]
- [[_COMMUNITY_POI Service|POI Service]]
- [[_COMMUNITY_Web App Manifest|Web App Manifest]]
- [[_COMMUNITY_Google Auth Flow|Google Auth Flow]]
- [[_COMMUNITY_Fuel Service|Fuel Service]]
- [[_COMMUNITY_Travel Journal|Travel Journal]]
- [[_COMMUNITY_Packing Lists|Packing Lists]]
- [[_COMMUNITY_Trip Planner|Trip Planner]]
- [[_COMMUNITY_Chat Service|Chat Service]]
- [[_COMMUNITY_Emergency Contact Service|Emergency Contact Service]]
- [[_COMMUNITY_Team Details & Sharing|Team Details & Sharing]]
- [[_COMMUNITY_Dashboard & Settings|Dashboard & Settings]]
- [[_COMMUNITY_App Entry Point|App Entry Point]]
- [[_COMMUNITY_Firebase Configuration|Firebase Configuration]]
- [[_COMMUNITY_Trip Log Service|Trip Log Service]]
- [[_COMMUNITY_iOS App Delegate|iOS App Delegate]]
- [[_COMMUNITY_Google Services Config|Google Services Config]]
- [[_COMMUNITY_ETA Service|ETA Service]]
- [[_COMMUNITY_App Icons & Branding|App Icons & Branding]]
- [[_COMMUNITY_iOS Icon Assets|iOS Icon Assets]]
- [[_COMMUNITY_iOS Launch Assets|iOS Launch Assets]]
- [[_COMMUNITY_Plugin Registration|Plugin Registration]]
- [[_COMMUNITY_iOS Unit Tests|iOS Unit Tests]]
- [[_COMMUNITY_Android Main Activity|Android Main Activity]]
- [[_COMMUNITY_iOS Plugin Registration|iOS Plugin Registration]]
- [[_COMMUNITY_Flutter Widget Tests|Flutter Widget Tests]]
- [[_COMMUNITY_Flutter Environment|Flutter Environment]]
- [[_COMMUNITY_Home Screen Widget|Home Screen Widget]]
- [[_COMMUNITY_Weather Card Widget|Weather Card Widget]]
- [[_COMMUNITY_Live Map Widget|Live Map Widget]]

## God Nodes (most connected - your core abstractions)
1. `travel_buddy Pubspec` - 26 edges
2. `project_info` - 4 edges
3. `_SosScreenState` - 4 edges
4. `_SpeedScreenState` - 4 edges
5. `_SplashScreenState` - 4 edges
6. `Build Flutter Web Job` - 4 edges
7. `RunnerTests` - 3 edges
8. `AppDelegate` - 3 edges
9. `info` - 3 edges
10. `info` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Build Android APK Job` --conceptually_related_to--> `travel_buddy Pubspec`  [INFERRED]
  .github/workflows/build.yml → pubspec.yaml
- `Build Flutter Web Job` --conceptually_related_to--> `travel_buddy Pubspec`  [INFERRED]
  .github/workflows/build.yml → pubspec.yaml
- `Build Flutter Web Job` --conceptually_related_to--> `Web Index HTML Entry Point`  [INFERRED]
  .github/workflows/build.yml → web/index.html
- `iOS Launch Screen Assets` --conceptually_related_to--> `TravelBuddy Project`  [INFERRED]
  ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md → README.md
- `TravelBuddy Project` --conceptually_related_to--> `travel_buddy Pubspec`  [INFERRED]
  README.md → pubspec.yaml

## Import Cycles
- None detected.

## Communities (73 total, 9 thin omitted)

### Community 0 - "Live Map & Navigation"
Cohesion: 0.03
Nodes (66): dart:ui, GoogleMapController?, package:google_maps_flutter/google_maps_flutter.dart, _accuracy, _activeTeamId, _activeTeamName, _addWaypoint, _badgeIcon (+58 more)

### Community 1 - "Screen Imports Hub"
Cohesion: 0.04
Nodes (55): blog_screen.dart, community_feed_screen.dart, document_wallet_screen.dart, emergency_info_screen.dart, expense_analytics_screen.dart, fuel_track_screen.dart, group_expense_screen.dart, live_map_screen.dart (+47 more)

### Community 2 - "Community Feed & Posts"
Cohesion: 0.05
Nodes (39): create_trip_post_screen.dart, MaterialPageRoute, build, _buildQuery, _chip, CommunityFeedScreen, _CommunityFeedScreenState, createState (+31 more)

### Community 3 - "Document Wallet & Storage"
Cohesion: 0.05
Nodes (38): dart:convert, DateTime, location_service.dart, _addDocument, build, _categories, createState, _docsRef (+30 more)

### Community 4 - "Nearby Places Service"
Cohesion: 0.06
Nodes (36): LatLng get, out center body, package:http/http.dart, package:latlong2/latlong.dart, 50, address, category, emoji (+28 more)

### Community 5 - "Emergency Info & Contacts"
Cohesion: 0.06
Nodes (35): List, package:url_launcher/url_launcher.dart, build, _countries, _CountryInfo, createState, EmergencyInfoScreen, _EmergencyInfoScreenState (+27 more)

### Community 6 - "Trip Post Creation"
Cohesion: 0.05
Nodes (37): _addHotel, _addRoad, _avoidCtrl, _bestSeason, build, _buildBasics, _buildCosts, _buildHotels (+29 more)

### Community 7 - "Expense Analytics"
Cohesion: 0.06
Nodes (32): dart:math, package:intl/intl.dart, build, _categoryColors, _categoryIcons, createState, ExpenseAnalyticsScreen, _ExpenseAnalyticsScreenState (+24 more)

### Community 8 - "Project Config & Dependencies"
Cohesion: 0.07
Nodes (34): Dart Analysis Options, flutter_lints Package, iOS Launch Screen Assets, cached_network_image Dependency, cloud_firestore Dependency, Dart SDK ^3.6.2, firebase_auth Dependency, firebase_core Dependency (+26 more)

### Community 9 - "Location & Chat Services"
Cohesion: 0.06
Nodes (32): dart:async, ../screens/team_chat_screen.dart, _auth, distanceBetween, _firestore, formatSpeed, getCurrentPosition, getTeamLocations (+24 more)

### Community 10 - "Currency Converter"
Cohesion: 0.07
Nodes (30): double?, Map, _amountCtrl, build, _convert, createState, CurrencyConverterScreen, _CurrencyConverterScreenState (+22 more)

### Community 11 - "Blog & Media Upload"
Cohesion: 0.07
Nodes (27): dart:typed_data, package:cached_network_image/cached_network_image.dart, package:firebase_storage/firebase_storage.dart, package:image_picker/image_picker.dart, _blogPostCard, BlogScreen, _BlogScreenState, build (+19 more)

### Community 12 - "Discover Places"
Cohesion: 0.08
Nodes (25): double lat, lon,, out body, 20, build, _Cat, _categories, color, createState (+17 more)

### Community 13 - "Route Optimization"
Cohesion: 0.09
Nodes (23): _addStop, build, createState, _formatDuration, fullName, lat, lon, name (+15 more)

### Community 14 - "Smart Packing"
Cohesion: 0.09
Nodes (22): build, category, _checked, _configChip, createState, _generateSuggestions, icon, initState (+14 more)

### Community 15 - "Vehicle Maintenance"
Cohesion: 0.11
Nodes (18): int kmInterval,, _addReminder, build, color, createState, dayInterval, _deco, icon (+10 more)

### Community 16 - "Group Expenses"
Cohesion: 0.12
Nodes (18): _addExpense, build, _calculateBalances, _createGroup, createState, _expensesRef, _firestore, groupData (+10 more)

### Community 17 - "Trip Templates"
Cohesion: 0.12
Nodes (17): Color, budget, build, color, createState, emoji, _filter, packing (+9 more)

### Community 18 - "Mileage Calculator"
Cohesion: 0.12
Nodes (17): build, _calculate, _costPerKm, createState, dispose, _distCtrl, _fuelCtrl, _inputField (+9 more)

### Community 19 - "Speedometer & GPS"
Cohesion: 0.11
Nodes (17): _altitude, _avgSpeed, build, createState, dispose, _getSpeedColor, initState, _maxSpeed (+9 more)

### Community 20 - "Travel Alerts"
Cohesion: 0.12
Nodes (16): IconData, _addAlert, _alertCard, _alertsRef, _AlertTemplate, build, category, color (+8 more)

### Community 21 - "Trip Post Details"
Cohesion: 0.13
Nodes (15): DocumentReference get, build, _cloneTrip, createState, _dayLine, _liked, postId, _postRef (+7 more)

### Community 22 - "Travel Badges & Gamification"
Cohesion: 0.13
Nodes (15): _allBadges, _Badge, _badgeCard, build, createState, desc, icon, id (+7 more)

### Community 23 - "Toll Calculator"
Cohesion: 0.14
Nodes (14): _amtCtrl, build, createState, dispose, _nameCtrl, _returnTrip, _saveToll, TollCalculatorScreen (+6 more)

### Community 24 - "Team Management Service"
Cohesion: 0.13
Nodes (14): _auth, createTeam, deleteTeam, _email, _firestore, _generateInviteCode, getMyTeams, getTeam (+6 more)

### Community 25 - "Fuel Tracking Screen"
Cohesion: 0.15
Nodes (13): build, createState, _dialogField, FuelTrackScreen, _FuelTrackScreenState, _logChip, _mileageColor, _pickMode (+5 more)

### Community 26 - "Fuel Price Comparison"
Cohesion: 0.17
Nodes (12): build, createState, _deco, FuelPriceScreen, _FuelPriceScreenState, _fuelType, _logPrice, _priceRef (+4 more)

### Community 27 - "Trip Sharing"
Cohesion: 0.17
Nodes (12): build, createState, _firestore, _loadSharedTrip, _sharedRef, _shareTrip, TripSharingScreen, _TripSharingScreenState (+4 more)

### Community 28 - "Expense Service"
Cohesion: 0.15
Nodes (12): addExpense, _auth, calculateBalances, categories, deleteExpense, ExpenseService, _expensesRef, _firestore (+4 more)

### Community 29 - "Trip Service"
Cohesion: 0.15
Nodes (12): addFuelLog, _auth, endTrip, _firestore, getActiveTrips, getTripHistory, getTripStats, _name (+4 more)

### Community 30 - "SOS Emergency Screen"
Cohesion: 0.17
Nodes (11): AnimationController, package:geolocator/geolocator.dart, build, createState, dispose, _infoRow, initState, _isSending (+3 more)

### Community 31 - "Checklist & Tasks"
Cohesion: 0.18
Nodes (11): _addItem, build, _checklistRef, ChecklistScreen, _ChecklistScreenState, createState, _firestore, _pickMode (+3 more)

### Community 32 - "Splash & Auth Animation"
Cohesion: 0.18
Nodes (10): Animation, auth_screen.dart, build, _controller, createState, dispose, _fadeIn, initState (+2 more)

### Community 33 - "Trip Cost Tracking"
Cohesion: 0.20
Nodes (10): CollectionReference get, build, _categories, _costsRef, createState, _firestore, _showAddExpense, TripCostScreen (+2 more)

### Community 34 - "Screen State Management"
Cohesion: 0.27
Nodes (11): AuthScreen, _AuthScreenState, SosScreen, _SosScreenState, SpeedScreen, _SpeedScreenState, SplashScreen, _SplashScreenState (+3 more)

### Community 35 - "Budget Planner"
Cohesion: 0.20
Nodes (10): _addExpense, BudgetPlannerScreen, _BudgetPlannerScreenState, _budgetRef, build, _categoryConfig, _createBudget, createState (+2 more)

### Community 36 - "Expense Screen"
Cohesion: 0.20
Nodes (10): build, createState, ExpenseScreen, _ExpenseScreenState, _pickMode, _selectedLabel, _selectedTeamId, _showAddExpense (+2 more)

### Community 37 - "Teams Screen"
Cohesion: 0.20
Nodes (10): build, createState, _emptyState, _headerButton, _showCreateTeamDialog, _showJoinTeamDialog, TeamsScreen, _TeamsScreenState (+2 more)

### Community 38 - "POI Service"
Cohesion: 0.18
Nodes (10): addPoi, _auth, categories, deletePoi, _firestore, getTeamPois, _name, PoiService (+2 more)

### Community 39 - "Web App Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 40 - "Google Auth Flow"
Cohesion: 0.20
Nodes (9): home_screen.dart, package:google_sign_in/google_sign_in.dart, build, createState, _featureChip, _initialized, _isLoading, _signInWithGoogle (+1 more)

### Community 41 - "Fuel Service"
Cohesion: 0.20
Nodes (9): package:cloud_firestore/cloud_firestore.dart, addFuelLog, deleteFuelLog, _firestore, FuelService, getFuelLogs, getStats, _logsRef (+1 more)

### Community 42 - "Travel Journal"
Cohesion: 0.22
Nodes (9): QuerySnapshot, _addEntry, build, createState, _journalRef, _timeAgo, TravelJournalScreen, _TravelJournalScreenState (+1 more)

### Community 43 - "Packing Lists"
Cohesion: 0.22
Nodes (9): build, createState, _firestore, _listsRef, PackingListScreen, _PackingListScreenState, _showAddItem, _showCreateList (+1 more)

### Community 44 - "Trip Planner"
Cohesion: 0.22
Nodes (9): build, createState, _firestore, _showCreateTrip, TripPlannerScreen, _TripPlannerScreenState, _tripsRef, _uid (+1 more)

### Community 45 - "Chat Service"
Cohesion: 0.20
Nodes (9): _auth, ChatService, _firestore, getMessages, hasUnread, markAsRead, _messagesRef, sendMessage (+1 more)

### Community 46 - "Emergency Contact Service"
Cohesion: 0.20
Nodes (9): addContact, _collection, deleteContact, EmergencyContactService, _firestore, getContacts, _uid, static CollectionReference get (+1 more)

### Community 47 - "Team Details & Sharing"
Cohesion: 0.22
Nodes (8): DocumentSnapshot, package:flutter/services.dart, package:share_plus/share_plus.dart, _inviteSection, _memberTile, teamId, ../services/team_service.dart, team_chat_screen.dart

### Community 48 - "Dashboard & Settings"
Cohesion: 0.22
Nodes (9): TravelBuddyApp, _DashboardTab, _LiveStats, _RecentActivity, _TripCountdown, SettingsScreen, TeamDetailScreen, StatelessWidget (+1 more)

### Community 49 - "App Entry Point"
Cohesion: 0.25
Nodes (7): firebase_options.dart, build, initializeApp, main, package:flutter/material.dart, package:google_fonts/google_fonts.dart, screens/splash_screen.dart

### Community 50 - "Firebase Configuration"
Cohesion: 0.25
Nodes (7): android, DefaultFirebaseOptions, ios, web, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 51 - "Trip Log Service"
Cohesion: 0.25
Nodes (7): deleteEntry, _firestore, getTripLog, logCheckpoint, TripLogService, _uid, static String? get

### Community 52 - "iOS App Delegate"
Cohesion: 0.29
Nodes (5): Any, Bool, FlutterAppDelegate, AppDelegate, UIApplication

### Community 53 - "Google Services Config"
Cohesion: 0.29
Nodes (6): client, configuration_version, project_info, project_id, project_number, storage_bucket

### Community 54 - "ETA Service"
Cohesion: 0.29
Nodes (6): package:firebase_auth/firebase_auth.dart, clearEta, EtaService, _firestore, getActiveEtas, shareEta

### Community 55 - "App Icons & Branding"
Cohesion: 0.40
Nodes (6): iOS App Icon (Flutter Default), iOS Launch Image (Blank Placeholder), Android Launcher Icon (Flutter Default), Web Favicon (Flutter Default), Web Maskable Icon (Flutter Default), Web Standard Icon (Flutter Default)

### Community 56 - "iOS Icon Assets"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 57 - "iOS Launch Assets"
Cohesion: 0.40
Nodes (4): images, info, author, version

## Knowledge Gaps
- **747 isolated node(s):** `project_number`, `project_id`, `storage_bucket`, `client`, `configuration_version` (+742 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `latLng` connect `Nearby Places Service` to `Live Map & Navigation`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **Why does `WeatherData` connect `Document Wallet & Storage` to `Screen Imports Hub`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **Why does `LiveMapScreen` connect `Live Map Widget` to `Live Map & Navigation`, `Screen State Management`?**
  _High betweenness centrality (0.001) - this node is a cross-community bridge._
- **What connects `project_number`, `project_id`, `storage_bucket` to the rest of the system?**
  _747 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Live Map & Navigation` be split into smaller, more focused modules?**
  _Cohesion score 0.029850746268656716 - nodes in this community are weakly interconnected._
- **Should `Screen Imports Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.03571428571428571 - nodes in this community are weakly interconnected._
- **Should `Community Feed & Posts` be split into smaller, more focused modules?**
  _Cohesion score 0.05365853658536585 - nodes in this community are weakly interconnected._