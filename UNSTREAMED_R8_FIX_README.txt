UNSTREAMED v0.4.9.1 – ANDROID R8 / ML KIT FIX

Der vorherige Build kam bereits erfolgreich durch:
- flutter analyze
- flutter test

Der Fehler trat erst beim Release-APK-Build in R8 auf.

Ursache:
google_mlkit_text_recognition enthält Codepfade für optionale OCR-Modelle
(Chinesisch, Devanagari, Japanisch, Koreanisch). Unstreamed verwendet bewusst
nur das Latin-Modell, daher sind diese zusätzlichen ML-Kit-Artefakte nicht eingebunden.
R8 hat die absichtlich fehlenden optionalen Klassen trotzdem als Fehler behandelt.

Fix:
- android/app/proguard-rules.pro hinzugefügt
- optionale, ungenutzte ML-Kit-Sprachmodule für R8 als absichtlich fehlend markiert
- Release-Build verwendet diese ProGuard-Regeln
- keine zusätzlichen großen OCR-Sprachmodelle nötig
- Cover-Erkennung bleibt auf Latin (Deutsch/Englisch usw.)

Version: 0.4.9+16 / Anzeige 0.4.9.1
