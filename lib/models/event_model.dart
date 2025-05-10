import '../core/utils/serialization_helpers.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String createdBy;
  final DateTime createdAt;
  final String type; // 'event' or 'lecture'

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.createdBy,
    required this.createdAt,
    this.type = 'event', // Default to 'event'
  });

  factory EventModel.fromJson(Map<String, dynamic> json, String id) {
    return EventModel(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: SerializationHelpers.parseDateTime(json['date']) ?? DateTime.now(),
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt:
          SerializationHelpers.parseDateTime(json['createdAt']) ??
          DateTime.now(),
      type: json['type'] ?? 'event', // Default to 'event' if not set
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'type': type,
    };

    // Use SerializationHelpers to handle timestamps
    return SerializationHelpers.serializeFirestoreData(map)
        as Map<String, dynamic>;
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    String? createdBy,
    String? imageUrl,
    DateTime? createdAt,
    String? type,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
    );
  }

  bool get isUpcoming => date.isAfter(DateTime.now());
}
