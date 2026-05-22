# Product Brief: DriveAssistant AR

## Vision
DriveAssistant AR provides a calm, safety-first augmented-reality style assistant for drivers. It surfaces only high-value context that can improve situational awareness with minimal distraction.

## Problem
Driving environments are information-dense. Existing apps often require frequent visual/context switching and expose too much detail at once.

## MVP Goal
Deliver a technical foundation with a HUD-style interface and mock data flow to validate architecture and UI interaction patterns before integrating live APIs.

## Core UX Principles
- Minimal visual clutter.
- Large, high-contrast elements.
- Prioritize warnings and actionable context.
- No interaction patterns that demand prolonged visual attention.

## MVP Features
- Camera-style placeholder background.
- Top status telemetry (speed, heading, GPS signal).
- Central HUD summary.
- Warning card stream for nearby events.

## Non-Goals (for this phase)
- Real sensor/camera integration.
- External API integration.
- Production-grade routing.
- Full offline support.

## Next Milestones
1. Integrate device location and heading streams.
2. Add camera background feed abstraction.
3. Implement real data-source adapters behind repository interfaces.
4. Add risk-prioritization and deduplication engine for warnings.
