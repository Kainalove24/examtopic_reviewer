
class Voucher {
  final String id;
  final String code;
  final String name;
  final String? examId; // Link to specific exam
  final Map<String, dynamic>? examData; // Embedded exam data for web deployment
  final Duration?
  examExpiryDuration; // Duration for the redeemed exam to expire
  final DateTime createdDate;
  final DateTime expiryDate;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedDate;

  Voucher({
    required this.id,
    required this.code,
    required this.name,
    this.examId,
    this.examData,
    this.examExpiryDuration,
    required this.createdDate,
    required this.expiryDate,
    this.isUsed = false,
    this.usedBy,
    this.usedDate,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? 'Unnamed Voucher',
      examId: json['examId'],
      examData: json['examData'],
      examExpiryDuration: json['examExpiryDuration'] != null
          ? Duration(microseconds: json['examExpiryDuration'])
          : null,
      createdDate: DateTime.parse(json['createdDate']),
      expiryDate: DateTime.parse(json['expiryDate']),
      isUsed: json['isUsed'] ?? false,
      usedBy: json['usedBy'],
      usedDate: json['usedDate'] != null
          ? DateTime.parse(json['usedDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'examId': examId,
      'examData': examData,
      'examExpiryDuration': examExpiryDuration?.inMicroseconds,
      'createdDate': createdDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedDate': usedDate?.toIso8601String(),
    };
  }

  Voucher copyWith({
    String? id,
    String? code,
    String? name,
    String? examId,
    Map<String, dynamic>? examData,
    Duration? examExpiryDuration,
    DateTime? createdDate,
    DateTime? expiryDate,
    bool? isUsed,
    String? usedBy,
    DateTime? usedDate,
  }) {
    return Voucher(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      examId: examId ?? this.examId,
      examData: examData ?? this.examData,
      examExpiryDuration: examExpiryDuration ?? this.examExpiryDuration,
      createdDate: createdDate ?? this.createdDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isUsed: isUsed ?? this.isUsed,
      usedBy: usedBy ?? this.usedBy,
      usedDate: usedDate ?? this.usedDate,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isValid => !isUsed && !isExpired;
}
