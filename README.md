# ReelShelf

**ReelShelf** ist ein moderner Android-Tracker für physische Filmsammlungen. Die erste Version ist bewusst auf den Alltag einer Blu-ray-/4K-Sammlung zugeschnitten: schöne Coveransicht, eigene Editionen, Barcode, Wunschliste, Kaufdaten und lokale Backups.

## Bereits umgesetzt

- Moderne Material-3-Dark-UI mit responsivem Cover-Raster
- Sammlung und Wunschliste
- 4K UHD, Blu-ray, DVD, Steelbook, Mediabook, Boxset und eigene Editionen
- EAN-/Barcode-Scanner per Smartphone-Kamera
- TMDB-Suche für Cover, Titel, Beschreibung, Laufzeit, Bewertung und Genres
- Detailseite mit Hero-Cover und Sammlerinformationen
- Kaufpreis, Kaufdatum, Zustand, Regal/Standort und Notizen
- Favoriten
- Filter, Suche und Sortierung
- Statistik zu Formaten, Laufzeit und erfassten Kaufpreisen
- Lokale SQLite-Datenbank – kein Account erforderlich
- JSON-Backup über die Zwischenablage
- Demo-Sammlung für einen schnellen UI-Test
- GitHub-Action, die automatisch ein installierbares Android-APK baut

## 1. Direkt ausprobieren

Voraussetzung ist ein aktuelles Flutter-SDK (empfohlen: aktueller Stable-Channel) und Android Studio/Android SDK.

```bash
flutter pub get
flutter run
```

Für ein APK:

```bash
flutter build apk --release
```

Danach liegt das APK unter:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> Der Release-Build ist für Tests absichtlich mit dem Debug-Key signiert. Vor einer Veröffentlichung im Google Play Store muss ein eigener Release-Keystore eingerichtet werden.

## 2. APK ohne lokale Flutter-Einrichtung über GitHub bauen

Im Projekt liegt `.github/workflows/build-android.yml`.

1. Projekt in ein neues GitHub-Repository hochladen.
2. Auf **Actions** gehen.
3. Workflow **Build Android APK** starten.
4. Nach dem Build das Artefakt **ReelShelf-Android-APK** herunterladen.

Der Workflow führt zusätzlich `flutter analyze` und `flutter test` aus.

## 3. TMDB für automatische Filmdaten einrichten

ReelShelf funktioniert auch ohne TMDB, dann werden Filme manuell angelegt. Für automatische Cover und Filmdaten:

1. Kostenloses Konto auf `themoviedb.org` erstellen.
2. In den Kontoeinstellungen den Bereich **API** öffnen.
3. Einen API-Zugang beantragen/aktivieren.
4. Den **API Read Access Token** kopieren.
5. In ReelShelf: **Einstellungen → TMDB → TMDB Read Access Token** einfügen.

ReelShelf nutzt die v3-API mit Bearer-Authentifizierung und standardmäßig `de-DE` / Region `DE`.

**Hinweis:** Der Token wird in dieser MVP-Version lokal in SharedPreferences gespeichert. Für eine öffentliche Multiuser-App würde ich ihn nicht als Nutzergeheimnis behandeln, sondern die API-Anbindung über ein eigenes Backend absichern.

## Barcode-Verhalten

Der Scanner liest EAN-13, EAN-8, UPC-A, UPC-E und Code 128. Die EAN wird der eigenen physischen Ausgabe gespeichert.

TMDB ist eine **Filmdatenbank**, keine vollständige EAN-Datenbank für deutsche Disc-Releases. Deshalb kann ReelShelf nach einem Scan nicht zuverlässig aus jeder EAN automatisch die exakte deutsche 4K-/Blu-ray-Ausgabe bestimmen. Aktuell wird die EAN übernommen und der Film anschließend per TMDB gesucht. Eine spätere Version kann dafür eine eigene Community-/Release-Datenbank ergänzen.

## Projektstruktur

```text
lib/
  core/        Theme
  models/      Film- und Sammlungsmodelle
  screens/     Sammlung, Wunschliste, Scanner, Details, Einstellungen
  services/    SQLite, TMDB, Einstellungen
  state/       zentraler App-State
  widgets/     Poster, Karten, Empty States
android/       Android-Projekt
.github/       automatischer APK-Build
```

## Nächste sinnvolle Ausbaustufe

Für eine Version 0.2 bieten sich an:

- Eigene Release-Datenbank für EAN → exakte deutsche Disc-Ausgabe
- Boxsets mit einzelnen enthaltenen Filmen
- Audio-/Untertitelspuren und Disc-Anzahl
- Ausgeliehen an / Verleihhistorie
- Eigene Listen und Tags
- CSV-Import/Export
- Cloud-Sync zwischen mehreren Geräten
- Preis-/Wertverlauf für Sammlerstücke
- Cover-Scan bzw. Suche nach Editionen
- Play-Store-taugliches Signing, Datenschutzseite und App-Icon-Set

## Daten & Attribution

Filmdaten und Bilder können optional von TMDB geladen werden.

> This product uses the TMDB API but is not endorsed or certified by TMDB.

Vor einer öffentlichen Veröffentlichung bitte die dann aktuellen TMDB-Nutzungs- und Attributionsbedingungen prüfen und die geforderte TMDB-Attribution/Logodarstellung vollständig umsetzen.
