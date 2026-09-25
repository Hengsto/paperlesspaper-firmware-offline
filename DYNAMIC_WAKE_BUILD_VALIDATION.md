# OpenPaper L Dynamic Wake V7 – Build- und Ablaufvalidierung

## Herkunft und Ergebnis

- Fork: https://github.com/Hengsto/paperlesspaper-firmware-offline
- Zielbranch: `fix/openpaper-l-unchanged-image-skip`.
- Ausgangscommit: `77354f282897d004437e70f12fb798352a40c0ab`.
- Finaler Firmware-/Testcommit: `76ae333437bd83e1ec32f76966c44669a32408a7`.
- Der anschließende Dokumentationscommit enthält diesen Bericht. Sein vollständiger Hash steht im Paket in `DELIVERY_COMMIT.txt`; im Checkout liefert ihn `git log -1 --format=%H -- DYNAMIC_WAKE_BUILD_VALIDATION.md`. Die Firmwarequellen ändern sich dadurch nicht.
- Separater Worktree: `/srv/dev/openpaper-dynamic-wake-v7`. Das ursprüngliche Arbeitsverzeichnis und seine Artefakte wurden nicht verändert.
- Hosttests und vollständiger Firmwarebuild erfolgreich. Kein Flashen, kein Gerätekontakt, kein serieller Monitor ausgeführt. Die physische V7-Abnahme steht aus.

## Vollständige Änderungsliste

1. `src/main.cpp`: Serverwert und Empfangszeit vor jedem einzelnen HTTP-Versuch löschen. Nur 200 beziehungsweise 304 mit vorhandenem gültigem Bildslot dürfen einen Header liefern. Den Wert erst nach erfolgreichem Body-/Speichervorgang oder bestätigtem unverändertem Bild übernehmen; Empfangszeit bleibt der Zeitpunkt unmittelbar nach GET. Bei nachträglichem Verarbeitungs-/Netzwerkfehler beide Werte löschen.
2. `src/main.cpp`: Die Umwandlung von Rückgabewert 1 in 0 durch `settings.forceDownload` entfernen. Sie führte bei unverändertem Bild zu einem fälschlichen Downloadfehler oder unnötigen Refresh. Manueller Abruf bleibt erhalten; neue Bilder werden weiterhin angezeigt.
3. `tests/host/download_test.cpp`: Produktionsfunktionen für HTTP, Wiederholungen, Prozessabschluss, Renderentscheidung und Schlafentscheidung gegen deterministische Backends ausführen. Headerregistrierung vor GET erzwingen; 200/304, Fehler, fehlende/ungültige Folgeheader, stale state, WiFi-Ausfall, forceDownload, Displayaufrufe, lokaler Fallback, Retry-Grenzen und Zeitüberlauf prüfen.
4. `tests/host/device_wake_test.cpp`: Parsergrenzen, Vorzeichen, Whitespace, Suffixe, sehr lange Zahlen, 32-Bit-Überlaufwerte, unveränderten Ausgabeparameter bei Ablehnung und zusätzliche Retry-/Zeitgrenzen prüfen.
5. `tests/host/storage_test.cpp`: Flash-Schreib-/Löschaufrufe zählen, um null Schreibzugriffe bei 304 nachzuweisen.
6. `tests/host/Arduino.h`: Serielle Host-Stubs für die zusätzlich extrahierten Produktionsfunktionen ergänzen.
7. `tests/run_host_tests.sh`: Weitere Produktionsabschnitte extrahieren; Ausführungsbit setzen (der Ausgangsstand war nicht direkt ausführbar).
8. `scripts/flash-windows.cmd`: Expliziten COM-Port verlangen, Paket-SHA256 vor Schreiben prüfen, ESP32-C6/4-MB-Offsets verwenden und anschließend verify-flash ausführen. Im Repository LF, im ZIP Windows-CRLF.
9. Dieser Abschlussbericht. Keine Binärdateien, ZIPs, Umgebungen oder Caches im Commit.

Der vorhandene Parser, Zeitrechner, lokale Intervallberechnung, BLE-/Setup-Ablauf, Auto-Rotation, V3-Slot und V6-Treiber benötigten keine Änderung. Die geforderten fünf Debugmeldungen waren bereits vorhanden und bleiben enthalten; die Annahmemeldung erfolgt nun erst bei erfolgreichem Request. Keine neuen Logs enthalten Headerrohwerte, Zugangsdaten oder Authentifizierungswerte.

## Geprüfter Wake-Ablauf

1. Die konfigurierte Bild-URL muss auf `/device/current.bmp` zeigen. `processHttpDownload()` löscht den Zykluszustand auch vor einem möglichen WiFi-Ausfall. Jeder nachfolgende HTTP-Versuch löscht ihn erneut.
2. `collectHeaders()` sammelt ETag, Last-Modified und X-OpenPaper-Sleep-Seconds vor GET. Ein vorhandener Slot ermöglicht bedingte Requests.
3. Nur die Zeichen 0–9 mit Ergebnis 60 bis 86400 sind gültig. Die Prüfung vor Multiplikation verhindert Integer-Überlauf; führende Nullen sind numerisch und zulässig. Null, leer, negative Werte, Pluszeichen, innere Leerzeichen und Suffixe werden abgelehnt. Der Arduino-HTTPClient entfernt bereits äußeres HTTP-Whitespace (OWS); die strikte Parserprüfung bezieht sich auf den von ihm gelieferten Feldwert.
4. Bei neuem 200-Bild wird der bestehende Slot wiederverwendet, vollständig geschrieben und validiert. Nach erfolgreichem Abschluss wird der Serverwert veröffentlicht. Ein vollständiger Displayaufruf erfolgt; erst danach wird der Validator dauerhaft übernommen. Ein gleichbleibender Validator kann auch bei 200 frühzeitig überspringen.
5. Bei 304 mit gültigem Slot Rückgabewert 1, keine Transaktion, keine Allokation, kein Flash-Schreiben/Löschen und kein `setImageFromFS()`, auch bei forceDownload. 304 ohne Slot ist ein Fehler und liefert keinen Schlafwert.
6. Serverzustand liegt ausschließlich im RAM. `settings.timeout` und der per BLE persistierte Intervallwert werden nicht vom Header überschrieben.
7. Unmittelbar vor dem Schlafaufruf wird `(uint32_t(now - receivedAt) / 1000)` abgezogen. Beispiel: 3555 minus 27 Sekunden = 3528 Sekunden. Der unsigned Unterschied funktioniert über einen millis()-Überlauf. Eine verstrichene Frist wird auf 60 Sekunden begrenzt, nicht auf 0.
8. `remainingSleepSeconds()` liefert bei ungültigen direkten Eingaben zwar den Sentinel 0, dieser ist im produktiven Aufrufpfad nicht erreichbar: nur erfolgreich geparste Werte 60–86400 werden veröffentlicht und nur positive Serverwerte aufgerufen. BLE verwendet weiterhin absichtlich Schlaf ohne Timer; das ist kein URL-Fallback.
9. Ohne gültigen Header bleibt die vorhandene lokale Schlafvorhersage aus dem BLE-Intervall aktiv; nichtpositive konfigurierte Intervalle verwenden DEFAULT_SLEEP. Die bestehende Vorhersageberechnung fällt bei erschöpften Zeitfenstern auf das positive konfigurierte Intervall zurück.
10. Download-/HTTP-/Netzwerkfehler haben Vorrang vor jedem Serverwert. Der lokale Wert wird für den Retry auf 60–300 Sekunden begrenzt. Die bestehende Folge von bis zu sechs unmittelbaren HTTP-Versuchen bleibt erhalten; das Retry-Intervall beginnt nach Abschluss dieser Versuche und der Fehlerbehandlung.
11. Der V6-Ablauf RAM-Transfer → DRF → stabiler BUSY-Abschluss → POF bleibt quellcodegleich. Die Guard-/Orientierungslogik bleibt unverändert; vorhandene Tests decken konkurrierende Zugriffe, Auto-Rotation und Cleanup ab.

## Tests und Build

Erfolgreich ausgeführt:

```sh
./tests/run_host_tests.sh
# Vorhandene Umgebung, vollständiger Neubau in neuem Buildverzeichnis:
/tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1
git diff --check
git diff --cached --check
```

- Hosttests: Exit 0 mit UndefinedBehaviorSanitizer, Wall/Wextra/Werror. 294 Storage-/Formatfälle, 24 produktive Downloads mit nur einer Slot-Allokation, V2-Whitelist-Regression, Wake-/HTTP-/Render-Integration, 23 Displayfälle sowie 57 Rotation-/Sessionfälle erfolgreich.
- Grenzen 60/3555/86400 auch für HTTP 200 und 304 geprüft. HTTP 404/500 und Transportfehler, WiFi-Ausfall, fehlende/ungültige Header nach gültigem Header, sehr lange Zahlen und Überlaufwerte geprüft.
- 304: null zusätzliche Flash-Writes, null Erases, null Displayaufrufe. Erfolgreiche neue Downloads: genau ein Displayaufruf pro Bild. 27 Sekunden simulierte Displayzeit und millis()-Wrap geprüft.
- Build: SUCCESS, 43,61 Sekunden. RAM 173464/327680 Bytes; PlatformIO-Programmnutzung 1702612/1900544 Bytes. Eine bestehende SdFat-Warnung bezüglich FS.h, keine Buildfehler.
- Die erstmaligen Hostversuche machten fehlendes Ausführungsbit und fehlende Host-Stubs sichtbar; diese sind korrigiert. Die beigelegte Host-Testdatei enthält den abschließenden erfolgreichen Lauf.
- Build verwendet vorhandene Abhängigkeiten und vorhandene Python-Umgebung. Keine TLS-Prüfung deaktiviert, keine Zertifikatsprüfung für Downloads umgangen.
- `esptool 5.1.2 image-info` bestätigt gültige Checksummen/Hashes, ESP32-C6 Chip-ID 13, DIO/80 MHz/4 MB für Anwendung und Bootloader.
- `gen_esp32part.py` dekodiert und validiert partitions.bin; zusätzliche Prüfung bestätigt nichtüberlappende Partitionen und Ende bei 0x400000.
- `EPD_TYPE_13INCH` ist in src/types.h aktiv, DisplayType ist EL133UF3. V6-/V3-Kennungen wurden auch in firmware.bin nachgewiesen. Kein 7-Zoll-Anwendungspfad.
- V6-/V3-Dateien einschließlich SerialFlash sind gegenüber dem Ausgangscommit unverändert.

| Partition | Offset | Größe |
| --- | --- | --- |
| nvs | 0x9000 | 0x5000 |
| otadata | 0xe000 | 0x2000 |
| app0 | 0x10000 | 0x1d0000 |
| app1 | 0x1e0000 | 0x1d0000 |
| spiffs | 0x3b0000 | 0x40000 |
| coredump | 0x3f0000 | 0x10000 |

## Artefakte

- Firmware: `artifacts/firmware.bin`, **1758480 Bytes**.
- SHA256: `35015d4fb190e313b0991463b5adcabc94d29a9712ca4992133da7f18aed6c03`.
- App-Partition: 1900544 Bytes, Reserve 142064 Bytes einschließlich Image-Overhead berücksichtigt.
- ZIP: `artifacts/openpaper-l-dynamic-wake-v7-windows.zip`.
- Paketinhalt: firmware.bin, bootloader.bin, partitions.bin, boot_app0.bin, flash-windows.cmd, SHA256SUMS, build.log, host-tests.log, diff-check.log, firmware-image-info.log, bootloader-image-info.log, partitions-decoded.csv, build-validation.json, DELIVERY_COMMIT.txt und DYNAMIC_WAKE_BUILD_VALIDATION.md.
- Flashoffsets: Bootloader 0x0000; Partitionen 0x8000; boot_app0 0xe000; Anwendung 0x10000. Kein erase-all.
- ZIP-CRC, alle paketinternen SHA256 und Bytegleichheit von ZIP-firmware.bin, artifacts/firmware.bin und dem Buildoutput werden beim Paketieren geprüft. SHA256SUMS listet alle übrigen Paketdateien, nicht sich selbst. Das Paket benötigt Windows PowerShell, Python-Launcher `py` und esptool 5.1.2.

## Verbleibende Risiken und Grenzen

- V7 wurde nicht physisch auf dem Panel getestet; elektrische BUSY-Signale, Serververhalten, tatsächliche Schlafdauer und Windows-Skriptausführung benötigen Nutzerabnahme. Hosttests ersetzen diese nicht.
- Der Zeitabzug arbeitet mit ganzen Sekunden und einer Untergrenze von 60 Sekunden. Weniger als eine Sekunde Rundung und die kurze Abschaltsequenz nach Berechnung kommen hinzu. Ein millis()-Wrap ist abgedeckt, mehrere volle 49,7-Tage-Perioden während eines Requests nicht.
- Ein 304 vertraut weiterhin dem Servervalidator und einem gültigen lokalen Slot. Ein fehlerhafter Servervalidator kann veraltete Bildinhalte behaupten. Kein neuer Bytevergleich wird eingeführt.
- Bereits vorhandene HTTPS-Firmwarepfade verwenden `setInsecure()`. Diese bestehende Eigenschaft wurde nicht erweitert oder umkonfiguriert und ist von der unverändert aktivierten TLS-Prüfung der Build-/Git-Werkzeuge zu unterscheiden. HTTPS-Gerätebetrieb bietet damit weiterhin keine Zertifikatsauthentifizierung.
- Der Report und die Hostprüfung weisen auch nach wie vor bestehende Abläufe aus: Fehler können einen Fehlertext anzeigen; Auto-Rotation und explizite BLE-/Setup-Bildaktionen haben eigene Anzeigeanlässe. Der unveränderte HTTP-Resultatpfad selbst rendert nicht.

## Physischer Abnahmeablauf – ausschließlich manuell

1. Die bisher funktionierende V6-ZIP separat sichern. V7-ZIP entpacken. Unter Windows `Get-FileHash .\firmware.bin -Algorithm SHA256` mit obigem Hash vergleichen. Python und `py -m pip install esptool==5.1.2` vorbereiten. COM-Port im Geräte-Manager unter Anschlüsse ermitteln.
2. Rahmen per USB anschließen. Erst nach eigener Entscheidung `flash-windows.cmd COM5` aus dem entpackten Ordner ausführen (COM5 ersetzen). Das Skript prüft alle Paketdateien, schreibt die vier Images und führt verify-flash aus. Kein Teil davon wurde durch den Agenten gestartet.
3. Pro Beobachtung einen auf höchstens 300 Sekunden begrenzten seriellen Mitschnitt bei 115200 Baud verwenden; nicht parallel zum Flashen öffnen. Längere Schlafzyklen über getrennte, jeweils begrenzte Mitschnitte rund um die erwartete Wake-Zeit und Serverzeitstempel prüfen. Keine Endlosmonitore.
4. Im Setup per BLE lokales Intervall 3600 Sekunden setzen, URL auf `/device/current.bmp`, URL-Modus einschalten. Server liefert ein neues gültiges 1200×1600-Top-down-4-bit-BMP, neuen ETag und Header 3555. Einen Wake auslösen. Vollständiges Bild genau einmal, Slot REUSE beziehungsweise einmaliges CREATED, genau ein DRF und POF nach stabilem BUSY erwarten. Nach circa 27 Sekunden Refresh plus Downloadzeit muss der Schlafwert entsprechend unter 3555 liegen.
5. Unverändertes Bild mit 304 und Header 60 liefern. Mindestens zwei Timer-Wakes in einem begrenzten Mitschnitt prüfen: kein Bildaufbau, keine Flash-Schreibtransaktion, Timer jeweils mindestens 60 Sekunden. Dasselbe nach manuellem Wake/Setup-Ausstieg (forceDownload) wiederholen.
6. Neue Bildversion/ETag mit 200 liefern: wieder genau ein vollständiger Refresh. Header 86400 akzeptieren lassen; ohne einen Tag Beobachtung zu blockieren Annahme und Timerlog prüfen, die reale Langzeitmessung separat planen.
7. Nacheinander fehlenden Header sowie `59`, `86401`, `+300`, `300s`, innere Leerzeichen und eine sehr lange Zahl liefern. Erwartung lokaler Timer 3600 beim Timer-Wake; bei fehlendem Header kein Invalid-Log nötig. OWS am Rand normalisiert HTTPClient wie oben beschrieben.
8. Erst gültigen Wert, dann HTTP 500/404 mit scheinbar gültigem Header 86400 liefern; anschließend WiFi-Ausfall und Body-Abbruch prüfen. Kein alter Serverwert darf den nächsten Schlaf bestimmen; Retry 60–300 Sekunden nach Ende der Fehlerbehandlung. Für untere Grenze BLE-Intervall 60, für obere Grenze 3600 verwenden. Netzwerk wiederherstellen, nächsten erfolgreichen Download und Slot-Wiederverwendung prüfen.
9. Setup/BLE-Modus separat testen: Konfiguration lesen/schreiben, BLE-Bild anzeigen, manuellen Refresh mit neuem Bild testen. BLE-only bleibt ohne URL-Timer. Für Auto-Rotation Rahmen während eines neuen Vollrefreshs drehen: Orientierung erst nach V6-Cleanup übernehmen, kein vorzeitiges POF/Reset oder gemischter Frame. Anschließend lokales Intervall erneut auslesen: der Serverheader darf es nie geändert haben.
10. Display und externe Flash-Nutzung über mehrere neue und unveränderte Bildzyklen prüfen. millis()-Wrap und Integerüberlauf sind deterministisch im Hosttest abgedeckt und erfordern kein wochenlanges Monitoring.

## Erwartete serielle Logs

```text
[SLEEP] Server suggestion accepted seconds=3555
[EPD] Path=EL133UF3 full-image-v6 storage=persistent-slot-v3
[EPD] V6 cleanup complete; orientation released
[MAIN] End of Update download=0 display=0
[SLEEP] Timetable wake in 3528 seconds (server=3555)
[DL] Image unchanged (HTTP 304); skipping flash write and display refresh
[SLEEP] Server suggestion accepted seconds=60
[IMAGE] Not rendering, image not modified
[MAIN] End of Update download=1 display=0
[SLEEP] Timetable wake in 60 seconds (server=60)
[SLEEP] Ignoring invalid server sleep header
[SLEEP] Download failed; retry in 300 seconds
[MAIN] Going to Sleep for 300 seconds (MotionWake: 0)
```

3528 ist das Rechenbeispiel bei exakt 27 Sekunden Gesamtzeit seit Headerempfang; reale Download-/Speicherzeit reduziert es zusätzlich. Die Zeilen stammen aus unterschiedlichen Testfällen, nicht aus einem einzigen Request. Ohne Header folgt das normale Going-to-Sleep-Log mit lokalem Intervall. Keine EPD-Refreshzeilen beim reinen 304-Fall erwarten.

## Rollback zur funktionierenden V6

Die unveränderte bisherige Datei liegt im ursprünglichen Arbeitsverzeichnis als `artifacts/openpaper-l-display-v6-windows.zip`. Die im vorhandenen V6-Abnahmebericht dokumentierte Firmware hat **1756704 Bytes** und SHA256 **cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78**.

V6-Paket getrennt entpacken, Hash prüfen, den tatsächlichen COM-Port im dortigen Skript einstellen und nur auf eigene Entscheidung die V6-Dateien mit den identischen ESP32-C6-Offsets flashen/verify-flash prüfen. Nicht V6- und V7-Dateien mischen und keinen vollständigen Flash-Erase ausführen. Nach Rückkehr drei neue Bildzyklen und unveränderte BLE-Konfiguration prüfen. V6 besitzt noch nicht den hier geprüften dynamischen Wake; der lokale BLE-Timer gilt wieder. Quellcode-Rücknahme allein flasht kein Gerät. Die vorhandenen V6-Artefakte wurden durch diese Arbeit nicht überschrieben.
