# Drive Assistant

Der optionale Drive-Assistant-Modus leitet aus der bereits vorhandenen GPS-Geschwindigkeit eine Schaltempfehlung ab. Der Fahrer schaltet die Ansicht über das Tachometer-Symbol im HUD ein und aus.

## Architektur

- `VehicleShiftProfile` hält fahrzeugspezifische, UI-unabhängige Übersetzungs- und Drehzahlwerte. Im MVP ist ausschließlich der **Citroën Jumper, Baujahr 2020, 6-Gang-Diesel** vorkonfiguriert.
- `ShiftAdvisor` berechnet für jeden möglichen Gang die theoretische Motordrehzahl und wählt den Gang nahe der Mitte des sparsamen Drehzahlbands. Im Stillstand werden erster Gang und Leerlaufdrehzahl angezeigt.
- `DriveAssistantPanel` visualisiert das Sparband grün, den Bereich maximaler Kraft orange, die simulierte Drehzahl und den empfohlenen Gang.

## Grenzen des MVP

Die Anzeige liest keine Motordaten über OBD/CAN. Drehzahl und Gang sind Schätzwerte auf Basis der GPS-Geschwindigkeit und eines generischen Jumper-2020-Antriebsprofils; Bereifung, konkrete Motor-/Getriebevariante, Beladung und Steigung werden noch nicht berücksichtigt. Die Empfehlung ersetzt weder die Fahrzeuganzeige noch die Beurteilung des Fahrers.
