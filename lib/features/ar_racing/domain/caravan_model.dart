import 'package:flutter/material.dart';

@immutable
class CaravanModel {
  const CaravanModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.accent,
    required this.speed,
    required this.handling,
    required this.durability,
  });

  final String id;
  final String name;
  final String subtitle;
  final Color color;
  final Color accent;
  final int speed;
  final int handling;
  final int durability;
}

const caravanModels = <CaravanModel>[
  CaravanModel(
    id: 'comet',
    name: 'COMET 350',
    subtitle: 'Agil & schnell',
    color: Color(0xFFD8DDD8),
    accent: Color(0xFFFF5A36),
    speed: 92,
    handling: 88,
    durability: 58,
  ),
  CaravanModel(
    id: 'terra',
    name: 'TERRA X',
    subtitle: 'Geländetauglich',
    color: Color(0xFFCFD3C8),
    accent: Color(0xFFD8FF3E),
    speed: 74,
    handling: 72,
    durability: 94,
  ),
  CaravanModel(
    id: 'neon',
    name: 'NEON 520',
    subtitle: 'Perfekt ausbalanciert',
    color: Color(0xFFD7DBE2),
    accent: Color(0xFF8A6CFF),
    speed: 84,
    handling: 82,
    durability: 78,
  ),
];
