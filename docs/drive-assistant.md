# Drive Assistant

Der optionale Drive-Assistant-Modus leitet aus der bereits vorhandenen GPS-Geschwindigkeit eine Schaltempfehlung ab. Der Fahrer schaltet die Ansicht über das Tachometer-Symbol im HUD ein und aus.

## Architektur

- `VehicleShiftProfile` hält fahrzeugspezifische, UI-unabhängige Übersetzungen, Drehzahlwerte und Zugkraft-Kurven. Im MVP ist ausschließlich der **Citroën Jumper, Baujahr 2020, 6-Gang-Diesel** vorkonfiguriert.
- `ShiftAdvisor` bestimmt ohne Gangsignal einen effizienten Gang. `DriveTelemetryCalculator` berechnet für einen übermittelten oder geschätzten Gang Drehzahl, linear interpolierte Radzugkraft, Effizienzzone, Coaching und kontextbezogene Fakten.
- `DriveAssistantPanel` zeichnet den Live-Zeiger auf der aktiven Zugkraftkurve und priorisiert Geschwindigkeit, Gang, Drehzahl und eine einzige Handlungsaufforderung. Eine links abgetragene Newton-Skala und horizontale Hilfslinien machen die Zugkraft direkt ablesbar. Die geglättete Kurve erhält eine farbige Verlaufsfläche: Das grün hinterlegte Kurvenband wird aus Übersetzung und Eco-Drehzahlbereich für den aktiven Gang berechnet; orange Kurvenabschnitte liegen außerhalb des verbrauchsarmen Zielbereichs. Die halbtransparente, weichgezeichnete Oberfläche bildet Apples Liquid-Glass-Anmutung mit Flutter-Primitiven plattformübergreifend nach.

## Effizienz- und Hinweislogik

- Grün (`OPTIMAL`): 1.800–2.200 U/min.
- Turboloch-Warnung: unter 1.500 U/min; hohe Drehzahl: über 2.600 U/min, verschärft über 3.200 U/min.
- Fakten werden bei 35–40 km/h, beim effizienten Cruisen in Gang 6 bei 105–115 km/h und bei einer untertourigen Autobahn-Steigung eingeblendet.

## Grenzen des MVP

Die Anzeige liest keine Motordaten über OBD/CAN. Drehzahl und Gang sind Schätzwerte auf Basis der GPS-Geschwindigkeit; Beladung, Schlupf und Steigung werden noch nicht gemessen. Ohne natives Gangsignal wählt der MVP den effizientesten plausiblen Gang. Flutter stellt keine öffentliche iOS-27-Liquid-Glass-API bereit; deshalb nutzt die aktuelle Implementierung einen sicheren `BackdropFilter`-Fallback statt nicht verfügbarer oder privater SDK-Aufrufe. Die Empfehlung ersetzt weder die Fahrzeuganzeige noch die Beurteilung des Fahrers.
