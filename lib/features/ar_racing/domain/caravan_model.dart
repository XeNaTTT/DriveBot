class CaravanModel {
  const CaravanModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.speed,
    required this.handling,
    required this.durability,
  });

  final String id;
  final String name;
  final String subtitle;
  final int speed;
  final int handling;
  final int durability;
}

const caravanModels = <CaravanModel>[
  CaravanModel(
    id: 'sport',
    name: 'FAMILY CRUISER',
    subtitle: 'Ausgewogener Alkoven-Camper',
    speed: 92,
    handling: 88,
    durability: 58,
  ),
  CaravanModel(
    id: 'offroad',
    name: 'EXPEDITION BEAST',
    subtitle: 'Mehr Bodenfreiheit & Federweg',
    speed: 74,
    handling: 72,
    durability: 94,
  ),
  CaravanModel(
    id: 'compact',
    name: 'URBAN CAMPER',
    subtitle: 'Wendiger Stadtcamper',
    speed: 84,
    handling: 95,
    durability: 78,
  ),
];
