# AGENTS.md

## Scope
These instructions apply to the full repository.

## Project Rules
- Keep architecture modular and feature-driven.
- Prefer small, composable widgets.
- Keep UI safe for driving:
  - high contrast
  - large typography
  - minimal cognitive load
- Use mock repositories and services by default in the MVP.
- Avoid hard-coding API-specific logic into presentation layer.
- Domain models should be UI-agnostic.
- Add/update tests for domain logic and critical UI composition.
- Keep docs in sync with architecture changes.

## Coding Conventions
- Use immutable classes where practical.
- Keep methods concise and intention-revealing.
- Favor constructor dependency injection for services.
- Keep files focused (single responsibility).

## PR Expectations
- Summarize architecture impact.
- List checks run (`flutter analyze`, `flutter test`, etc.).
- Call out known limitations clearly.
