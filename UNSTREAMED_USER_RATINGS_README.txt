UNSTREAMED v0.5.0 – EIGENE FILMBEWERTUNGEN

Neu:
- Jeder Film kann zusätzlich zu TMDB und IMDb persönlich bewertet werden.
- Skala: 0,5 bis 10 Punkte in 0,5-Schritten.
- Bewertung ist optional und kann jederzeit entfernt werden.
- Eingabe unter „Bearbeiten“ > „Meine Bewertung“.
- Anzeige auf der Detailseite.
- Anzeige in normaler Coveransicht, Kompaktansicht und Listenansicht.
- IMDb/TMDB bleiben unverändert und getrennt sichtbar.

Daten:
- neues Feld: user_rating
- SQLite-Schema wird automatisch von Version 4 auf 5 migriert
- bestehende Sammlungen bleiben erhalten
- Backup/Restore übernimmt die eigene Bewertung automatisch über CollectionItem JSON
- ältere Backups ohne user_rating bleiben kompatibel

Version:
0.5.0+17
