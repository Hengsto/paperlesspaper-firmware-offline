# EL133UF3: Differenzanalyse und physische V6-Validierung

Stand: 25.09.2026. Ziel: ESP32-C6-DevKitM-1 / EPD_TYPE_13INCH.
Keine Serveränderung, kein Gerätekontakt oder Flashen durch den Agenten. Abschließender lokaler Commit nun beauftragt; kein Push.
Der persistente V3-Slot einschließlich `tmp.gz`-Recovery bleibt erhalten.

## Aktueller Abnahmestand V6

**Drei aufeinanderfolgende physische V6-Läufe mit `/device/current.bmp` sind durch den Nutzer bestätigt.** Flash und verify-flash waren erfolgreich. Firmware: **1756704 Bytes**, SHA256 `cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78`.

| Lauf | Storage / Transfer | PANEL REFRESH END | Abschluss |
| --- | --- | --- | --- |
| 1 | Slot REUSE, 960000 Bildbytes, frozen rotation=0 | elapsed_ms=26810 | POF complete → orientation released → ACC Update Orient to Mem:1; download=0 display=0 |
| 2 | Slot REUSE, 960000 Bildbytes | elapsed_ms=26964 | POF complete; download=0 display=0 |
| 3 | Slot REUSE, 960000 Bildbytes | elapsed_ms=27015 | POF complete; download=0 display=0 |

Kein Lauf zeigte zwischen initReset und POF ein konkurrierendes powerOff. Im ersten Lauf erfolgte die ACC-Übernahme erst nach `V6 cleanup complete; orientation released`: Der zentrale Synchronisierungsfall ist damit physisch bestätigt.

Der zuvor erfolgreiche einzelne V5-Lauf (26816 ms) war keine ausreichende Freigabe: Der zweite V5-Lauf scheiterte nach einer ACC-Änderung und einem konkurrierenden powerOff. Ursache war der Tickerpfad `recheckAccOrient` → bei aktivem Display `deinitDisplay` → RESET/hibernate/powerOff/SPI und Pin-Deinitialisierung. V6 ersetzt ihn durch hardwarefreie atomare Prüfanforderungen, stabile Orientierung vor Beginn, einen unveränderlichen Frame-Snapshot, einen gemeinsamen rekursiven Ressourcenmutex und genau einen Abschluss vor der nachträglichen Orientierungsübernahme.

Storage V3, Farbmapping, beide Controller, 10-MHz-SPI und die V5-BUSY-Entprellung bleiben erhalten. Eine optische Mindestdauer von 10000 ms ist weiterhin **keine Erfolgsbedingung**. Kein zusätzlicher Weißrefresh. Die Ergebnisse belegen die drei gemeldeten Abläufe, keine vollständige Temperatur-/Langzeit-/Ghosting-Matrix.

Der nachgelagerte **ESP_ERR_WIFI_NOT_INIT** bleibt ein harmloser Cleanup-Befund für diese erfolgreich abgeschlossenen Displayläufe. Wiederholte WiFi.disconnect(true)-Aufrufe passen dazu; die genaue interne Auslösung wurde nicht separat instrumentiert. Kein Wi-Fi-Fix wurde hierfür hinzugefügt. Dynamisches Wake-Timing und die weitergehende Erkennung unveränderter Bilder sind spätere Optimierungen und kein Bestandteil dieser Fehlerbehebung.

Endgültiges Paket: `artifacts/openpaper-l-display-v6-windows.zip`. Technische Race-Analyse: [DISPLAY_ROTATION_RACE_FIX.md](DISPLAY_ROTATION_RACE_FIX.md). Erneute Tests, vollständiger Build, Bytevergleich, Rollback und lokaler Commit: [FINAL_HARDWARE_VALIDATION.md](FINAL_HARDWARE_VALIDATION.md).

**Historischer Kontext:** Alle folgenden Abschnitte beschreiben die frühere V4-Analyse
und deren damaligen Prüfstand. Die dort genannten 15 Displaytests, V4-Prüfsumme und
10-Sekunden-Bedingung sind keine Angaben zum finalen V5-Stand. Aktuelle Nachträge
stehen oben und im V5-/Abschlussbericht; die historische Analyse bleibt nachvollziehbar.

## Ergebnis und Grenzen (historische V4-Analyse)

Der gemeldete physische Befund ist ein unvollständig ersetzter optischer Zustand.
Die beiden bisherigen Logzeilen beweisen weder einen partiellen optischen Refresh
noch einen erfolgreich abgeschlossenen Vollrefresh. Bereits V3 ruft den
Vollrefresh der Bibliothek auf. Ein zwingend erforderlicher vorheriger Weißrefresh
ist anhand der Herstellerimplementierung **nicht belegt**.

Belegt sind ein fehlerhafter 25-Zeilen-RAM-Fallback, ungeprüfte Flash-Lesevorgänge,
Fenster-Kommandos außerhalb einer expliziten SPI-Transaktion und unzureichende
Refresh-Erfolgskontrolle. Ob der reale Lauf den Fallback nutzte, SPI-Daten verlor,
den Refresh zu früh beendete oder eine andere Hardware-/Versorgungsursache hatte,
lässt sich ohne vollständigen Zeit-/BUSY-Verlauf nicht entscheiden. Der neue Fix
beseitigt diese Softwareprobleme und macht die verbleibende physische Prüfung
nachvollziehbar; er ist kein behaupteter Nachweis, dass das Nachbild schon weg ist.

**Original-Backup 3.0.17 fehlt:** In den zugänglichen lokalen Projekt-, Backup- und
Arbeitsverzeichnissen unter `/srv`, `/home/dev`, `/tmp`, `/mnt`, `/media`, `/opt`
und `/root` wurde kein entsprechendes Firmwarebackup gefunden. Deshalb wurden
für dieses Backup weder image-info noch Strings, Partitionen oder Binärtabellen
analysiert. Es wurde kein aktuelles Download-Binary als Ersatz ausgegeben und
kein Backup verändert. Die öffentlichen Quellen sind nicht automatisch die
Quellen des tatsächlich ausgelieferten Binaries 3.0.17. Dieser Teil bleibt offen.

## Festgehaltene Vergleichsstände

- [Öffentliche Cloud-Firmware](https://github.com/paperlesspaper/paperlesspaper-firmware/tree/e9111287a6279720acccee3776f114a2ca565b6d):
  `e9111287a6279720acccee3776f114a2ca565b6d`, Commit vom 16.09.2026.
  Frischer Vergleichsklon `/tmp/openpaper-display-research/cloud-firmware`,
  unverändert und anschließend per Dateirechten schreibgeschützt.
- [Offline-Firmware](https://github.com/paperlesspaper/paperlesspaper-firmware-offline/tree/0961aa69ffeddfe505f7a2bb4b7c45f49308b2d6):
  `0961aa69ffeddfe505f7a2bb4b7c45f49308b2d6`, vorhandener unveränderter Referenzklon.
- V3: tatsächlicher Arbeitsstand vor dieser Aufgabe, gesichert als
  `artifacts/display-v4-evidence/epaper_display.before.cpp`.
- [Verwendeter GxEPD2-Fork](https://github.com/smarthomeagentur/GxEPD2/tree/ffb2031f90220cd4a88de682d6c509103e27935c):
  `ffb2031f90220cd4a88de682d6c509103e27935c`; dieser bereits verwendete Stand
  wird nun in `platformio.ini` fest gepinnt, ohne Bibliotheksquellen zu ändern.
- [Waveshare ESP32-Beispiel](https://github.com/waveshareteam/e-Paper/blob/master/E-paper_Separate_Program/13.3inch_e-Paper_E/ESP32/EPD_13in3e.cpp)
  und dessen Header wurden lesend gesichert. Sie verwenden vollständige
  Controllerdaten und einen Ablauf PON → DRF → BUSY-Ende → POF.

## Cloud, Offline und V3

| Merkmal | Öffentliche Cloud | Offline-Referenz | Persistent Slot V3 |
|---|---|---|---|
| 13 Zoll / EL133UF3 vorhanden | **Ja**, eigene Funktion und Klasse | Ja | Ja |
| Displaywahl | `EPD_TYPE_13INCH` in types.h | ebenfalls types.h | explizit 13 Zoll |
| Physische Auflösung | 1200×1600, zwei Hälften | gleich | gleich |
| Display-SPI | **10 MHz** | **20 MHz** | **20 MHz** |
| Bild-RAM-Transfer | 16/32/64 Teilfenster je Hälfte | gleich | gleich |
| Nicht-BMP-Offset | **4 Bytes**, Cloud-RAW | **0 Bytes**, BLE-RAW; Kommentar nennt irreführend 4 | 0; HTTP nur geprüftes BMP |
| BMP-Offset | aus Header 0x0A | gleich | geprüfter BMP-Vertrag, typ. 118 |
| Leseprüfungen | Zeilenlänge und Gesamtzahl | fehlen im Displaypfad | fehlen im Displaypfad |
| Refresh-Prüfung | Rückgabefehler bei Dauer <10 s | keine | keine |
| Farbabbildung getColor | 0→0, 1→5, 2→6, 3→3, 5→2, 6→1 | identisch | identisch |
| Dateispeicherung | u.a. tmp.gz, alter Allokatorpfad | tmp.bmp/tmp_raw.bin | fester tmp.bmp-Slot |

Der Cloud-Pfad ist in `src/epaper_display.cpp:392` klar vorhanden. Er ist keine
7-Zoll-Implementierung, die nur versehentlich für 13 Zoll verwendet wird.
Allerdings ist die GxEPD2-Abhängigkeit in dessen veröffentlichter platformio.ini
kommentiert und es gibt dort keinen mitgelieferten lib/GxEPD2-Baum. Aus dem
öffentlichen Cloud-Stand lässt sich deshalb nicht allein eine konkrete
Bibliotheksversion des Backups 3.0.17 rekonstruieren.

Die öffentlichen `part.csv` von Cloud und Offline sind identisch: NVS
0x9000/0x5000, otadata 0xe000/0x2000, app0 0x10000/0x1d0000, app1
0x1e0000/0x1d0000, SPIFFS 0x3b0000/0x40000, coredump 0x3f0000/0x10000.
Das sind **Quellkonfigurationen**, keine aus dem fehlenden Backup gelesenen Daten.

## Vollständiger bisheriger Anzeigepfad

1. Die Hauptschleife schaltet die Panelversorgung ein, lädt/prüft den V3-Slot und
   ruft `setImageFromFS()` auf. Der Wrapper verweigert ungültige Slotinhalte.
2. `setImageFromFS_13inch()` öffnet den Slot und bestimmt den Pixeloffset.
3. `enableQuickRefresh(..., false)` deaktiviert den vorzeitig per Reset
   abgebrochenen Schnellrefresh. `display.init()` reicht die Initialisierung
   an `GxEPD2_1330c_EL133UF3` weiter. Die eigentlichen Register werden erst beim
   folgenden RAM-Schreiben durch `_InitDisplay()` gesetzt.
4. `clearScreen(0x01)` ruft im konkreten 13-Zoll-Treiber lediglich
   `writeScreenBuffer()` auf. Es schreibt weißes RAM für beide Controller;
   es gibt hierbei **kein DRF und keinen optischen Weißrefresh**.
5. Der Anwendungscode überschreibt dieses RAM in Streifen: PTLW `0x83`, PTIN
   `0x91`, DTM `0x10`, pro Controller 600×1600 Pixel bzw. 480000 Bytes.
   Daher der Name „Partial Image“. In Summe sollen alle 960000 Bildbytes
   übertragen werden. Es handelt sich nicht absichtlich um ein kleines neues
   Bild über einem erhaltenen alten Hintergrund.
6. 16 Streifen ergeben 100 Zeilen, 32 ergeben 50 Zeilen. Der 64er-Fallback ergibt
   **25 Zeilen**, obwohl VRST/VRED in Zweizeileneinheiten berechnet werden.
   Erste Fenster umfassen dadurch z.B. 24 Zeilen, während 25 übertragen werden;
   Folgestarts werden abgerundet. Dieser Fallback ist inkonsistent.
7. Die Anwendung sendet nach den Streifen PTLW-disable außerhalb einer eigenen
   SPI-Transaktion. `display.refresh()` ruft standardmäßig `refresh(false)` auf.
   Im gepinnten Treiber folgen `_powerOn()`, BUSY-Warten, 30 ms, nochmals
   PTLW-disable an beide Controller und DRF `0x12` mit Datenbyte `0x00`.
   Der Treiber versucht also bereits einen **vollständigen** optischen Refresh.
8. `_waitWhileBusy()` beendet sein Warten nach 60 s mit einer Textmeldung,
   liefert aber keinen Fehler an die Anwendung. Ein nie aktiv gewordenes BUSY
   wird ebenfalls nicht als Fehler erkannt. V3 meldet danach ungeprüft Erfolg.
9. `close()` verändert den Slot nicht. Erst der spätere Schlafpfad ruft
   `hibernate()`/POF auf und schaltet die externe Panelversorgung ab.

## Initialisierung, Waveform und Entwicklungsstand

`_InitDisplay()` verwendet denselben Registerblock wie das Waveshare-Beispiel,
u.a. PSR DF69, CDI F7, TCON 0303, TRES 04B00320 sowie passende Master-/Slave-
Adressierung. Es wird keine eigene Spannungs-/Zeit-LUT hochgeladen. Der Pfad
verwendet die eingebaute Waveform gemäß Herstellersequenz. `_InitDisplayAlt()`
mit u.a. PSR DF6B wird in unserem Bildpfad **nicht** ausgewählt. `settings.lut`
ist kein Beleg für einen tatsächlichen LUT-Upload; im geprüften Bildpfad wird es
nicht zur Programmierung einer Waveform verwendet.

Die Bezeichnung „Hardware LUT conversion“ im Streamingcode meint nur `getColor()`:
eine Farbindextabelle. Sie ist nicht die elektrophoretische Refresh-Waveform.
Die tatsächliche werksprogrammierte Waveform des konkreten Panels kann ohne
passende Binär-/Hardwaredaten nicht verifiziert werden.

Die Offline-README bewirbt beide Displaygrößen. Es gibt keine eindeutige
Maintainer-Aussage „13 Zoll experimentell“ in den geprüften Quellen. Gleichzeitig
sind Fehler und unfertige Stellen sichtbar: veraltete Build-Auswahl, ungerader
Streifenfallback, fehlende Erfolgskontrolle sowie generische leere draw*-Methoden
und kopierte 7,3-Zoll-Metadaten im Fork. Ergebnis: ein vorhandener funktionsfähiger
Teilpfad, aber **keine belegte vollständige Produktionsvalidierung**.

[Issue #9](https://github.com/paperlesspaper/paperlesspaper-firmware-offline/issues/9)
meldet USB-/Batterie-/HTTP-Probleme beim OpenPaper L, während BLE-Bilder angezeigt
werden; außerdem identische Builds trotz zweier Größen. [Issue #11](https://github.com/paperlesspaper/paperlesspaper-firmware-offline/issues/11)
fragt nach der widersprüchlichen Größenwahl. Beide sind beim Abruf offen und ohne
Kommentare. Die Workflow-sed-Befehle ersetzen tatsächlich `SET_DISPLAY` in
main.cpp, während die aktive Auswahl in types.h liegt. Das erklärt die
Build-Verwirrung, beweist aber keinen bestimmten Refresh-/Farbfehler.

## Farben, Nibbles und bytegenauer Vergleich

| Farbe | Web-BLE / app/spectra.py / BMP-Index | getColor-Ausgabe = Hersteller-Controllercode |
|---|---:|---:|
| Weiß | 6 | 1 |
| Schwarz | 0 | 0 |
| Rot | 3 | 3 |
| Gelb | 5 | 2 |
| Blau | 1 | 5 |
| Grün | 2 | 6 |

Der [Herstellerheader](https://github.com/waveshareteam/e-Paper/blob/master/E-paper_Separate_Program/13.3inch_e-Paper_E/ESP32/EPD_13in3e.h)
benennt die Controllercodes **0,1,2,3,5,6**. Andere Werte werden nicht als
normale sechs Farben verwendet. Es erfolgen keine weiteren 0–F-Hardwaretests.
Insbesondere ist logischer Index 4 kein zusätzlicher zulässiger Farbtest:
`getColor()` bildet ihn und andere unbekannte Indizes auf Weiß ab. Das 4×4-
Indexraster kann daher keine 16 direkte Controllercodes darstellen.

In allen verglichenen Packern steht das linke/gerade Pixel im **hohen Nibble**,
das rechte/ungerade im niedrigen. Bei 180° dreht die Firmware Zeilen, Hälften,
Bytereihenfolge und Nibbles zusammen. Diese bestehende Abbildung ist unverändert.

Cloud-RAW enthält vier vorangestellte Bytes und danach gepackte Pixel. Der
13-Zoll-Cloud-Pfad überspringt vier Bytes; deren semantischer Inhalt wird dort
nicht validiert und ist damit nicht allein aus diesem Leser bewiesen. BLE-RAW
hat keinen solchen Header. BMP enthält Datei-/DIB-Header und Palette, gewöhnlich
118 Bytes. Im direkten Bildpfad werden die Indizes über `getColor()` interpretiert;
die BMP-RGB-Palette wird nicht zur Ermittlung anderer Controllercodes ausgewertet.
Eine bereits auf Hardwarecodes umgerechnete BMP-Payload würde doppelt umgerechnet.

Verglichen wurde der aktuelle Quell-Endpunkt `/device/six-colors.bmp`, ohne einen
Server oder ein Gerät anzusprechen: Aufruf seiner `diagnostic_bmp()`-Funktion,
Abgriff desselben RGB-Inputs vor `encode_bmp()`, Verarbeitung durch die originale
`GeneratePicture.generateFullBuffer()` mit epdoptimize 1.2.0, Custom-Palette,
Floyd–Steinberg, Serpentine, neutralem Tone-Mapping. Canvas-I/O wurde im Host
für identische Größe und Rotation 0 simuliert; Dithering und Packing stammen aus
dem originalen JS-Code. Beide angeforderten Engine-Modi js/wasm liefern:

- **960000 von 960000 Payloadbytes identisch, Differenzen=0**.
- Payload-SHA256: `917c63e52d4142c14d5861760c2305dc93081f5f3bfe7e222283ff4841b22615`.
- Vollständiges BMP: 960118 Bytes, SHA256
  `4e1a5a3bd778b182d40dd22ca781d757f8908bed882e8dc64a0af1fdd5d652cf`.
- Zusätzlich ein 8×4-Diffusionsvektor: 16/16 Bytes identisch in beiden Modi.

Das ältere lokale `/tmp/openpaper-spectra-validation/six-colors.bmp` ist ein
anderes, unbeschriftetes Bild mit anderer Feldreihenfolge. Es wurde nicht als
aktueller Endpunkt ausgegeben. Protokolle, Rohbytes, RGB-Input und Quell-Hashes
liegen in `artifacts/display-v4-evidence/byte-comparison.json` und `provenance.json`.

## Kleiner belastbarer Fix statt experimenteller LUT/Weißrefresh

- Nur der 13-Zoll-Bildpfad wird umgestellt. Display-SPI nun 10 MHz wie im
  öffentlichen Cloud-Pfad; SerialFlash-Takt und Speicherallokation unverändert.
  Dies schafft Timingreserve, beweist aber nicht, dass 20 MHz das Nachbild verursachte.
- Ein fester 600-Byte-Puffer schreibt Zweizeilenfenster, lückenlos über beide
  Controller. Kein ungerader Fallback, keine große dynamische Allokation.
  Flash-Lesen erfolgt ausschließlich bei inaktiven Panel-CS; das gemeinsame
  SPI-Bussystem erlaubt keinen 480000-Byte-Dauertransfer aus Flash bei aktivem
  Panel-CS. Deshalb bleiben RAM-Streifen nötig, obwohl das Bild vollständig ist.
- Jeder Lesevorgang und die logische Bildlänge werden geprüft. Bei Fehlern kein
  DRF. Rotation und `getColor()` bleiben bytegleich.
- Alle Kommandos nutzen den ausgewählten SPI-Bus und explizite Transaktionen.
  Zum Abschalten der Fenster wird exakt die vorhandene Neun-Nullbyte-Sequenz
  des gepinnten Treibers beibehalten; kein spekulatives PTOUT-/LUT-Kommando.
- Ein expliziter Herstellerablauf PON → 50 ms → **ein DRF** → BUSY-Ende → POF
  ersetzt den nicht überprüfbaren Bibliotheks-Rücksprung. DRF muss innerhalb von
  2 s BUSY aktivieren, BUSY muss innerhalb von 120 s enden. Wie im Cloud-Code
  wird eine Gesamtdauer unter 10 s als Fehler behandelt. Timeout/Kurzrefresh
  wird nicht als erfolgreiche Darstellung geloggt.
- Keine zusätzliche optische Weißlöschung. Das bestehende RAM-Weißfüllen dient
  weiterhin der verzögerten Treiberinitialisierung und ist kein Panelrefresh.

Die Bibliothek nennt 40 s für den Vollrefresh; das ist keine Messung dieses
Geräts. Tatsächliche Zeit steht künftig im Log. Ein zusätzlicher Weißrefresh
würde einen weiteren vollständigen Waveformzyklus und ungefähr dessen
Panelenergie benötigen; die genaue Energie hängt von Bild, Temperatur und
Versorgung ab und wurde nicht gemessen. Da die Herstellersequenz einen einzelnen
Bildrefresh unterstützt, wird diese Verdopplung nicht eingeführt.

Geändert: `src/epaper_display.cpp`, neues `src/epaper_13inch_transfer.h`,
`platformio.ini` (nur Pinning des bereits benutzten GxEPD2-Commits),
`tests/host/display_test.cpp`, `tests/run_host_tests.sh`, diese Analyse.
`src/main.cpp`, `src/image_storage.cpp`, `src/image_storage.h` und `getColor()`
sind gegenüber V3 hash-/textgleich; Nachweis in provenance.json.

## Tests und manueller physischer Ablauf

Host: 294 Storage-/Formatfälle, 24 produktive HTTP-Downloadtests sowie die
V2-Whitelist-Rekonstruktion bestehen weiterhin. Dazu 15 Displayfälle: vollständige
RAM-Abdeckung und Pixelvergleich für beide Rotationen und drei aufeinanderfolgende
Bilder; genau ein DRF; korrektes POF nach BUSY-Ende; nie aktives, zu kurzes und
hängendes BUSY; PON-/POF-Timeout; Zeitstempelüberlauf und Lesefehler. Die Simulation
prüft Bytes und Sequenz, nicht die optische Waveform auf Glas.

Physischer Ablauf, ausschließlich später vom Nutzer:

1. Neues Artefakt anhand SHA256 identifizieren. Es wurde hier nicht geflasht.
   Bei manuell installiertem v4 müssen `full-image-v4` und
   `storage=persistent-slot-v3` im Bildpfad erscheinen. Bestehende Orientierung
   unverändert lassen, ausreichende Versorgung sicherstellen und Logs vollständig
   vom Start bis Deep Sleep aufzeichnen.
2. Über den bestehenden `/device/six-colors.bmp`-Pfad das beschriftete Bild
   anzeigen lassen. Bis `PANEL REFRESH END ... elapsed_ms=...` und
   `POF complete` warten. Dauer mindestens 10000 ms; jeder FAILED-Eintrag
   bedeutet keinen erfolgreichen Test. Keine manuellen Resets während BUSY.
3. Das mitgelieferte **refresh-check.png** über die vorhandene Bildverwaltung
   als aktuelles Bild auswählen und den vorhandenen `/device/current.bmp`-Pfad
   abrufen lassen. Kein Serverumbau. Dieses deckende 4×4-Muster enthält nur
   Schwarz/Weiß, trägt neue `NEW 01`–`NEW 16`-Markierungen und ist **kein**
   0–F-Rohcode-Test. Alternativ liegt der bereits korrekt codierte
   `refresh-check.bmp` für den bestehenden BMP-Bereitstellungsweg bei.
4. Erwartete Logs: FULL RAM coverage 1200×1600, master und slave jeweils
   480000 Bildbytes, insgesamt 960000 Bildbytes / 1920000 Pixel, Refresh FULL,
   genau ein `PANEL REFRESH BEGIN`, danach BUSY-bestätigtes END und POF.
   Weiße Felder müssen frei von alten Farbnamen/-flächen sein. Beide Hälften,
   Randzeilen und frühere Textpositionen prüfen und nach Ende fotografieren.
5. Anschließend zurück zu six-colors.bmp, wieder vollständig abwarten, dann
   nochmals zum Schwarzweißmuster wechseln. Auch nach Deep Sleep müssen diese
   Wechsel ohne alte Beschriftungen funktionieren. Storage-Logs müssen REUSE
   zeigen, ohne neue Slotallokation oder erneute Recovery.
6. Bleiben alte Flächen trotz vollständig bestandener Logs sichtbar, ist die
   optische Ursache weiterhin offen. Dann weder Farben umdeuten noch 0–F-Tests
   fortsetzen; Zeit/BUSY/Versorgung und das fehlende originale Backup wären die
   nächsten belastbaren Diagnosegrundlagen.

## Build und Artefakt

Build ESP32-C6-DevKitM-1 / EPD_TYPE_13INCH: **SUCCESS**.
Firmware: `artifacts/firmware.bin`, **1753088 Bytes**.
SHA256: `cb1ff957dbec6e3b787ca8502ef8d4fd824116319d7636c36c054df3e8658c63`.
Windows-Paket: `artifacts/openpaper-l-display-v4-windows.zip`.
Die Firmware im Paket ist bytegleich mit artifacts/firmware.bin.
Prüflogs, image-info, SHA256SUMS und das manuell ausführbare Windows-Skript
liegen bei. Alle hier ausgeführten esptool-Aufrufe sind dateibasierte image-info,
keiner kommuniziert mit einem Gerät.
