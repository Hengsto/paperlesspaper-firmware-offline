# Abschließende Hardwarevalidierung: OpenPaper L V6

Stand: 25.09.2026. Ziel: ESP32-C6-DevKitM-1, 13-Zoll-EL133UF3. **V6 ist durch drei aufeinanderfolgende reale Nutzerläufe mit `/device/current.bmp` physisch bestätigt.** Flash und verify-flash wurden vom Nutzer erfolgreich ausgeführt. Der Agent hat ausschließlich lokal getestet, gebaut, Dateien geprüft und dokumentiert; kein eigener Gerätekontakt, kein Flashen und kein Push.

## Endgültiger technischer Stand und behobene Ursachen

- **Storage Slot V3:** Ein permanenter reservierter Bildslot statt fortlaufender neuer append-only Allokationen. 983040 Bytes Reservierung, REUSE, geprüfte Schreib-/Readback-Ergebnisse, Transaktions-/Gültigkeitsmetadaten und begrenzte Recovery für das bekannte Legacy-tmp.gz-Layout. Die frühere tmp.gz-Whitelist-Ablehnung verbraucht nicht mehr irrtümlich die Recovery-Freigabe. SerialFlash-Wartepfade sind begrenzt; keine pauschale Löschung unbekannter Dateien.
- **Vollständiger Displaytransport:** EL133UF3 mit zwei Controllern, je 480000 Bildbytes, insgesamt 960000 Bildbytes / 1920000 Pixel. Farbmapping und Nibble-Reihenfolge erhalten, vollständiger RAM-Inhalt, 10-MHz-Panel-SPI, Standardinitialisierung und eine vollständige Waveform. Kein zusätzlicher optischer Weißrefresh.
- **V5-BUSY-Qualifikation:** Keine künstliche Mindestdauer von 10 Sekunden. DRF verlangt 5 ms stabile Aktivität innerhalb 2000 ms, der Abschluss 20 ms stabiles Idle; Phasenbudget 120000 ms. POF folgt erst nach BUSY-Ende und wird ebenfalls auf stabiles Idle überwacht. Kein Timeout wurde zur Verschleierung der Race erhöht.
- **V6-Race-Fix:** Der alte ACC-Ticker konnte gerade bei aktivem Display über deinitDisplay → RESET → hibernate → powerOff/SLEEP den Transfer stören und EPD-Pins auf INPUT setzen. Jetzt publiziert er nur atomare Prüfanforderungen. Zwei gleiche gültige Orientierungsproben qualifizieren vor Beginn den eingefrorenen Frame-Snapshot. Ein gemeinsamer rekursiver Mutex schützt Display, Versorgung, Reset, gemeinsame SPI-Zugriffe und Orientierung von der Initialisierung bis einschließlich POF/Fehler-Cleanup. Erst danach wird die aktuelle stabile Orientierung übernommen. Auto-Rotation bleibt erhalten.
- **Abschluss genau einmal:** RAII-Session mit idempotentem finish; bei Fehler einmal RESET low und externer Rail-Cutoff statt konkurrierender POF-Versuche. Nach erfolgreichem POF ebenfalls kontrollierter einmaliger Abschluss. Der spätere Sleep-Pfad sendet kein zweites Treiber-powerOff.

Details und Aufrufpfade: [DISPLAY_ROTATION_RACE_FIX.md](DISPLAY_ROTATION_RACE_FIX.md), historische Transportanalyse mit aktuellem Abnahmestand: [DISPLAY_ANALYSIS.md](DISPLAY_ANALYSIS.md), Storage: [STORAGE_FIX.md](STORAGE_FIX.md). Im Rahmen dieser Abschlussarbeit wurde kein Firmwarequellcode geändert; der Commit nimmt den bereits geprüften vollständigen Storage-/Display-/Synchronisierungsstand auf, der bisher uncommittet vorlag.

## Drei physische V6-Läufe

Quelle: vom Nutzer in dieser Sitzung mitgeteilte Hardwareergebnisse. Die Identität wurde anhand der unten genannten Firmware-SHA256 bestätigt. Es werden keine zusätzlichen Messungen oder nicht übermittelten Logdetails behauptet.

| Lauf | Storage / Bildbytes | Orientierung | PANEL REFRESH END | Ergebnis |
| --- | --- | --- | --- | --- |
| 1 | Slot REUSE; vollständige 960000 Bildbytes | frozen rotation=0; erst nach `V6 cleanup complete; orientation released` ACC Update Orient to Mem:1 | elapsed_ms=26810 | POF complete; download=0 display=0 |
| 2 | Slot REUSE; vollständige 960000 Bildbytes | Keine konkrete frozen-Rotation mitgeteilt | elapsed_ms=26964 | POF complete; download=0 display=0 |
| 3 | Slot REUSE; vollständige 960000 Bildbytes | Keine konkrete frozen-Rotation mitgeteilt | elapsed_ms=27015 | POF complete; download=0 display=0 |

In **keinem** Lauf trat zwischen initReset und POF ein konkurrierendes powerOff auf. Insbesondere Lauf 1 bestätigt die zeitlich korrekte Übernahme der Orientierungsänderung erst nach Freigabe. Drei aufeinanderfolgende Erfolge ersetzen die frühere, durch den zweiten V5-Fehllauf widerlegte Einzellauf-Freigabe. Dies ist eine technische Wiederholungsvalidierung im gemeldeten Ablauf, keine vollständige Umwelt-/Langzeit-/Ghosting-Prüfung.

## Wiederholte lokale Verifikation

Nach den Dokumentationsnachträgen ausgeführt:

```sh
./tests/run_host_tests.sh
/tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1 -t clean
SOURCE_DATE_EPOCH=1790292908 /tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1
```

Hosttests: **bestanden**, mit -Wall/-Wextra/-Werror und UndefinedBehaviorSanitizer. Ergebnisse:

- 294 Storage-/Formatfälle, darunter das exakte Legacy-Layout und dauerhafte Slot-Wiederverwendung.
- 24 Produktions-HTTP-Downloads einschließlich wechselnder URL/Hashes/Inhalte, Abbruch und Stromunterbrechung im Modell; eine Allokation.
- Rekonstruktion der früheren Whitelist-Ablehnung ohne Verbrauch der NVS-Recovery-Freigabe.
- 23 Displayfälle: vollständige Controller-/Pixelabdeckung und Mapping, gültige kurze Refreshs, BUSY-Entprellung, Fehler, POF, Überlauf und Lesefehler.
- 57 Rotation-/Sessionfälle: Initialisierung, Master, Slave, DRF, BUSY, POF; acht wechselnde Orientierungszyklen; konkurrierender Thread ausgeschlossen; zurückgestellte Übernahme; Exactly-once-Cleanup auch bei Fehlern.
- Aus main.cpp extrahierte tatsächliche ACC-Funktionen: hardwarefreier Timer, keine Messung/NVS-Änderung während active, nachträgliche Übernahme, instabile Messung/Retry, deaktivierte Auto-Rotation und gestoppter Ticker.

Reproduzierbarkeit: Der erste vollständige Neubau ohne Zeitvorgabe bestand, unterschied sich aber in 68 Bytes von der freigegebenen Datei: Arduino `cores/esp32/chip-debug-report.cpp` bettet `__TIME__` ein; hinzu kommen der abhängige ELF-Hash und Image-Prüfsummen. Deshalb wurde anschließend erneut vollständig mit `SOURCE_DATE_EPOCH=1790292908` gebaut (ursprünglicher eingebetteter Zeitstempel: Sep 24 2026 23:35:08 UTC). Keine Firmwarebytes wurden nachträglich gepatcht. Der Vergleich des gewöhnlichen Neubaus ist in `artifacts/final-v6-default-build-comparison.json` dokumentiert.

Logs: `artifacts/final-v6-host-tests.log`, `artifacts/final-v6-clean.log`, `artifacts/final-v6-build.log`. Quellcode-/Artefaktverifikation: `artifacts/final-v6-verification.json`. Der vollständige Neubau nach clean mit festgelegtem Build-Zeitstempel ist erfolgreich: RAM 173456/327680 Bytes, Flash-Programmnutzung 1700872/1900544 Bytes. **Neubau, artifacts/firmware.bin, Paketverzeichnis und Firmware im ZIP sind bytegleich** und stimmen mit der vom Nutzer physisch geprüften SHA256 überein. ZIP-CRC und sämtliche paketinternen SHA256SUMS sind geprüft und gültig. Die Quellcode-/Test-Hashes stimmen weiterhin mit der V6-Provenienz vor der Hardwareprüfung überein. Die Commit-Dateiliste wurde explizit freigegeben und auf Textdateien, zulässige Pfade sowie typische Secret-Signaturen geprüft. Keine Binär-/Cache-/Backup-Dateien werden aufgenommen. `git diff --cached --check` besteht für Anwendung, Tests und Dokumentation. Die unverändert übernommene vendor-Datei lib/SerialFlash/SerialFlashDirectory.cpp enthält vier historische trailing-whitespace-Stellen und eine leere EOF-Zeile; deren Formatierung bleibt zur Bewahrung des physisch geprüften Quellstands unverändert. Das sind ausschließlich Formatwarnungen, keine Test-/Buildfehler.

## Endgültige Artefakte

| Eigenschaft | Wert |
| --- | --- |
| Windows-Paket | `artifacts/openpaper-l-display-v6-windows.zip` |
| Firmwaredatei | `artifacts/firmware.bin` |
| Firmwaregröße | **1756704 Bytes** |
| Firmware-SHA256 | **cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78** |
| ZIP-Größe | **1104327 Bytes** |
| ZIP-SHA256 | **4cfa7ea19e9af824ea4590fde1f44e744701635eda742a9aa9a982b0ed23102c** |
| Separate ZIP-Prüfsumme | `artifacts/openpaper-l-display-v6-windows.zip.sha256` |

Das ZIP wird nach den Nutzertests nicht neu gepackt und enthält deshalb den historischen Bericht vor der physischen Freigabe. Aktuelle Nachweise stehen in den Repository-Berichten. Artefakte und Logs bleiben unter dem ignorierten artifacts-Verzeichnis außerhalb der Git-Historie. Das Paket enthält ein manuell ausführbares Windows-Flashing-Skript mit anzupassendem COM5; es wurde hier nicht ausgeführt.

## Rollback-Anleitung und Grenzen

1. **Bevorzugte Wiederherstellung:** Das oben identifizierte, physisch bestätigte V6-ZIP separat aufbewahren. Für die manuelle Wiederherstellung ZIP entpacken und SHA256 von firmware.bin vergleichen. Den tatsächlichen Windows-COM-Port im beiliegenden flash-windows.cmd einstellen; dann ausschließlich auf ausdrückliche Entscheidung des Nutzers das Skript aus dem entpackten Verzeichnis ausführen. Es schreibt bootloader.bin bei 0x0000, partitions.bin bei 0x8000, boot_app0.bin bei 0xe000 und firmware.bin bei 0x10000, ESP32-C6 / 4 MB. Danach verify-flash mit denselben Dateien/Offsets und derselben Portangabe ausführen. Hier wurden diese Geräteaktionen nicht durchgeführt.
2. **Kein vollständiges erase-flash/NVS-Reset:** Einstellungen, Recovery-Marker und externer Slot sollen erhalten bleiben. Ein Firmware-Rollback stellt bereits durchgeführte externe Flash-/NVS-Transaktionen nicht rückwirkend wieder her. Der ursprüngliche vollständige Hardware-Flashzustand lässt sich ohne ein separat vorhandenes passendes Backup nicht rekonstruieren; ein solches Backup wurde hier weder erstellt noch eingecheckt.
3. **Vorherige V5-Artefakte:** `artifacts/openpaper-l-display-v5-windows.zip` bleibt erhalten, ist aber wegen der nachgewiesenen ACC/Power-off-Race **kein empfohlener Betriebs-Rollback**. Auch V4 oder der Repository-Ausgangsstand verlieren spätere BUSY-/Race-/Storage-Korrekturen. Die frühere Firmware nicht allein aufgrund eines einzelnen erfolgreichen Laufs wieder freigeben.
4. **Quellcodevergleich/Rücknahme:** Ausgangsbasis vor diesen Änderungen ist Commit `0961aa69ffeddfe505f7a2bb4b7c45f49308b2d6` (nur historische Vergleichsbasis). Nach Sichern lokaler Arbeit kann der unten genannte Implementierungscommit mit `git revert <Implementierungscommit>` in einem eigenen Arbeitszweig rückgängig gemacht werden. Das setzt Quellcode zurück, flasht kein Gerät und macht die behobenen Fehler wieder möglich. Für produktive Wiederherstellung stattdessen die freigegebene V6-Binärdatei verwenden.

## Verbleibender Cleanup-Befund und spätere Optimierungen

`ESP_ERR_WIFI_NOT_INIT` nach abgeschlossenem Displayupdate bleibt ein **harmloser nachgelagerter Wi-Fi-Cleanup-Befund bezüglich der belegten Bilddarstellung**. Mehrere WiFi.disconnect(true)-Aufrufe vor dem Displaypfad und im Sleep-Pfad passen zum Disconnect einer bereits deaktivierten Wi-Fi-Instanz. Die genaue interne Auslösung wurde nicht zusätzlich instrumentiert; der Befund macht POF und download=0/display=0 nicht rückwirkend ungültig. Ein Wi-Fi-Cleanup-Fix ist nicht Teil dieses Commits.

**Dynamisches Wake-Timing** und eine weitergehende **Erkennung unveränderter Bilder** sind spätere Optimierungen. Die vorhandenen HTTP-/Last-Modified-Mechanismen bleiben bestehen; daraus wird keine neue flächendeckende Inhaltsvergleichsoptimierung behauptet. Für diese Optimierungen wurden weder Zeitregeln noch Refresh-/Downloadverhalten verändert.

Weitere Grenzen: keine vollständige Temperatur-/Versorgungs-/Langzeitmatrix; Software-BUSY beweist keine Pixelqualität auf Glas. Während eines Frames werden Orientierungszwischenstände zusammengefasst; bei fortgesetzter Bewegung gilt die letzte stabile Lage. Wartende BLE-/Failsafe-Aufrufe können durch die Display-Sperre verzögert werden. Die ergänzende 12-Läufe-Bewegungsmatrix im Race-Bericht bleibt optionaler weiterer Robustheitsnachweis.

## Lokaler Commit und Repository-Nachweis

Der Implementierungscommit enthält ausschließlich den beabsichtigten Quellcode einschließlich lokal gepinntem/gepatchtem SerialFlash, Hosttests, Buildkonfiguration, Artefakt-Ignore-Regel und technische Dokumentation. Keine Secrets, Flashbackups, .pio-Build-Caches, firmware.bin oder ZIPs werden aufgenommen. Die konkrete Commit-ID, Dateiliste und abschließenden Repository-Ausgaben werden nach Erstellung unten ergänzt. Ein separater Dokumentationsabschluss hält die tatsächliche Implementierungs-ID fest, ohne eine unmögliche Selbstreferenz auf den Hash der eigenen Commit-Inhalte zu erzeugen. Kein Push.
