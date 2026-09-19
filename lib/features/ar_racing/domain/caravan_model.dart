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
    id: 'sport',
    name: 'SPRINT SPORT',
    subtitle: 'Direkte Lenkung & kräftiger Antrieb',
    color: Color(0xFFD8DDD8),
    accent: Color(0xFFFF5A36),
    speed: 92,
    handling: 88,
    durability: 58,
  ),
  CaravanModel(
    id: 'offroad',
    name: 'TRAIL OFFROAD',
    subtitle: 'Mehr Bodenfreiheit & Federweg',
    color: Color(0xFFCFD3C8),
    accent: Color(0xFFD8FF3E),
    speed: 74,
    handling: 72,
    durability: 94,
  ),
  CaravanModel(
    id: 'compact',
    name: 'CITY COMPACT',
    subtitle: 'Gutmütig & kontrollierbar',
    color: Color(0xFFD7DBE2),
    accent: Color(0xFF8A6CFF),
    speed: 84,
    handling: 82,
    durability: 78,
  ),
];
