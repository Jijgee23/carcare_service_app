import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/notifications/domain/notification_item.dart';
import 'package:carcare_service/features/notifications/domain/notifications_repository.dart';

/// A typed parse failure kept at the data boundary. The remote adapter maps
/// it to an [AppError] before it crosses into the controller.
class NotificationParseException implements Exception {
  const NotificationParseException(this.message);

  final String message;

  @override
  String toString() => 'NotificationParseException: $message';
}

class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NotificationParseException('Мэдэгдлийн өгөгдөл буруу байна.');
    }
    final json = Map<String, dynamic>.from(raw);
    return NotificationDto(
      id: _requiredString(json, 'id'),
      type: _requiredString(json, 'type'),
      title: _requiredString(json, 'title'),
      body: _requiredString(json, 'body'),
      data: _optionalMap(json['data']),
      readAt: _optionalDate(json['readAt']),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationItem toDomain() => NotificationItem(
    id: id,
    type: type,
    title: title,
    body: body,
    data: data,
    readAt: readAt,
    createdAt: createdAt,
  );
}

class NotificationPageDto {
  const NotificationPageDto({
    required this.notifications,
    required this.pagination,
    required this.unreadCount,
  });

  factory NotificationPageDto.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NotificationParseException('Мэдэгдлийн хариу буруу байна.');
    }
    final json = Map<String, dynamic>.from(raw);
    final rawItems = json['notifications'];
    if (rawItems is! List) {
      throw const NotificationParseException(
        'Мэдэгдлийн жагсаалт буруу байна.',
      );
    }
    final pagination = json['pagination'];
    if (pagination is! Map) {
      throw const NotificationParseException(
        'Хуудаслалтын мэдээлэл буруу байна.',
      );
    }
    return NotificationPageDto(
      notifications: rawItems
          .map(NotificationDto.fromJson)
          .toList(growable: false),
      pagination: _paginationFromJson(pagination),
      unreadCount: _requiredInt(json, 'unreadCount'),
    );
  }

  final List<NotificationDto> notifications;
  final PaginationMeta pagination;
  final int unreadCount;

  NotificationPage toDomain() => (
    items: notifications.map((item) => item.toDomain()).toList(growable: false),
    pagination: pagination,
    unreadCount: unreadCount,
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw NotificationParseException('Мэдэгдлийн $key талбар буруу байна.');
  }
  return value.trim();
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  throw NotificationParseException('Мэдэгдлийн огноо буруу байна.');
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, dynamic> _optionalMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(value));
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw NotificationParseException('Мэдэгдлийн $key талбар буруу байна.');
}

PaginationMeta _paginationFromJson(Map raw) {
  final json = Map<String, dynamic>.from(raw);
  return PaginationMeta(
    page: _requiredInt(json, 'page'),
    pageSize: _requiredInt(json, 'pageSize'),
    total: _requiredInt(json, 'total'),
    totalPages: _requiredInt(json, 'totalPages'),
    hasPrev: _requiredBool(json, 'hasPrev'),
    hasNext: _requiredBool(json, 'hasNext'),
  );
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw NotificationParseException('Мэдэгдлийн $key талбар буруу байна.');
}
