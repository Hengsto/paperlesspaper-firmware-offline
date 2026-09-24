# Display V5: BUSY-Abschluss statt Mindestdauer

> Historischer V5-Bericht. Der zweite physische V5-Lauf zeigte eine ACC-/Power-off-Race. Aktuell freigegebener Stand: V6 mit drei erfolgreichen physischen Wiederholungen; siehe [FINAL_HARDWARE_VALIDATION.md](FINAL_HARDWARE_VALIDATION.md). Frühere V5-Freigabeaussagen gelten nicht als aktueller Betriebsstand.

Stand: 24.09.2026. Ziel: ESP32-C6-DevKitM-1, EPD_TYPE_13INCH / EL133UF3.
Dieser Bericht ersetzt ausschließlich die V4-Aussagen zur 10-Sekunden-Prüfung in DISPLAY_ANALYSIS.md. Storage V3 und die übrige V4-Ansteuerung bleiben erhalten.

## Ursache und Quellenvergleich

Der physische V4-Sechsfarbentest zeigte laut Nutzer ein korrektes Bild ohne Ghosting, vollständige Übertragung, BUSY-Aktivierung und -Abschluss bei 10148 ms sowie erfolgreichen POF. Beim folgenden current.bmp waren Download, Slot REUSE und beide RAM-Hälften ebenfalls vollständig. Die Firmware erklärte den bereits abgeschlossenen Refresh allein aufgrund der Messdauer unter 10000 ms zum Fehler. Das ist ein Software-Fehlalarm; die gemeldete Dauer belegt keinen Paneldefekt.

Die Quellen wurden aus den vorhandenen Vergleichskopien ausschließlich gelesen:

| Quelle | Tatsächliche Abschlussbedingung |
| --- | --- |
| [Waveshare ESP32 EPD_13in3e.cpp](https://github.com/waveshareteam/e-Paper/blob/master/E-paper_Separate_Program/13.3inch_e-Paper_E/ESP32/EPD_13in3e.cpp), lokale Kopie /tmp/openpaper-display-research/waveshare_esp32.cpp | ReadBusyH wartet auf HIGH (LOW = aktiv), pollt alle 10 ms und wartet danach 20 ms. PON → BUSY → 50 ms → DRF 00 → BUSY → POF 00. Der zusätzliche BUSY-Wait nach POF ist dort auskommentiert. Keine optische Mindestdauer. |
| [Öffentliche Cloud-Firmware, Commit e9111287a6279720acccee3776f114a2ca565b6d](https://github.com/paperlesspaper/paperlesspaper-firmware/blob/e9111287a6279720acccee3776f114a2ca565b6d/src/epaper_display.cpp) | Enthält einen 13-Zoll-Pfad und die zusätzliche Prüfung refreshDuration < 10000 (13-Zoll-Pfad Zeile 588). Diese Anwendungsheuristik ist keine BUSY-Protokollanforderung; V4 hatte sie übernommen. |
| Offline-Referenz /tmp/openpaper-firmware-reference, Commit 0961aa69ffeddfe505f7a2bb4b7c45f49308b2d6 | display.refresh() ohne diese Mindestdauer. |
| Verwendete GxEPD2-Version ffb2031f90220cd4a88de682d6c509103e27935c, src/epd7c/GxEPD2_1330c_EL133UF3.cpp und src/GxEPD2_EPD.cpp | PON und DRF verwenden _waitWhileBusy. Mit BUSY-Pin entscheidet dessen inaktiver Pegel bzw. Timeout; full_refresh_time=40000 erzwingt dabei keine Mindestdauer. Die Bibliotheksroutine liefert keinen Fehlerstatus zurück und beweist keine Aktivierungsflanke. |

V5 behält die vollständige Waveform ohne Quick-Reset bei und qualifiziert das BUSY-Signal strenger als diese einfachen Wartepfade. Eine zweite Weißdarstellung oder ein zweiter optischer Refresh ist nicht erforderlich und wurde nicht ergänzt.

## Exakte Änderungen

- src/epaper_13inch_transfer.h: Dauergrenze entfernt. waitStableLevel prüft den Pegel im Abstand von 1 ms. Nach DRF muss BUSY innerhalb von 2000 ms mindestens 5 ms durchgehend aktiv beobachtet werden. Anschließend muss BUSY innerhalb von 120000 ms mindestens 20 ms durchgehend idle sein. Erst danach wird DRF als abgeschlossen protokolliert und POF 0x02:00 an beide Controller gesendet. Nach 1 ms wird auch POF bis zu 120000 ms auf 20 ms stabiles idle überwacht. Die Idle-Prüfungen vor und nach PON verwenden dieselbe stabile Pegelprüfung.
- src/epaper_display.cpp: Pfadkennung full-image-v5; BEGIN nennt busy_active_stable_ms=5 und busy_idle_stable_ms=20; END nennt idle_stable_ms=20 und die weiterhin gemessene elapsed_ms. Die Dauer dient nur der Diagnose. POF complete; image update successful erscheint ausschließlich nach erfolgreichem POF-Wait.
- tests/host/display_test.cpp: zeitgesteuerte BUSY-Fehlersimulationen und Regressionen für kurze gültige Refreshs, Entprellung und POF ergänzt.
- DISPLAY_REFRESH_TIMING_FIX.md sowie V5-Build-, Test-, Provenienz- und Auslieferungsartefakte erstellt.

Bei jedem Pegelwechsel beginnt nur die Stabilitätsprüfung neu, niemals der Phasen-Timeout. Ein dauerhaft flatternder Abschluss läuft daher sicher in einen Fehler. Der Timeout hat Vorrang, wenn die Stabilitätszeit erst am/über dem Timeout erreicht würde. Zeitdifferenzen sind unsigned und überstehen millis()-Überlauf.

POF verlangt wie die bisherigen Treiber einen stabilen Idle-Abschluss, keinen separaten Aktivierungsnachweis. Der explizite Aktivierungsnachweis gilt für DRF. Ein POF-Timeout oder instabiler POF-Abschluss lässt den gesamten Displayaufruf fehlschlagen, auch wenn zuvor PANEL REFRESH END erschien. Fehler während DRF führen weiterhin nicht zu einem voreiligen POF im Refresh-Helfer. Der bestehende übergeordnete Sleep-/Fehlerpfad wurde nicht verändert.

## Erhaltene Eigenschaften

Vorher-/Nachher-SHA256 bestätigen unveränderte src/main.cpp, src/image_storage.cpp, src/image_storage.h, src/types.h und platformio.ini. Die vollständige getColor-Funktion und der Transferteil einschließlich SPI_HZ, writeFrame und fullWindow wurden zusätzlich bytegleich mit dem V4-Ausgangsstand verglichen. Nachweis: artifacts/display-v5-provenance.json.

Damit bleiben Persistent Slot V3, 983040-Byte-Reservierung, tmp.gz-Legacy-Recovery samt Whitelist/NVS-Sperre, EL133UF3-Auswahl, Farbmapping/Nibble-Reihenfolge, 10-MHz-SPI und die vollständige Zwei-Controller-Übertragung erhalten: jeweils 960000 Pixel/480000 Bytes, insgesamt 1920000 Pixel/960000 Bytes. Registerinitialisierung, Reset, Full-Window-Umschaltung, PON/DRF/POF-Befehle und integrierte Waveform sind unverändert. Es gibt weiterhin genau einen DRF pro erfolgreicher Darstellung. Keine Serveränderung.

## Tests und Build

Ausgeführt: ./tests/run_host_tests.sh, mit -Wall -Wextra -Werror und UndefinedBehaviorSanitizer. Alle Tests bestanden; Log: artifacts/display-v5-tests.log.

| Regression | Ergebnis |
| --- | --- |
| Gültiger Refresh, gemessene Gesamtdauer 9999 ms | Erfolg, genau ein DRF, stabiler Abschluss, POF erfolgreich |
| Gültiger Refresh, gemessene Gesamtdauer 10148 ms | Erfolg |
| Gültiger Refresh, gemessene Gesamtdauer 525 ms | Erfolg; keine versteckte lange Mindestdauer |
| BUSY nach DRF nie aktiv | Fehler nach Aktivierungsfrist |
| BUSY bis Timeout aktiv | Fehler, kein DRF-END |
| Isolierter aktiver 1-ms-Glitch | Fehler, kein gültiger Aktivierungsnachweis |
| Wiederholter instabiler Idle-Abschluss | Fehler innerhalb des unverlängerten Timeouts |
| 5-ms-Idle-Lücke mitten im Refresh | Kein vorzeitiger Abschluss; später regulärer Erfolg |
| POF normal | Erfolg erst nach stabilem Idle |
| POF dauerhaft aktiv oder instabil | Displayfehler trotz abgeschlossenem DRF |
| PON dauerhaft aktiv | Fehler vor DRF |
| Stabilitätszeit knapp vor/am Timeout | Exakte Grenzprüfung bestanden |
| millis()-Überlauf | Erfolg ohne Zeitfehler |
| Beide RAM-Hälften, drei Muster, beide Rotationen | Alle Pixel, Bytezahlen und unverändertes Mapping geprüft |
| Abgebrochener Bildlesevorgang | Fehler, kein DRF |

Insgesamt 23 Displayfälle, 294 Storage-/Formatfälle und 24 Produktions-HTTP-Downloads mit wechselnden URLs/Hashes/Inhalten, Verbindungs- und Stromunterbrechung im Hostmodell bestanden. Die Allokationszahl bleibt nach dem ersten Slot bei 1. Das reale Legacy-Layout (15 gelöschte tmp.gz, eine aktive tmp.gz, eine gelöschte tmp.bmp) führt zu genau einer Recovery und anschließend 24 REUSE. Die frühere Whitelist-Ablehnung setzt nachweislich keine NVS-Sperre. git diff --check bestanden.

Build: /tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1, erfolgreich. Buildlog: artifacts/firmware-display-v5-build.log. RAM 173392/327680 Bytes (52,9 %); Programmnutzung 1697826/1900544 Bytes (89,3 %). Die Binärdateigröße enthält zusätzlich Imageformat/Alignment und ist daher größer. esptool image-info bestätigt das erzeugte ESP32-C6-Image; Ausgabe in artifacts/image-info.txt. Kein Schreibzugriff auf ein Gerät.

## Auslieferung und Prüfsummen

Firmware: artifacts/firmware.bin

Größe: **1753200 Bytes**

SHA256: **c4f0eddc66abaa125e2a60958bb410c9559a3d8d1f2dc177a33c56485b60b685**

Windows-Paket: artifacts/openpaper-l-display-v5-windows.zip

Entpackter Paketstand: artifacts/display-v5-windows/ mit firmware.bin, bootloader.bin, partitions.bin, boot_app0.bin, manuell ausführbarem flash-windows.cmd, diesem Bericht, Build-/Testlogs, image-info.txt, Provenienz und SHA256SUMS. Firmware im ZIP, im Paketverzeichnis, im Buildverzeichnis und artifacts/firmware.bin wurden bytegleich geprüft. Alle ZIP-Einträge wurden nach Erstellung gegen SHA256SUMS validiert. ZIP-Größe: **1098486 Bytes**. ZIP-SHA256: **f6978ea95fbbe48cf184ccd23add2d8e3ac2acf434457140008c4f0442df30c3**. Die Prüfsumme steht außerdem in artifacts/openpaper-l-display-v5-windows.zip.sha256; bewusst außerhalb des ZIP, um eine zirkuläre Prüfsumme zu vermeiden. Das bestehende Auslieferungs-ZIP wurde nicht neu gepackt; der darin enthaltene Bericht ist der historische Stand vor dem physischen Test. Maßgeblich für die abschließende Bewertung sind die aktualisierten Repository-Berichte.

## Physischer V5-Test bestätigt (Nachtrag)

Am 24.09.2026 meldete der Nutzer den physischen V5-Test über `/device/current.bmp`
als technisch erfolgreich. Die folgenden Werte stammen aus dem vom Nutzer
bereitgestellten Gerätelog; hier wurde kein Gerät erneut angesprochen oder geflasht.

| Beobachtung | Physisches Ergebnis |
| --- | --- |
| Persistenter Bildslot | V3 erkannt und gültig |
| Download | 960118 Bytes |
| Wiederverwendung | `Slot REUSE address=65536 reserved=983040` |
| Schreiben/Readback | `Stored verified=960118 ok=1` |
| Displaypfad | `EL133UF3 full-image-v5` |
| Master / Slave | jeweils vollständig, 480000 Bytes |
| Gesamtübertragung | 960000 Bildbytes |
| BUSY | aktiv erkannt, danach 20 ms stabil idle |
| Refreshdauer | 26816 ms (Diagnosewert, kein Mindestzeit-Gate) |
| Power-off / Endstatus | `POF complete`; `download=0 display=0` |

Damit ist für diesen Lauf die komplette Kette Download → Slot-REUSE → verifiziertes
Schreiben → beide RAM-Hälften → BUSY-Abschluss → POF physisch bestätigt. Der
Einzellauf belegt weder einen physischen Refresh unter 10000 ms noch alle
Temperatur-/Versorgungsbedingungen oder eine separat dokumentierte optische
Langzeit-/Ghosting-Abnahme. Kurze gültige Refreshs sind weiterhin hostseitig geprüft.

### Separater Wi-Fi-Cleanup-Befund

Das nachgelagerte `ESP_ERR_WIFI_NOT_INIT` beim Disconnect liegt nach erfolgreichem
Bildabschluss und ist für die bereits abgeschlossene Bilddarstellung irrelevant.
Im vorhandenen Code wird vor `setImageFromFS()` und später in `gotToDeepSleep()`
erneut `WiFi.disconnect(true)` aufgerufen. Das passt zu einem Disconnect nach
bereits abgeschaltetem Wi-Fi; ohne zusätzlichen Trace ist die genaue interne
Auslösung nicht unabhängig bewiesen. Der Befund bleibt eine separate Cleanup-
Aufgabe. **Kein Display-, Storage- oder Wi-Fi-Code wurde deswegen geändert.**

## Offene Risiken und weitere physische Abnahme

V5 ist auf dem Host getestet, für das Ziel gebaut und im oben dokumentierten einzelnen `/device/current.bmp`-Lauf physisch erfolgreich geprüft. Die 5-ms-Aktivierungsqualifizierung ist ein kurzer Software-Glitchschutz, keine Herstellervorgabe für die optische Waveform. Die 20-ms-Idle-Qualifizierung orientiert sich an der Hersteller-Nachwartezeit und überprüft dabei tatsächlich den Pin. 1-ms-Abtastung kann kürzere Störungen zwischen Abtastungen nicht erkennen. BUSY bestätigt den elektrischen Ablauf, nicht die optische Bildqualität. Die bestehenden 2-s-Aktivierungs- und 120-s-Phasenbudgets müssen im realen Temperatur-/Versorgungsbereich ausreichend sein. Ein physikalisch gültiger, aber kürzer als 5 ms aktiver DRF würde abgewiesen; bei diesem Panel ist das kein optischer Refresh im beobachteten Sekundenbereich. Energieverbrauch wurde nicht gemessen; es kommt kein zweiter Refresh hinzu, lediglich kurze Pegelqualifizierung.

Die folgende erweiterte Wechsel-/Sichtprüfung bleibt für den Nutzer vorgesehen. Sie wurde hier nicht ausgeführt; der oben gemeldete einzelne current.bmp-Lauf ist bereits bestanden:

1. ZIP entpacken; Firmwaregröße und SHA256 oben prüfen. Die Installation von V5 erfolgt ausschließlich durch den Nutzer. flash-windows.cmd enthält COM5 als anzupassenden Platzhalter und wurde nicht ausgeführt. Keine Speicherbereinigung/NVS-Löschung durchführen.
2. Gleiche Versorgung und Orientierung wie beim erfolgreichen V4-Sechsfarbentest verwenden. Serielles Log ab Start vollständig sichern. Pfad muss EL133UF3 full-image-v5 storage=persistent-slot-v3 melden.
3. Über die bestehende Gerätekonfiguration zuerst /device/six-colors.bmp abrufen. Slot REUSE erwarten; bei bereits vorhandenem Slot darf keine neue Allokation/Recovery stattfinden. Beide RAM-complete-Meldungen und RAM coverage=FULL mit 1920000 Pixeln/960000 Bytes prüfen.
4. PANEL REFRESH BEGIN mit mode=FULL, controllers=both, DRF=0x12:00, quick=off und den Stabilitätswerten 5/20 ms erwarten. Bis zum Abschluss Versorgung unverändert lassen. PANEL REFRESH END muss busy_seen=1, busy_idle=1 und idle_stable_ms=20 melden, danach POF complete und download=0 display=0.
5. Auf /device/current.bmp wechseln und denselben Ablauf protokollieren. Auch elapsed_ms unter 10000 muss bei stabilem BUSY und erfolgreichem POF erfolgreich sein. Nach POF das vollständige Bild fotografieren und auf alte Sechsfarbflächen/Beschriftungen prüfen.
6. Mindestens drei weitere Wechsel six-colors.bmp → current.bmp ausführen. Für jeden Abruf Dauer, END, POF, abschließenden Displaystatus und Slot REUSE festhalten; die Reservierung muss 983040 Bytes bleiben. Tritt ein Fehler auf, vollständiges Log einschließlich der konkreten stage-Meldung aufbewahren.
7. Keine 0x0–0xF-Rohcode-Hardwaretests und keine absichtlichen BUSY-/Strommanipulationen während eines Panel-Refresh durchführen. Die Fehlerfälle sind bereits im Hostmodell abgedeckt. Keine Serveränderung für diesen Test erforderlich.

Kein Flashen oder Gerätekontakt durch den Agenten. Der abschließende lokale Commit ist jetzt vom Nutzer beauftragt; kein Push. Erneute Tests, finale Artefaktprüfsummen und Rollback-Grenzen stehen in [FINAL_HARDWARE_VALIDATION.md](FINAL_HARDWARE_VALIDATION.md).
