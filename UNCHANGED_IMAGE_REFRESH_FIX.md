# Unveränderte Bilder ohne Panelrefresh

Stand: 25.09.2026. Basis ist der physisch bestätigte OpenPaper-L-V6-Stand auf
`fix/openpaper-l-storage-display-reliability`. Diese Änderung betrifft nur die
HTTP-Validierung vor dem persistenten Bildslot; Storage V3 und der vollständige
EL133UF3-Displaypfad V6 bleiben unverändert.

## Ursache

`downloadAndSaveFile()` las den Antwortheader `Last-Modified`, verglich ihn aber
nicht mehr mit dem gespeicherten Validator. Die Funktion konnte deshalb trotz
des weiterhin vorhandenen Rückgabepfads `1 = not modified` niemals `1`
zurückgeben. Jeder Timer-Wakeup schrieb das Bild erneut in den externen Flash und
startete anschließend einen vollständigen Panelrefresh.

Ein reiner Zeitstempelvergleich reicht außerdem nicht aus: Derselbe Bildinhalt
kann später neu erzeugt werden und dadurch ein neues `Last-Modified` erhalten.

## Umsetzung

- Ein starker HTTP-`ETag` hat Vorrang vor `Last-Modified`.
- Der gespeicherte Validator wird typisiert (`etag:` beziehungsweise
  `last-modified:`), ohne das bestehende EEPROM-Layout zu verändern.
- Bei vorhandenem validem Bildslot sendet die Firmware `If-None-Match` oder
  `If-Modified-Since`.
- HTTP 304 sowie ein identischer Validator bei HTTP 200 liefern `1` zurück,
  bevor Bilddaten gelesen, der Flash beschrieben oder der Displaypfad gestartet
  wird.
- Alte, untypisierte `Last-Modified`-Werte werden weiterhin erkannt.
- Ohne gültiges lokales Bild wird selbst bei passendem Validator vollständig
  geladen. Ein 304 wird nur bei vorhandenem Bildslot akzeptiert.
- Wenn eine Remote-Konfiguration die Download-URL tatsächlich ändert, wird der
  gespeicherte Bildvalidator verworfen. Der bestehende BLE-URL-Pfad tat dies
  bereits.
- Ein absichtlicher Mehrfachdruck auf Reset behält das dokumentierte
  `forceDownload`-/Refresh-Verhalten.

Der Server sollte für bytegleichen Inhalt einen stabilen starken `ETag`
ausgeben. `Last-Modified` bleibt ein kompatibler Fallback.

## Verifikation

`./tests/run_host_tests.sh` besteht weiterhin vollständig. Der aus
`src/main.cpp` extrahierte Produktions-Downloader prüft zusätzlich:

- veränderte ETags und 24 aufeinanderfolgende Downloads,
- identischen ETag bei HTTP 200,
- HTTP 304,
- typisiertes und altes `Last-Modified`,
- keinen Transaktionsstart und unveränderte Slotbytes beim Skip,
- Download trotz passendem Validator, wenn kein lokaler Slot vorhanden ist,
- bestehende Abbruch- und Stromunterbrechungsfälle.

`git diff --check` ist sauber. Ein ESP32-C6-Build und ein physischer 30-Minuten-
Wiederholungstest stehen für diesen neuen Stand noch aus. Erwarteter serieller
Erfolgspfad:

```text
[DL] Image unchanged (ETag); skipping flash write and display refresh
[IMAGE] Not rendering, image not modified
[MAIN] End of Update download=1 display=0
```

Beim ersten Lauf nach dem Firmwarewechsel kann einmalig ein normaler Download
und Refresh stattfinden, weil ein alter `Last-Modified`-Wert auf den neuen
ETag-basierten Validator migriert wird.
