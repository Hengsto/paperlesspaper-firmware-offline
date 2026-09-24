# Persistenter Bildslot – Revision 3

Ziel: ESP32-C6-DevKitM-1 / EPD_TYPE_13INCH. Keine Serveränderung,
kein Gerätekontakt, kein Flashen, kein Commit oder Push.

## Befund und vollständiger Lebenszyklus

Der vorgefundene Arbeitsstand enthält bereits den ersten Storage-Fix. Die
Gerätelogs beweisen eine fehlgeschlagene zweite Allokation, aber nicht, welcher
Fehler-/Resetpfad zwischen beiden Downloads lief. Eine Löschung unmittelbar
nach erfolgreicher Darstellung ist in diesem Quellstand **nicht vorhanden**.

1. `loadImageFromWeb()` ruft bis zu sechsmal `downloadAndSaveFile()` auf.
   Der direkte BMP-Pfad reservierte `tmp.bmp`; andere Formate nutzten
   `tmp_raw.bin` plus `tmp.bmp` als Konvertierungsziel.
2. `ImageStorage::prepare()` öffnete die Datei, entfernte eine zu kleine Datei
   über `discard()` und rief bei fehlender Datei `createErasable()` auf.
   `discard()` verwendete bisher `SerialFlash.remove()`.
3. Nach Download rief `ImageStorage::finish()` `close()` auf. Bei Fehlern
   entfernte es zusätzlich den Dateieintrag. Weitere Entfernungspfade waren
   `discardHttpImages()` im Downloadfehlerpfad und in `processHttpDownload()`.
4. `processHttpDownload()` beendete bei Erfolg die NVS-Transaktion. Bei einem
   Neustart mit gesetztem `pending` entfernte `recoverImageTransaction()` bisher
   beide Bilddateien, auch wenn die reservierten Sektoren noch vorhanden waren.
5. Die Hauptschleife ruft `setImageFromFS()` auf. Der 13-Zoll-Pfad in
   `src/epaper_display.cpp` öffnet die Datei, liest BMP-Offset und Pixel, überträgt
   die Pixel zum Panel, führt gegebenenfalls `display.refresh()` aus und ruft
   `saveFile.close()` auf (aktuell Zeile 524). Kein remove, rename oder erase.
   Der 7-Zoll-Pfad hatte nicht einmal ein close; dieses wurde ergänzt.
6. Danach werden ggf. Last-Modified-Einstellungen gespeichert, `debugFS()`
   aufgerufen und die Statusmeldung ausgegeben; anschließend folgt Deep Sleep.
   `debugFS()` liest nur Speicherdiagnostik. Es löscht keine Bilddatei.
7. Weitere frühere erase-Aufrufe lagen in BLE `START` und `resetAll()`, nicht
   nach normaler Darstellung. Sie löschten Pixel, aber keine Allokation.

Die gepinnte Bibliothek implementiert `close()` leer
(`lib/SerialFlash/SerialFlash.h:131`). `remove()` nullt den Namenshash und lässt
Adresse/Länge stehen (`SerialFlashDirectory.cpp:190`). `SerialFlashFile::erase()`
löscht ausschließlich Inhaltsblöcke (`:382`). Keine dieser Operationen gibt
Allocator-Tail zurück. Es gibt keinen Bilddatei-rename-Pfad.

## Umsetzung

`ImageStorage::IMAGE_SLOT` heißt absichtlich weiterhin `tmp.bmp`. Damit kann
jede vorhandene, korrekt ausgerichtete 983040-Byte-Datei ohne neue Allokation
übernommen werden, auch bei `free_tail=0`. `SLOT_BYTES` ist unveränderlich
983040. Es gibt im Anwendungscode genau eine `createErasable()`-Stelle, im
Storage-Modul. URL, Last-Modified und Bildinhalt sind keine Allokationsschlüssel.
Die HTTP-Last-Modified-Abkürzung wurde entfernt: auch gleiche Validatoren bei
unterschiedlichen URLs führen zu einem erneuten Schreiben desselben Slots.

Die letzten 16 Bytes innerhalb der reservierten Datei enthalten Commit-Magie,
logische Länge und komplementäre Prüffelder. Vor jeder Pixeländerung wird ein
alter Commit ungültig geschrieben und überprüft. Anschließend werden die
Slotsektoren, beginnend mit dem Metadatensektor, mit begrenzter Wartezeit gelöscht.
Nach vollständig per Readback geprüften Pixelwrites wird der Commit geschrieben
und zurückgelesen. Die Verzeichnislänge bleibt immer 983040; die logische Länge
ist separat über `logicalLength()` verfügbar. Maximaler Inhalt: 983024 Bytes.

`finish()`, Downloadfehler, Boot-Recovery, BLE START/END und Bildinvalidierung
entfernen keinen Dateieintrag. Display und BLE-Fallback beachten die persistente
Gültigkeit. Eine Unterbrechung darf das alte Bild ungültig machen; der Slot bleibt
beim nächsten Start beschreibbar. Ein alter NVS-Transaktionsmarker invalidiert
nur den Inhalt und entfernt keine Allokation. Vorhandene Bilder ohne neuen
Commit-Trailer werden durch einen Download neu validiert.

HTTP akzeptiert im Ein-Slot-Modus ausschließlich validierte Top-down-4-Bit-BMPs
mit passender Geometrie, darunter die vorhandenen 960118-Byte-Serverbilder.
JPEG-/24-Bit-Konvertierung wird vor Slotänderung abgewiesen, da diese bisher eine
zweite Flashdatei benötigte. BLE-Rohbilder nutzen denselben Slot und werden erst
bei passender Gesamtlänge gültig. Die alten Konvertierungsfunktionen haben keinen
HTTP-Aufrufer mehr. Kein Server muss geändert werden.

## Einmalige externe Recovery

Bei fehlendem passenden Slot und unzureichendem Tail (oder inkompatibler alter
Slotgröße) diagnostiziert `inspect(true)` alle belegten Verzeichniseinträge:
Name, Adresse, reservierte Länge, gelöscht/aktiv. Nur ein valides Verzeichnis
mit ausschließlich bekannten Bildnamen (`tmp.bmp`, `tmp_raw.bin`, exakt `tmp.gz`), einschließlich
der gelöschten Einträge, darf zurückgesetzt werden. Unbekannte oder ungültige
Metadaten, unpassende Blockgröße, zu kleiner Chip und SPI-Fehler sperren Recovery.

Vor dem Reset wird `image-cache/slot-recovery` über Preferences dauerhaft gesetzt
und der Schreiberfolg geprüft. Ohne bestätigte Sperre erfolgt kein Reset. Diese
Sperre ist bewusst strenger als einmal pro Vollzustand: sie erlaubt insgesamt
höchstens eine automatische Recovery, solange dieser NVS-Schlüssel besteht.
Weder HTTP-Retries noch Deep Sleep noch Neustart setzen sie zurück.

Gelöscht wird ausschließlich Block 0 des externen SerialFlash auf CS_FLASH_PIN
(CS 21). Danach wird genau ein Slot angelegt und dessen Inhaltsblöcke gelöscht.
Der restliche alte Bildinhalt ist nicht mehr adressierbar; ein zeitaufwendiges
Chip-Erase ist nicht nötig. Kein interner Flash-Reset, kein NVS-Erase, kein
WLAN-Reset und kein SPIFFS-Format sind Teil dieses Recovery-Pfads. NVS wird nur
für die vorhandenen Transaktionsdaten und die neue Recovery-Sperre beschrieben.

Logsignaturen:

- `[FLASH] Persistent image slot v3 (legacy tmp.gz recovery): 983040 bytes, allocation retained`
- `[FLASH] Entry=... name=... deleted=... address=... reserved=...`
- `[FLASH] RECOVERY ONCE: external image directory block 0 only; latch persisted`
- einmal `[FLASH] Slot CREATED ... reserved=983040`
- danach `[FLASH] Slot REUSE ... reserved=983040 free_tail=...`

Scheitert eine Recovery nach dem Setzen der Sperre mit unlesbarem Verzeichnis,
bleibt die Firmware gesperrt statt wiederholt destruktiv zu löschen. Ein bereits
vollständig gelöschtes leeres Verzeichnis kann ohne erneuten Reset initialisiert
werden. Die Recovery schützt unbekannte Dateien auch dann, wenn sie gelöscht
markiert sind.

## Prüfung und Artefakt

`./tests/run_host_tests.sh` verwendet den echten gepinnten SerialFlash-Allocator
und die produktiven Storage-Funktionen mit RAM-basierter NOR-Simulation
(nur 1→0 beim Schreiben). Zusätzlich wird die unveränderte Funktion
`downloadAndSaveFile()` aus `src/main.cpp` extrahiert und gegen simulierte
HTTP-/SPI-Schnittstellen kompiliert, damit keine zweite Downloaderimplementierung
getestet wird. Compiler: `-Wall -Wextra -Werror -fsanitize=undefined`.

Abgedeckt sind 24 aufeinanderfolgende echte Downloaderaufrufe mit wechselnden
URLs, Validatoren und Bildinhalten, Disconnect, Stromunterbrechung beim Schreiben,
Readback und Neustart. Jeder Durchlauf prüft Allokationen=1 und free_tail=0.
Storage-Tests prüfen außerdem variable logische Längen, neun Unterbrechungspunkte
bei Invalidierung/Erase/Write/Commit mit jeweils 20 Folgeschreibvorgängen,
vorhandenen Altslot bei vollem Chip, Recovery auf 1 MiB und dem gemeldeten 16 MiB
mit erschöpftem Tail, jeweils 24 Downloads ohne weitere Allokation, sechs
Recovery-Retries mit persistenter Sperre, fehlgeschlagene Verzeichniswrites,
unbekannte aktive/gelöschte Dateien, zu kleinen Chip, ungültiges Verzeichnis,
SPI-Timeouts und stille Schreibfehler. Hardware-Timing und echte Stromausfälle
sind damit nicht physisch validiert.

Build: `/tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1`.
`src/types.h` definiert EPD_TYPE_13INCH. Das neue Windows-Paket heißt
`artifacts/openpaper-l-persistent-slot-v3-windows.zip`; es enthält Firmware,
Bootloader, Partitionstabelle, boot_app0, manuell ausführbares Windows-Skript,
Prüflogs und SHA256SUMS. Es wurde kein Flashskript ausgeführt.

## Legacy-Recovery-Korrektur v3

Der physische v2-Test zeigte 15 gelöschte `tmp.gz`, eine aktive `tmp.gz` und
anschließend eine gelöschte `tmp.bmp`, alle mit je 983040 Bytes. Zusammen mit
dem 65536-Byte-Verzeichnisblock sind das exakt 16777216 Bytes; `free_tail=0`.
Die v2-Whitelist erkannte `tmp.gz` nicht und setzte deshalb `imageOnly=false`.
Die Recovery-Whitelist erlaubt jetzt zusätzlich ausschließlich den exakten,
groß-/kleinschreibungssensitiven Namen `tmp.gz`, sowohl aktiv als auch gelöscht.
Es gibt keine Erweiterung auf beliebige `.gz`-Dateien oder Namenspräfixe.

Die Sicherheitsprüfung erfolgt weiterhin vor jedem Aufruf der NVS-Sperrfunktion.
Im vorliegenden v2-Ablehnungspfad war bereits `!s.imageOnly` wahr. Durch die
Kurzschlussauswertung des bisherigen `||`-Ausdrucks wurde `recoveryGate()` nicht
aufgerufen: Dieser Blockierfall hat die Sperre **nicht gesetzt**. Das ist durch
Quellprüfung und eine Host-Rekonstruktion mit der alten Whitelist belegt. Es wurde
kein NVS-Inhalt auf dem Gerät ausgelesen; ein unabhängig vorher gesetzter Wert
kann ohne Gerätekontakt nicht überprüft werden.

Die bisherigen kombinierten Blockiermeldungen sind getrennt:

- `RECOVERY blocked: unknown or invalid metadata/files; NVS latch untouched`
- `RECOVERY blocked: NVS latch already set`
- `RECOVERY blocked: NVS latch read/write failed`
- Für deaktivierte Recovery, SPI-Fehler oder fehlenden Gate-Callback zusätzlich:
  `RECOVERY blocked: disabled, SPI fault or missing gate; NVS latch untouched`

Der Gate-Callback unterscheidet dafür bestätigte Freigabe, bereits gesetzte
Sperre und fehlgeschlagenen NVS-Zugriff. Nur bestätigte Freigabe erlaubt den Reset.
Umfang und Einmaligkeit des externen Resets sind unverändert.

Der neue Host-Test baut das exakte 17-Einträge-Gerätelayout mit dem echten
SerialFlash-Allocator auf und prüft jede Adresse, Länge, den Namen und den
Löschstatus direkt im Verzeichnis. Genau eine Recovery erzeugt genau einen neuen
`tmp.bmp`-Slot. Erst danach folgen 24 vollständige Schreib-/Readbackzyklen über
REUSE mit simuliertem Neustart: unveränderte Slotadresse, genau ein Dateieintrag,
keine weitere Allokation und kein weiterer Recovery-Gate-Aufruf.

Zusätzliche Negativtests lassen `keep.dat`, `tmp.gz.bak`, `TMP.GZ` und `other.gz`
jeweils aktiv und gelöscht Recovery blockieren und prüfen Gate-Aufrufe=0,
Sperre=false und Verzeichnis-Erases=0. Ein weiterer Test kompiliert dieselbe
Storage-Implementierung mit der alten Whitelist: Sechs Versuche gegen das exakte
Gerätelayout rufen den NVS-Gate kein einziges Mal auf und verändern nichts.

Tests: **294 Storage-/Formatfälle bestanden**, zusätzlich **24 produktive
HTTP-Downloads** mit wechselnden URLs/Validatoren/Inhalten, Disconnect und
simulierter Schreibunterbrechung; Allokationen=1. Rekonstruktion der alten
Whitelist-Ablehnung ebenfalls bestanden. Keine physische Hardwareprüfung.

Build v3: **SUCCESS**, ESP32-C6-DevKitM-1 / EPD_TYPE_13INCH.
RAM 173392 / 327680 Bytes, App-Flash 1696636 / 1900544 Bytes.
Firmwaredatei: **1751824 Bytes**.
SHA256 `artifacts/firmware.bin` und `firmware.bin` im Windows-ZIP:
`d4c3575c3835f9fc6a7cf60323f62a416f3fe3fd9bc9d8212fa99ee6cb0e071b`.

`artifacts/SHA256SUMS` und das SHA256SUMS im neuen Paket gehören zu v3.
Die separat benannten v2-/älteren ZIPs sind historische Artefakte.
