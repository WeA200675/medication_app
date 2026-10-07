# Medikationsplan

Flutter-App zur persönlichen Verwaltung von Medikamenten, lokalen Einnahmeerinnerungen, Arztkontakten und medizinischen Dokumenten.

> **Status:** Entwicklungs- und Testversion. Nicht zur Diagnose, Therapieentscheidung oder Änderung ärztlicher Verordnungen verwenden. OCR-Ergebnisse können falsch sein und müssen immer anhand des Originals geprüft werden. Erinnerungen können durch Geräteeinstellungen, Berechtigungen, Energiesparfunktionen oder Betriebssystemverhalten ausbleiben. Sie ersetzen keine Packungsbeilage, ärztliche Anweisung oder persönliche Erinnerung.

## Funktionsumfang

- Lokaler Medikationsplan mit Dosierung, Einnahmezeit und ausgewählten Wochentagen
- Wiederkehrende lokale Erinnerungen
- Arztkontakte sowie Scan und Ablage medizinischer Dokumente
- Lokale PDF-Funktionen und manuelle Backups

Die App verwendet derzeit eine lokale SQLite-Datenbank und lokale Profileinstellungen. Backups und E-Mail-Funktionen können Gesundheits- und Stammdaten außerhalb des Geräts weitergeben. Vor dem Teilen bitte Inhalt und Empfänger prüfen. In dieser Version gibt es keine Anmeldung und keine geräteübergreifende Synchronisation. Die Arztsuche übermittelt die eingegebene Suchanfrage an den öffentlichen Dienst OpenStreetMap Nominatim; bitte dort keine Patientennamen oder identifizierenden Angaben eingeben. Eine Online-Suche ist optional, Arztkontakte können manuell erfasst werden.

## Voraussetzungen und Entwicklung

- Flutter/Dart entsprechend den SDK-Grenzen in pubspec.yaml
- Android Studio/Android SDK für Android
- macOS mit Xcode für iOS

    flutter pub get
    flutter analyze
    flutter test
    flutter run

Die Repository-CI führt Analyse, Tests und einen Android-Debug-Build aus. Ein grüner CI-Lauf ersetzt keine Tests auf echten Geräten.

## Android-Release

Der Release-Build verwendet **keinen Debug-Schlüssel**. Lege lokal android/key.properties mit folgenden Werten an (nicht einchecken):

    storeFile=/absoluter/pfad/zum/upload-keystore.jks
    storePassword=...
    keyAlias=...
    keyPassword=...

Dann:

    flutter build appbundle --release

Vor einer Veröffentlichung müssen außerdem eindeutige, dem Herausgeber gehörende Android- und iOS-Paketkennungen, Store-Metadaten, Datenschutzinformationen, Supportkontakt und Release-Schlüssel festgelegt werden. Die aktuellen Paketkennungen sind noch Flutter-Beispielwerte; Änderungen nach dem ersten Store-Release wären inkompatible neue App-Pakete.

## Vor einem öffentlichen Rollout

1. Erinnerungserlaubnisse, genaue Alarme, Neustart, Zeitzonen- und Sommerzeitwechsel auf unterstützten Android- und iOS-Geräten testen.
2. Speicher- und Backup-Schutz, Lösch-/Exportverhalten und Datenweitergabe fachlich und datenschutzrechtlich prüfen. Sensible lokale Daten sind in dieser Version noch nicht durch app-seitige Verschlüsselung geschützt.
3. Datenbankmigrationen, Backup-Wiederherstellung, OCR-Fehlerfälle und Barrierefreiheit automatisiert und manuell testen.
4. Zweckbestimmung sowie eine mögliche Einordnung als Medizinprodukt fachkundig klären, bevor medizinische Wirkversprechen oder Empfehlungen kommuniziert werden.

## Lizenz und Kontakt

Für Release, Datenschutzanfragen und Sicherheitsmeldungen müssen vor Veröffentlichung Verantwortliche und Kontaktwege ergänzt werden.
