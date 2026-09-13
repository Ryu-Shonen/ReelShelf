UNSTREAMED v0.4.9 – COVER SCAN

Neu:
- EAN/Barcode-Scan ist aus der normalen Oberfläche entfernt.
- Stattdessen: Filmcover fotografieren.
- Google ML Kit erkennt den Text direkt auf dem Gerät.
- Unstreamed erzeugt daraus mehrere Titel-Kandidaten.
- Bis zu vier Kandidaten werden gegen TMDB gesucht und die Treffer anhand des erkannten Covertexts sortiert.
- Danach wählst du den richtigen Film wie gewohnt aus.
- Manuelle TMDB-Suche bleibt erhalten.
- EAN bleibt als optionales manuelles Feld für konkrete physische Ausgaben erhalten.
- Kamera-Schnellbutton in Sammlung/Wunschliste scannt nun das Cover.
- Android minSdk steigt von 23 auf 24 wegen des aktuellen offiziellen image_picker-Plugins.

Technik:
- image_picker ^1.2.3
- google_mlkit_text_recognition ^0.15.1
- keine kostenpflichtige Bilderkennungs-API
- kein Upload des Fotos an eine eigene Cloud
- nur der erkannte Suchtext wird an TMDB geschickt

Hinweis:
Cover-OCR erkennt primär den Film, nicht garantiert die exakte physische Edition.
