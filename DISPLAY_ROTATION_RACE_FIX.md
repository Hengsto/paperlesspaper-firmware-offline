# Display V6: Race zwischen Auto-Rotation und EPD-Transfer

Stand: 25.09.2026. **V6 wurde durch den Nutzer physisch bestätigt:** Flash und verify-flash erfolgreich, anschließend drei aufeinanderfolgende reale Durchläufe mit `/device/current.bmp` bestanden. Geprüfte Firmware-SHA256: `cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78`. Kein Gerätekontakt oder Flashen durch den Agenten; lokaler Commit nun beauftragt, kein Push. Die umfassendere Bewegungs-/Temperatur-/Langzeitmatrix unten bleibt eine ergänzende Prüfung, keine bereits ausgeführte Abnahme.

## Physische V6-Ergebnisse – vom Nutzer bestätigt

| Lauf | Storage und Transfer | Refresh | Abschluss |
| --- | --- | --- | --- |
| 1 | Slot REUSE; vollständige 960000 Bildbytes; orientation frozen rotation=0 | PANEL REFRESH END elapsed_ms=26810 | POF complete; V6 cleanup complete; orientation released; erst danach ACC Update Orient to Mem:1; download=0 display=0 |
| 2 | Slot REUSE; vollständige 960000 Bildbytes | PANEL REFRESH END elapsed_ms=26964 | POF complete; download=0 display=0 |
| 3 | Slot REUSE; vollständige 960000 Bildbytes | PANEL REFRESH END elapsed_ms=27015 | POF complete; download=0 display=0 |

In keinem der drei Läufe trat zwischen initReset und POF ein konkurrierendes powerOff auf. Lauf 1 bestätigt insbesondere die tatsächliche Übernahme der Orientierungsänderung **erst nach** `V6 cleanup complete; orientation released`. Die End-to-End-Kette Slot-Wiederverwendung → vollständiger Transfer → Refresh → POF und die zurückgestellte Rotation sind damit physisch belegt. Quelle sind die vom Nutzer mitgeteilten Ergebnisse; hier wurden keine zusätzlichen Geräteläufe durchgeführt. Für Lauf 2/3 wurden keine konkreten frozen-Rotationen oder ACC-Änderungen mitgeteilt und werden nicht hinzuerfunden.

Die abschließenden erneut ausgeführten Hosttests, der Build, Artefaktvergleiche, Rollback und Commit-Nachweis stehen in [FINAL_HARDWARE_VALIDATION.md](FINAL_HARDWARE_VALIDATION.md).

## Befund und bewiesener Aufrufpfad in V5

Die beiden vom Nutzer gelieferten physischen Ergebnisse:

| Lauf | Orientierung und Ablauf | Ergebnis |
| --- | --- | --- |
| V5 erfolgreich | X=0 Y=7 Z=6, Orient=1; kein auffälliges powerOff im RAM-Transfer; BUSY aktiv und anschließend idle; elapsed_ms=26816; POF complete | download=0 display=0 |
| V5 fehlgeschlagen | X=0 Y=0 Z=10, Orient=0; ACC schreibt 0; initReset; ACC schreibt 1; powerOff : 6; anschließend beide RAM-Hälften vollständig; DRF ohne stabilen BUSY-Beginn | download=0 display=-1 |

Der V5-Code hatte folgenden direkten Pfad:

```text
loop()
  -> accUpdateOrient() -> accInit() -> deviceOrientation/displaySetRotation()
  -> checkOrientationInBackground(..., true)
       -> periodicAccCheck.attach_ms(1000, recheckAccOrient, ...)
          [Arduino Ticker: ESP_TIMER_TASK, unabhängig vom loop-Task]
          -> recheckAccOrient()
               -> accInit(true) [I2C-Messung]
               -> Vergleich mit readIntFromFlash(220)
               -> systemData.deviceOrientation = accCheck
               -> "[ACC] Update Orient to Mem: ..."
               -> writeIntToFlash(..., 220)
               -> displaySetRotation(...)
               -> if (isEpaperActive()) deinitDisplay()
                    -> RESET GPIO1 OUTPUT/HIGH, 50 ms, LOW, 20 ms
                    -> displayIsInit = false
                    -> display.hibernate()
                         -> display.epd2.hibernate()
                         -> GxEPD2_1330c_EL133UF3::powerOff()
                              -> _pof(CS_MASTER_SLAVE), SPI-Befehl
                              -> _waitWhileBusy("powerOff", ...)
                         -> SLEEP-Befehl über SPI
                    -> RESET/CS-Master/CS-Slave/DC auf INPUT
```

Parallel läuft `setImageFromFS()` → `setImageFromFS_13inch()` mit `epaperIsUpdating=true`, `display.epd2.init()`, `display.clearScreen()` → lazily `_InitDisplay()` → `_reset()` → `_waitWhileBusy("initReset", ...)`, danach RAM-Transfer und `Epd13::refreshFull()`.

**Die Bedingung war gerade verkehrt für diesen Zweck:** Ein aktives Displayupdate veranlasste den Timer, das Display zurückzusetzen und herunterzufahren. `epaperIsUpdating` war nur ein ungeschütztes bool, keine gegenseitige Ausschlusssperre. Auch ein atomares bool allein hätte die Hardwareaufrufe nicht serialisiert.

Quellbelege: `src/main.cpp` (V5-Funktionen recheckAccOrient/checkOrientationInBackground), `src/epaper_display.cpp` (deinitDisplay), gepinnte GxEPD2-Version `ffb2031f90220cd4a88de682d6c509103e27935c`, dort `src/epd7c/GxEPD2_1330c_EL133UF3.cpp:553` powerOff, `:561` hibernate, `:728` _InitDisplay, sowie `src/GxEPD2_EPD.cpp:135` _waitWhileBusy. Die installierte Arduino-Ticker-Implementierung `/home/dev/.platformio/packages/framework-arduinoespressif32/libraries/Ticker/src/Ticker.cpp:37` setzt `dispatch_method = ESP_TIMER_TASK`.

`powerOff : 6` ist die von `_waitWhileBusy` ausgegebene **Wartezeit in Mikrosekunden**, weder Fehlernummer noch 6 ms. Die Zeile belegt einen ausgeführten Treiber-Power-off-Pfad. Dieser sendet Panel-POF und anschließend hibernate/SLEEP; er schaltet im ACC-Pfad nicht zusätzlich den externen DISP_POWER-GPIO. Versorgungskommandos im Panel, RESET, CS-Pins und gemeinsamer SPI-Bus werden dennoch unmittelbar verändert. `displaySetRotation` verändert die gemeinsamen Software-Rotationsparameter; systemData und EEPROM werden ebenfalls verändert. Der Timer verändert nicht direkt die SPI-Taktkonfiguration, greift aber mit dem Treiber auf dieselbe SPI-Instanz zu.

Damit ist die Software-Race anhand der Aufrufpfade bewiesen. Die beobachtete Reihenfolge ist genau mit diesem Pfad vereinbar. Eine vollständige RAM-Bytezählung beweist anschließend nur die ausgeführten Schreibaufrufe, nicht die Annahme der Daten durch ein inzwischen zurückgesetztes/schlafendes Panel. Die Ursache erklärt den ausbleibenden BUSY-Start nach DRF. Welcher einzelne elektrische Teil (Reset, POF, SLEEP oder auf INPUT gesetzte Pins) im konkreten Lauf ausschlaggebend war, ist ohne Hardwaretrace nicht getrennt bewiesen. Weitere elektrische Fehlerursachen werden damit nicht ausgeschlossen.

## Exakte V6-Synchronisierung

Neue Dateien: `src/display_sync.h`, `src/display_sync.cpp`. Ein gemeinsamer rekursiver Mutex nutzt auf dem ESP32 `xSemaphoreCreateRecursiveMutex`/Take/Give; das Hostmodell verwendet `std::recursive_mutex`. `DisplayGuard` schützt den gesamten Funktionsbereich. Die Sperre ist taskbasiert und bleibt auch während delay/yield bestehen; Interrupts bleiben aktiv. Rekursion erlaubt geschützten übergeordneten Funktionen, dieselben geschützten Hilfsfunktionen zu verwenden.

1. **ACC-Timer:** `recheckAccOrient()` liest ausschließlich das atomare Stop-Flag und setzt eine atomare Prüfanforderung (`RotationRequests`). Keine I2C-Messung, kein EEPROM-Schreiben, keine Orientierungsmutation und keinerlei Display-/Reset-/SPI-Aufruf. Mehrere Ticks werden zu einer Prüfung zusammengefasst. Es wird keine historische Folge von Zwischenorientierungen abgespielt.
2. **Orientierungsdienst:** `serviceOrientation()` läuft unter derselben Ressourcensperre im aufrufenden Task. Während `epaperIsUpdating` wahr ist, bleibt die Anfrage unangetastet. Sonst wird bei aktivierter Auto-Rotation gemessen. Nach Verlassen des IMU-Standby wartet `accInit()` 180 ms auf einen neuen 6,25-Hz-Messwert; zwei aufeinanderfolgende gültige, gleiche Orientierungen qualifizieren die Übernahme. Bei unterschiedlichen/fehlerhaften Messungen bleibt die letzte stabile Orientierung erhalten, eine weitere Prüfung wird vorgemerkt. Ein Registerlesefehler liefert jetzt -1 statt einer vermeintlichen Orientierung 0. Die bisherige Achsenzuordnung einschließlich flach liegendem Gerät bleibt erhalten.
3. **Snapshot:** `setImageFromFS_13inch()` erwirbt die Sperre vor allen Initialisierungs-/SPI-Aufrufen. `DisplayFrame` erwirbt sie zusätzlich rekursiv vor seinem Prepare-Callback. Prepare ruft `serviceOrientation(true)`, setzt den atomaren Aktivstatus und kopiert `rotationPicture` in das unveränderliche `frame.orientation`. Genau dieser Wert steuert beide Controllerhälften. Bei anhaltender Bewegung wird die letzte stabile Orientierung eingefroren; es gibt keine unbegrenzte Wartephase auf Stillstand.
4. **Geschützte Phase:** Stromversorgung einschalten, Datei prüfen, Standardinitialisierung/Reset, RAM-Prefill, Master-RAM, Slave-RAM, Full Window, PON, DRF, qualifiziertes BUSY-Ende, POF und dessen qualifiziertes Ende liegen vollständig unter derselben Sperre. Die Orientierung kann dabei weder durch den ACC-Ticker noch einen anderen geschützten Einstieg geändert werden.
5. **Abschluss:** Der Frame-Destruktor schließt/invalidiert den Dateihandle, setzt beide CS high und RESET low und schaltet die externe Displayversorgung ab. Erst anschließend setzt er den Aktivstatus zurück und ruft `serviceOrientation(true)` zur Übernahme der jetzt stabilen Orientierung. Erst danach wird die Sperre freigegeben. Das gilt sowohl nach erfolgreichem POF als auch nach jedem Fehler innerhalb der begonnenen Session.
6. **Andere Einstiegspunkte:** Displayinitialisierung, Typprüfung, deinit/hibernate, Text/Wipe/TurnOn, Rotation, Refreshoptionen, Overlays und Displaydaten verwenden ebenfalls die Sperre. `powerSupplyDisplay`, Sleep einschließlich Pin-Deinitialisierung, der asynchrone Textdisplay-Ticker, Failsafe-Sleep, Reset, SD-Zugriffe und HTTP-Bildverarbeitung sind serialisiert. Der BLE-onWrite-Einstieg verwendet dieselbe Sperre: Er kann während eines Frames weder den gemeinsamen SerialFlash-SPI benutzen noch Einstellungen ändern. Die globale SPI-Konfiguration erfolgt im seriellen setup vor Start des Bildpfads. In main gibt es keinen direkten ungeschützten `display.hibernate()` mehr. IMU-Initialisierung und Interruptkonfiguration verwenden ebenfalls die Sperre.
7. **Auto-Rotation bleibt aktiv:** Der Dienst wird im normalen loop, im Setup-/BLE-Loop sowie zwingend vor/nach jedem V6-Bild aufgerufen. Während langer Downloads/Frames werden Prüfungen zusammengefasst. Die nachträgliche Orientierung gilt für folgende Darstellungen; der bereits laufende Frame wird nicht neu gestartet oder teilweise gedreht. `autoRotation=false` wird beachtet.

Eine Pause/Detach des Tickers allein wäre wegen einer bereits laufenden Callback-Ausführung nicht ausreichend gewesen. In V6 ist selbst ein gerade laufender ACC-Callback hardwarefrei. Atomare Anforderungen gehen beim gleichzeitigen exchange/store nicht durch einen nichtatomaren Read/Write verloren; ein späterer Tick bleibt für die nächste Prüfung erhalten.

### Genau ein Fehler-Cleanup

`DisplayFrame::finish()` ist idempotent; ein zweiter finish-Aufruf und der Destruktor führen den Completion-Callback nicht erneut aus. Es gibt keine ACC-getriebene deinit-/powerOff-Konkurrenz mehr.

- Erfolg: unveränderter Refresh-Helfer sendet genau einen POF nach stabilem BUSY-Ende, wartet auf POF-idle; anschließend einmal externer Rail-Cutoff.
- Fehler vor POF (Initialisierung, Lesen, RAM, PON, DRF): kein zusätzlicher Treiber-Power-off mit unbekanntem BUSY-Zustand; genau ein Abschluss mit RESET low und physischem Rail-Cutoff.
- Fehler nach gesendetem POF (POF-Timeout/unstabil): kein zweiter POF; derselbe einmalige Rail-Cutoff.
- `needsHibernate=false` verhindert danach den erneuten Treiber-Power-off im Sleep-Pfad. `powerSupplyDisplay(false)` ist nach erfolgter Abschaltung idempotent; die erste Initialisierung des Versorgungspins beim Boot wird trotzdem ausgeführt. `waitDisplayComplete` wartet nach dem abgeschlossenen V6-Cleanup nicht mehr auf einen stromlosen BUSY-Pin.
- Fehler vor Eintritt in die Session, etwa fehlende Storage-Voraussetzungen im Wrapper, haben noch keine V6-Hardwarephase gestartet; deren vorhandener übergeordneter Sleep-Pfad bleibt zuständig.

Die interne 13-Zoll-Option `doRefresh=false` darf keine ungeschützte RAM-Session hinterlassen und wird jetzt protokolliert als vollständiger Refresh abgeschlossen. Im aktuellen Quellcode existiert kein Aufrufer mit explizitem false. Ein zukünftiger RAM-only-Workflow müsste eine eigene über mehrere Aufrufe gehaltene Session erhalten.

## Erhaltene Eigenschaften

`src/epaper_13inch_transfer.h` ist **bytegleich zum V5-Stand**. Damit sind 10 MHz, beide Controller mit je 480000 Bildbytes, insgesamt 960000 Bildbytes, Nibble-/Pixeltransformation, Full Window und PON/DRF/POF-Sequenz unverändert. BUSY-Aktivierung bleibt 5 ms stabil innerhalb von **2000 ms**, Idle bleibt 20 ms stabil innerhalb von 120000 ms. Keine Timeout-Erhöhung und keine optische Mindestdauer ergänzt. Das bestehende getColor-Mapping ist unverändert und weiterhin über die Pixeltests geprüft.

Storage Slot V3, Formatvalidierung, Reservierung 983040 Bytes, Wiederverwendung und Recovery bleiben unverändert. SHA256-Vergleich gegen `artifacts/final-hardware-source-hashes.json` bestätigt bytegleiche Dateien: image_storage.cpp/.h, image_format.h, types.h, epaper_13inch_transfer.h und platformio.ini. Ergebnisse und sämtliche aktuellen Source-Hashes stehen in `artifacts/display-v6-provenance.json`.

## Deterministische Tests und Build

Ausgeführt: `./tests/run_host_tests.sh`, C++17, `-Wall -Wextra -Werror`, UndefinedBehaviorSanitizer; Rotationstest zusätzlich `-pthread`. Vollständiges Log: `artifacts/display-v6-tests.log`.

| Test | Nachweis |
| --- | --- |
| Orientierungswechsel bei Initialisierung | Anfrage zwischen Snapshot und RAM; Snapshot bleibt erhalten; anderer Thread kann Mutex nicht erwerben |
| Wechsel während Master-Transfer | Einspeisung direkt am Produktions-writeFrame-RAM-Kommando; keine Ressourcenübernahme |
| Wechsel während Slave-Transfer | Dasselbe für zweite Controllerhälfte; unveränderte Orientierung bis Abschluss |
| Wechsel bei DRF und während BUSY | Einspeisung am DRF-Kommando bzw. in pause während Produktions-refreshFull; keine Übernahme vor Abschluss |
| Wechsel während POF | Anfrage bleibt zurückgestellt bis POF abgeschlossen und Completion läuft |
| Nach POF | Orientierung genau einmal übernommen; Ressourcensperre anschließend für anderen Thread verfügbar |
| Fehler | NoBusy, StuckRefresh, StuckPowerOn, StuckPowerOff, UnstablePowerOff; Cleanup genau einmal, POF höchstens einmal, Übernahme erst im Cleanup |
| Früher Fehler | Rückkehr vor RAM sowie Lesefehler an unterschiedlichen Transferfortschritten: Destruktor-Cleanup genau einmal, kein DRF |
| Wiederholungen | 8 wechselnde Orientierungszyklen × 6 Phasen; 48 erfolgreiche Sessions, dazu 9 Fehlerfälle = 57 Sessionfälle |
| Tatsächlicher ACC-Code | recheckAccOrient und serviceOrientation werden aus main.cpp extrahiert und kompiliert: Timer ohne Messung/NVS; keine Verarbeitung während active; Übernahme nach Freigabe; unstabile Messung mit späterem Retry; Auto-Rotation aus; gestoppter Ticker |
| Integration | Quellassertionen: Session vor init, Snapshot im Transfer, Cleanup/Cutoff gesetzt, kein direkter main-hibernate und keine Hardware im Timer |
| V5/Storage-Regressionen | 23 Displayfälle, 294 Storage-/Formatfälle, 24 Produktions-HTTP-Downloads, exaktes Legacy-tmp.gz-Layout und frühere Whitelist-Ablehnung bestanden |

Die konkurrierenden Thread-Prüfungen sind deterministisch: Während der Hauptthread die tatsächliche Host-Mutex-Implementierung hält, versucht der andere Thread try_lock und wird per join abgeschlossen. Kein timingabhängiges sleep zum Erraten eines Rennfensters. Transfer/BUSY-Prüfungen verwenden die unveränderten Produktions-Templates; Hardware-Pins, FreeRTOS-Scheduling, tatsächliche I2C-Werte und optisches Ergebnis bleiben simuliert. Die GPIO-Cleanup-Lambda wird durch Codeprüfung/Integration geprüft; die Exactly-once-Garantie wird an dem tatsächlich verwendeten DisplayFrame getestet.

Build: `/tmp/openpaper-pio-venv/bin/pio run -e ESP32-C6-DevKitM-1`, erfolgreich. Log: `artifacts/firmware-display-v6-build.log`. RAM 173456/327680 Bytes, Flash-Programmnutzung 1700872/1900544 Bytes. Lokales esptool image-info bestätigt ESP32-C6 und gültiges Image; Log `artifacts/display-v6-image-info.txt`. Dafür wurde ausschließlich die lokale Binärdatei gelesen, kein Port geöffnet. `git diff --check` bestanden.

## Artefakte

- Firmware: `artifacts/firmware.bin`
- Firmwaregröße: **1756704 Bytes**
- Firmware-SHA256: **cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78**
- Windows-ZIP: `artifacts/openpaper-l-display-v6-windows.zip`
- Paketverzeichnis: `artifacts/display-v6-windows/`
- ZIP-Prüfsumme: `artifacts/openpaper-l-display-v6-windows.zip.sha256`
- Verifikation: `artifacts/display-v6-artifact-verification.json`

Das Paket enthält firmware.bin, bootloader.bin, partitions.bin, boot_app0.bin, das nur manuell auszuführende flash-windows.cmd, diesen Bericht, Build-/Test-/Image-Info-Logs, Provenienz und SHA256SUMS. Firmware im ZIP, Paketverzeichnis, Buildverzeichnis und artifacts/firmware.bin wird byteweise verglichen. Alle Paketdateien werden gegen SHA256SUMS geprüft. Das CMD wurde nicht ausgeführt; COM5 bleibt ein vom Nutzer anzupassender Platzhalter. Die bisherigen V5-ZIPs bleiben historische Artefakte. Der ZIP-Hash wird außerhalb des ZIP geführt, damit keine zirkuläre Selbstprüfsumme entsteht; das Repository-Exemplar dieses Berichts erhält nach Verpackung einen entsprechenden Anhang.

## Restrisiken

- Drei physische V6-Läufe bestanden, einschließlich nachgestellter Orientierungsübernahme. Software-Ausschluss und diese Wiederholungen bestätigen die Behebung im geprüften Ablauf; Versorgungseinbrüche, Signalqualität und weitere Temperatur-/Langzeitbedingungen sind damit nicht vermessen.
- Zwei gleiche Samples sind eine begrenzte Stabilitätsqualifikation, keine Garantie völligen Stillstands. Während anhaltender Bewegung gilt die letzte stabile Orientierung; ein flach liegendes Gerät fällt wie bisher auf Orientierung 0 zurück. Zwischenbewegungen während eines Frames werden absichtlich nicht nachgespielt.
- Nach fehlerhaftem/gestörtem Refresh kann ein Teilbild stehen bleiben. Der physische Rail-Cutoff beendet den unsicheren Zustand; optische Wiederherstellung erfordert den nächsten erfolgreichen vollständigen Refresh. Die konkrete Entladung/Backpower-Situation der Hardware wurde nicht gemessen.
- Der Mutex ist eine Softwarevereinbarung: Künftige direkte Treiber-/SPI-/Pinzugriffe müssen ebenfalls darunter liegen. Direkter Hardwarezugriff aus Interrupts ist damit nicht erlaubt. Die aktuelle Callsite-Prüfung fand den ACC-Timer, Async-Display, Sleep/Failsafe und BLE als relevante konkurrierende Wege und schützt sie.
- BLE-Schreibcallbacks und Failsafe-Sleep können bis zum Ende einer Displayphase warten. Dadurch können BLE-Client-Timeouts auftreten; der Failsafe darf keine laufende Panelphase mehr abbrechen. Die bestehenden Panel-Timeouts bleiben wirksam, bei einem echten dauerhaft hängenden Besitzer ist der Mutex selbst kein Watchdog.
- Der Sensor-Dienst kostet außerhalb der kritischen Bildphase etwa 360 ms pro Doppelprobe. Keine Messung von Energieverbrauch oder Wake-Gesamtdauer. 7-Zoll- und alternative Text-/Quick-Refresh-Hardwarepfade wurden nicht physisch geprüft.

## Ergänzender physischer Wiederholungstest – erweiterte Matrix

Die drei oben dokumentierten Nutzerläufe sind bestanden. Die folgende darüber hinausgehende 12-Läufe-/Bewegungsmatrix bleibt ein ergänzender Testplan, kein behauptetes Testergebnis. Es fand hier ausdrücklich kein Kontakt zum Gerät statt.

1. V6-ZIP entpacken und Firmware-SHA256 prüfen. Installation nur manuell durch den Nutzer; vorhandenen Slot/NVS nicht löschen. Vollständiges Start-/Update-/Sleep-Log sichern.
2. Mindestens **12 vollständige Updates** mit wechselnder stabiler Anfangsorientierung 0/1/2/3 durchführen, darunter genau die V5-Konstellation flach (X≈0 Y≈0 Z≈10) → aufgestellt (Y>5). Ein Kontrolllauf bleibt während des gesamten Frames unbewegt.
3. Bewegungen über die Wiederholungen verteilen: während Initialisierung, vor Master-complete, zwischen Master- und Slave-complete, unmittelbar bei PANEL REFRESH BEGIN sowie während BUSY. Position anschließend bis nach Cleanup stabil halten. Keine absichtliche Unterbrechung der Versorgung/BUSY-Leitung durchführen; elektrische Fehler wurden im Hostmodell geprüft.
4. Vor Hardwareinitialisierung `V6 orientation frozen rotation=...` erwarten. Zwischen dieser Zeile und `V6 cleanup complete; orientation released` darf keine ACC-Übernahme, kein fremdes init/deinit/powerOff und kein erneuter Versorgungswechsel erscheinen. Beide RAM-complete-Zeilen müssen je 480000 Bytes melden.
5. Je erfolgreichem Lauf: genau ein PANEL REFRESH BEGIN, END mit busy_seen=1/busy_idle=1 und idle_stable_ms=20, anschließend POF complete, dann V6 cleanup complete, schließlich download=0 display=0. elapsed_ms nur protokollieren, nicht gegen eine künstliche Mindestdauer prüfen. Kein nachgelagertes zweites Treiber-powerOff im normalen Sleep erwarten.
6. Eine bis zum Ende gehaltene neue Orientierung muss erst nach POF/Cleanup in `[ACC] Update Orient to Mem` erscheinen, sofern sie sich vom gespeicherten Wert unterscheidet. Der laufende Frame bleibt vollständig in seiner eingefrorenen Orientierung; der nächste Frame nutzt die neue stabile Lage. Wenn die Bewegung vor Abschluss zurückgenommen wurde, ist kein historisches Nachdrehen zu erwarten.
7. Zwischen six-colors.bmp und current.bmp wechseln, sichtbare vollständige Darstellung und richtige Orientierung nach jedem Lauf fotografieren. Slot REUSE, Reservierung 983040 und Readback-Erfolg weiter prüfen; keine neue Slot-Allokation pro Update.
8. Für jeden Lauf festhalten: Startlage, Bewegungsphase/Ziellage, frozen-Rotation, Master/Slave, DRF-END, elapsed_ms, POF, Cleanup-Anzahl, spätere ACC-Übernahme, download/display-Status, Bildbeobachtung. Bei Fehler vollständiges Log behalten. Ein fehlerhafter Frame darf keine konkurrierenden powerOffs zeigen; nächster regulärer Updateversuch muss wieder vollständig initialisieren.

V6 ist durch die drei oben dokumentierten Wiederholungen physisch bestätigt. Die erweiterte Matrix dient zusätzlicher Robustheitsprüfung. Die historischen V5-Ergebnisse bleiben genau ein erfolgreicher und ein fehlgeschlagener Nutzerlauf.

## Abschließende ZIP-Verifikation

ZIP-Größe: **1104327 Bytes**.

ZIP-SHA256: **4cfa7ea19e9af824ea4590fde1f44e744701635eda742a9aa9a982b0ed23102c**.

Bytevergleich ZIP-Firmware = Paket-Firmware = Build-Firmware = artifacts/firmware.bin: **bestanden**. ZIP-CRC und sämtliche SHA256SUMS-Einträge: **bestanden**. Details: `artifacts/display-v6-artifact-verification.json`. Dieser nach dem Packen ergänzte Anhang ist im Repository-Bericht enthalten; das ZIP enthält den vollständigen Bericht bis einschließlich physischem Testplan, ohne diesen selbstreferenziellen Archiv-Anhang.

## Dokumentationsstand nach physischer Abnahme

Das bestehende V6-ZIP wurde nach der physischen Abnahme nicht neu gepackt: Es identifiziert unverändert die geprüfte Firmware und enthält den damaligen Bericht vor Hardwarefreigabe. Maßgeblich für die nachgetragenen physischen Ergebnisse sind dieser Repository-Bericht und FINAL_HARDWARE_VALIDATION.md.
