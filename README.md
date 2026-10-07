# Medikationsplan

Flutter-App zur persönlichen Verwaltung von Medikamenten, lokalen Einnahmeerinnerungen, Arztkontakten und medizinischen Dokumenten.

> **Status:** Private Testverteilung. Nicht zur Diagnose, Therapieentscheidung oder Änderung ärztlicher Verordnungen verwenden. OCR-Ergebnisse können falsch sein und müssen immer anhand des Originals geprüft werden. Erinnerungen können durch Geräteeinstellungen, Berechtigungen, Energiesparfunktionen oder Betriebssystemverhalten ausbleiben. Sie ersetzen keine Packungsbeilage, ärztliche Anweisung oder persönliche Erinnerung.

## Funktionsumfang

- Lokaler Medikationsplan mit Dosierung, Einnahmezeit und ausgewählten Wochentagen
- Wiederkehrende lokale Erinnerungen
- Arztkontakte sowie Scan und Ablage medizinischer Dokumente
- Lokale PDF-Funktionen und manuelle Backups

Die lokale SQLite-Datenbank wird mit SQLCipher verschlüsselt; der zufällige Schlüssel liegt im Android Keystore. Stammdaten werden verschlüsselt in Android Secure Storage abgelegt. Android-Systembackups sind deshalb deaktiviert. Das schützt gespeicherte Daten im Ruhezustand, ersetzt aber keine unabhängige Sicherheitsprüfung. Manuelle JSON-Backups und E-Mail-/PDF-Exporte sind weiterhin unverschlüsselt und können Gesundheits- und Stammdaten außerhalb des Geräts weitergeben. Vor dem Teilen bitte Inhalt und Empfänger prüfen. In dieser Version gibt es keine Anmeldung und keine geräteübergreifende Synchronisation. Die Arztsuche übermittelt die eingegebene Suchanfrage an den öffentlichen Dienst OpenStreetMap Nominatim; bitte dort keine Patientennamen oder identifizierenden Angaben eingeben. Eine Online-Suche ist optional, Arztkontakte können manuell erfasst werden.

## Voraussetzungen und Entwicklung

- Flutter/Dart entsprechend den SDK-Grenzen in pubspec.yaml
- Android Studio/Android SDK und Java 17

    flutter pub get
    flutter analyze
    flutter test
    flutter run

Die Repository-CI führt Analyse, Tests und einen Android-Debug-Build aus. Ein grüner CI-Lauf ersetzt keine Tests auf echten Geräten.

## Private Android-Verteilung

Die konfigurierte Android Application ID lautet `de.wea200675.medikationsplan`. Sie ist als stabile Paketkennung vorgesehen. Wenn du eine andere Kennung bevorzugst, muss sie vor der ersten Verteilung geändert werden; spätere Änderungen erzeugen eine separate Android-App und übernehmen keine installierte App oder deren Daten.

### Einmalig: privaten Signaturschlüssel anlegen

Erzeuge den Schlüssel auf einem vertrauenswürdigen Rechner. Wähle eigene Passwörter, bewahre eine verschlüsselte Offline-Sicherung des Keystores auf und teile oder committe den Keystore niemals:

    keytool -genkeypair -v -keystore medication-upload.jks -alias medication -keyalg RSA -keysize 4096 -validity 10000

Erstelle `android/key.properties` lokal und trage die tatsächlichen Werte ein (Datei und Keystore sind ignoriert und dürfen nicht eingecheckt werden):

    storeFile=/absoluter/pfad/zum/medication-upload.jks
    storePassword=<dein-keystore-passwort>
    keyAlias=medication
    keyPassword=<dein-key-passwort>

Schütze die Datei:

    chmod 600 android/key.properties

### APK bauen und privat weitergeben

    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --release

Das signierte APK liegt unter `build/app/outputs/flutter-apk/app-release.apk`. Prüfe die Signatur mit Android SDK Build Tools (`apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`) und bilde einen Hash zur Integritätsprüfung (`sha256sum build/app/outputs/flutter-apk/app-release.apk`). Teile APK und Hash über einen privaten, vertrauenswürdigen Kanal. Empfänger müssen die Installation aus dieser Quelle auf Android erlauben. Künftige Updates müssen mit demselben Keystore signiert werden. Verliere den Keystore nicht; ohne ihn können vorhandene Installationen nicht mit einem Update fortgesetzt werden.

## Vor der Weitergabe an andere

1. Auf echten Android-Geräten Datenbankverschlüsselung, sichere Schlüsselspeicherung und App-Neustart testen; zusätzlich Benachrichtigungen, Alarme, Neustart, Zeitzonen- und Sommerzeitwechsel prüfen.
2. Geräte-PIN/Displaysperre aktivieren. Manuelle JSON-Backups und E-Mail-/PDF-Exporte enthalten weiterhin unverschlüsselte Daten; dafür nur Testdaten verwenden, bis ein verschlüsseltes Backupformat ergänzt wurde.
3. Datenbankmigration von unverschlüsselten Bestandsdaten, Backup-Wiederherstellung, OCR-Fehlerfälle und Barrierefreiheit manuell prüfen.
4. Nur an Personen weitergeben, die den Teststatus und die Einschränkungen kennen; Support- und Sicherheitskontakt festlegen.

## Lizenz und Kontakt

Für private Verteilung und Sicherheitsmeldungen müssen Verantwortliche und Kontaktwege mit den Empfängern geteilt werden.
