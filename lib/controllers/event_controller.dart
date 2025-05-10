import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/event_model.dart';
import '../core/services/notification_service.dart';
import '../core/utils/app_constants.dart';

class EventController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  List<EventModel> _events = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  DateTime _lastFetchTime = DateTime.now();

  List<EventModel> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<EventModel> get upcomingEvents =>
      _events.where((event) => event.date.isAfter(DateTime.now())).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<EventModel> get pastEvents =>
      _events.where((event) => event.date.isBefore(DateTime.now())).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  // Initialize and fetch events from Firestore
  Future<void> init() async {
    await fetchEvents();

    // Set up very frequent background refresh to ensure we catch events quickly
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkForNewEvents();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Check for new events since last fetch
  Future<void> checkForNewEvents() async {
    try {
      // Query Firestore for events created after the last fetch time
      final snapshot =
          await _firestore
              .collection(AppConstants.eventsCollection)
              .where('createdAt', isGreaterThan: _lastFetchTime)
              .get();

      if (snapshot.docs.isNotEmpty) {
        // Process each new event
        for (final doc in snapshot.docs) {
          final eventData = doc.data();
          final newEvent = EventModel.fromJson(eventData, doc.id);

          // Check if this event is already in our list
          final existingIndex = _events.indexWhere((e) => e.id == newEvent.id);
          if (existingIndex >= 0) {
            _events[existingIndex] = newEvent;
            debugPrint('🔄 Updated existing event: ${newEvent.title}');
          } else {
            _events.add(newEvent);

            // Send notification - Fire and forget, don't block
            _sendNotification(newEvent);
          }
        }

        // Update last fetch time
        _lastFetchTime = DateTime.now();

        // Notify listeners of new events
        notifyListeners();
      } else {
        debugPrint('📅 No new events found');
      }
    } catch (e) {}
  }

  // Helper method to send notification without blocking
  Future<void> _sendNotification(EventModel event) async {
    try {
      // Send notification through notification service
      final success = await _notificationService.sendEventNotification(event);
    } catch (e) {}
  }

  // Admin can add events with type selection and no image URL
  Future<bool> addEventAdmin({
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    String? imageUrl,
    String type = 'event',
    BuildContext? context,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create event data
      final eventData = {
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'time': time,
        'location': location,
        'createdBy': 'admin',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'type': type,
      };

      // Add to Firestore
      try {
        final docRef = await _firestore
            .collection(AppConstants.eventsCollection)
            .add(eventData);

        // Wait a moment to ensure the server timestamp is processed
        await Future.delayed(const Duration(milliseconds: 500));

        // Get the full document with server timestamp
        final docSnapshot = await docRef.get();
        final createdEventData = docSnapshot.data() ?? {};

        // Extract the server timestamp
        Timestamp? serverTimestamp;
        try {
          serverTimestamp = createdEventData['createdAt'] as Timestamp?;
        } catch (e) {}

        // Add to local events
        final event = EventModel(
          id: docRef.id,
          title: title,
          description: description,
          date: date,
          time: time,
          location: location,
          createdBy: 'admin',
          createdAt: serverTimestamp?.toDate() ?? DateTime.now(),
          type: type,
        );

        _events.add(event);
        notifyListeners();

        // Update last fetch time to include this event
        _lastFetchTime = DateTime.now();

        // Send push notification
        final notificationSent = await _notificationService
            .sendEventNotification(event);

        return true;
      } catch (e) {
        _error = 'Failed to add event to database: $e';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create an event as admin
  Future<bool> createAdminEvent({
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    String? imageUrl,
    BuildContext? context,
  }) async {
    return addEventAdmin(
      title: title,
      description: description,
      date: date,
      time: time,
      location: location,
      imageUrl: imageUrl,
      type: 'event',
      context: context,
    );
  }

  // Fetch all events from Firestore
  Future<void> fetchEvents() async {
    try {
      _isLoading = true;
      notifyListeners();

      try {
        // Fetch from Firestore
        final snapshot =
            await _firestore.collection(AppConstants.eventsCollection).get();

        _events =
            snapshot.docs
                .map((doc) => EventModel.fromJson(doc.data(), doc.id))
                .toList();

        // Update last fetch time
        _lastFetchTime = DateTime.now();

        if (_events.isEmpty) {
          debugPrint('✅ No events found in Firestore');
        } else {
          debugPrint('✅ Fetched ${_events.length} events from Firestore');
        }
      } catch (e) {
        _error = 'Error fetching events from Firestore: $e';
        debugPrint('⚠️ $_error');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get a single event
  EventModel? getEventById(String eventId) {
    try {
      return _events.firstWhere((event) => event.id == eventId);
    } catch (e) {
      return null;
    }
  }

  // Clear errors
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
