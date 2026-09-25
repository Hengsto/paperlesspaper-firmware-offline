# Dynamischer Timetable-Wake

Diese Revision ergänzt den unveränderten Bildabruf um eine pro Antwort
berechnete Schlafdauer. Der Smart-Frame-Server sendet auf HTTP 200 und 304
`X-OpenPaper-Sleep-Seconds`. Die Firmware akzeptiert ausschließlich Dezimalwerte
von 60 bis 86400 Sekunden und verändert den dauerhaft per BLE gespeicherten
Intervallwert nicht.

Nach dem Abruf zieht sie die seit Empfang des Headers vergangene Zeit ab. Damit
werden Download und der ungefähr 27 Sekunden dauernde Vollrefresh nicht auf den
nächsten Timetable-Slot aufgeschlagen. Liegt kein gültiger Header vor, gilt der
lokale BLE-Intervallwert weiter. Scheitert der Download, wird der nächste Versuch
auf 60 bis 300 Sekunden begrenzt, statt möglicherweise eine Stunde bis zum
nächsten Versuch zu warten.

Der dynamische Wert wird nur für den aktuellen Deep-Sleep-Zyklus verwendet:

1. Server berechnet nächsten echten Slot minus 45 Sekunden Vorlauf.
2. Firmware lädt das Bild oder erhält HTTP 304.
3. Bei einem neuen Bild erfolgt genau ein Displayrefresh.
4. Firmware subtrahiert die verstrichene Verarbeitungszeit und schläft bis zum
   berechneten Wake.
5. Beim nächsten Abruf liefert der Server den folgenden tatsächlichen Slot.

Die Firmware vertraut weder negativen, formatierten noch übergroßen Headern.
Ein Serverausfall führt zu einem höchstens fünfminütigen Retry. BLE-Modus und
manuelle Setup-Abläufe behalten ihr bisheriges Verhalten.

## Prüfung

`tests/host/device_wake_test.cpp` prüft Grenzen, fehlerhafte Werte,
Millisekundenüberlauf, Zeitabzug und Fehler-Retry. Der produktive Downloadertest
prüft die Headerübernahme bei HTTP 200 und 304 sowie das Ignorieren ungültiger
Werte. Die physische Abnahme umfasst anschließend einen neuen Bildslot, einen
unveränderten 304-Abruf und einen simulierten nicht erreichbaren Server.
