class Vehicle {
  final String? id;
  final String? ownerId;
  final String make;
  final String model;
  final int year;
  final String? vin;
  final bool isConnected;

  const Vehicle({
    this.id,
    this.ownerId,
    required this.make,
    required this.model,
    required this.year,
    this.vin,
    this.isConnected = false,
  });

  String get displayName => '$make $model';
  String get fullDisplayName => '$make $model \u2022 $year';

  Vehicle copyWith({
    String? id,
    String? ownerId,
    String? make,
    String? model,
    int? year,
    String? vin,
    bool? isConnected,
  }) {
    return Vehicle(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      vin: vin ?? this.vin,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
