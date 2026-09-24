# GitHub-Fork-Veröffentlichung des geprüften V6-Stands

Stand: 25.09.2026. Ausschließlich GitHub-/Git-Veröffentlichung und dieser Bericht; der physisch geprüfte Quellcode, die Tests und die Firmwareartefakte wurden nicht verändert.

## Ziel und Identität

- GitHub-Benutzer: **Hengsto**, über gh auth status und die API für die verwendete gespeicherte CLI-Anmeldung bestätigt.
- Fork: https://github.com/Hengsto/paperlesspaper-firmware-offline
- Branch: https://github.com/Hengsto/paperlesspaper-firmware-offline/tree/fix/openpaper-l-storage-display-reliability
- Feature-Branch: `fix/openpaper-l-storage-display-reliability`.
- Fork-Elternrepository über GitHub geprüft: `paperlesspaper/paperlesspaper-firmware-offline`, isFork=true.

Der Fork wurde mit `gh repo view Hengsto/paperlesspaper-firmware-offline` geprüft und nach dessen Nichtvorhandensein mit `gh repo fork paperlesspaper/paperlesspaper-firmware-offline --clone=false --remote=false` erstellt. Der aktive Umgebungstoken verweigerte zunächst die Fork-Erstellung mit HTTP 403. Daraufhin wurde die bereits gespeicherte CLI-Anmeldung verwendet, nach gesonderter Bestätigung derselben Identität Hengsto. Es wurden keine Tokenwerte in Dateien übernommen.

## Remotes und Transport

Der falsche lokale origin wurde ersetzt. Dauerhaft gespeicherte Remotes:

```text
origin	git@github.com:Hengsto/paperlesspaper-firmware-offline.git (fetch)
origin	git@github.com:Hengsto/paperlesspaper-firmware-offline.git (push)
upstream	git@github.com:paperlesspaper/paperlesspaper-firmware-offline.git (fetch)
upstream	git@github.com:paperlesspaper/paperlesspaper-firmware-offline.git (push)
```

SSH auf Port 22 antwortete nicht; SSH über Port 443 wurde mangels akzeptiertem öffentlichen Schlüssel abgewiesen. Fetch und Push erfolgten deshalb mit einer ausschließlich für den jeweiligen Prozess geltenden HTTPS-Umschreibung und dem gh-Credential-Helper. Die Remote-Adressen wurden dabei nicht verändert. Die vorhandene CLI-Anmeldung gehört Hengsto; der übersteuernde Umgebungstoken wurde für diese Aufrufe aus der Prozessumgebung entfernt. Es wurden weder Sicherheitsprüfungen deaktiviert noch Schlüssel hinzugefügt.

Ausgeführte Git-Operationen: fetch upstream --prune, fetch origin --prune, Branch-Neuanlage vom geprüften HEAD und ausschließlich `push -u origin fix/openpaper-l-storage-display-reliability`. Kein Reset, kein Rebase, kein Merge neuer Upstream-Änderungen, kein Force-Push. Die inzwischen neuere Upstream-main-Version wurde nicht mit dem geprüften Stand vermischt.

## Veröffentlichte Commits

| Commit | Inhalt |
| --- | --- |
| cb43c446b8779395d2b1dd613eacf19a903720b6 | Geprüfter V6-Implementierungsstand einschließlich Storage V3, Display, Synchronisierung, Tests und Berichten |
| cf27607643c4134b1eebfe9d48f33b5c5037c0bd | Abschließende Hardwarevalidierung und Implementierungsnachweis |
| **875afa21131acc27f73757a2aadfdc3b9af233bb** | **Fix OpenPaper L storage and display reliability** |

Der verlangte Veröffentlichungscommit ist bewusst ein Commit ohne Dateiänderung: Der gesamte geprüfte Stand war bereits in den beiden vorherigen Commits gespeichert. Deren Historie bleibt erhalten. Der Tree-Hash des Veröffentlichungscommits wurde gegen cf27607 geprüft und ist identisch. Es wurde nichts verworfen oder nachträglich am geprüften Code verändert.

Dieser Bericht wird anschließend separat als einzige neue Datei committed und auf denselben Feature-Branch gepusht. Seine eigene Commit-ID ist über `git log -1 --format=%H -- FORK_PUBLICATION_REPORT.md` abrufbar; die abschließende Ausgabe nennt den endgültigen Branch-HEAD. Ein Commit kann seinen eigenen vollständigen Hash nicht im eigenen Inhalt festhalten.

## Vollständige beabsichtigte V6-Dateiliste

Gegenüber der ursprünglichen Basis 0961aa69ffeddfe505f7a2bb4b7c45f49308b2d6 sind folgende 29 Dateien enthalten. Die Liste wurde vor dem Veröffentlichungscommit vollständig angezeigt:

```text
.gitignore
DISPLAY_ANALYSIS.md
DISPLAY_REFRESH_TIMING_FIX.md
DISPLAY_ROTATION_RACE_FIX.md
FINAL_HARDWARE_VALIDATION.md
STORAGE_FIX.md
lib/SerialFlash/LOCAL_PATCHES.md
lib/SerialFlash/SerialFlash.h
lib/SerialFlash/SerialFlashChip.cpp
lib/SerialFlash/SerialFlashDirectory.cpp
lib/SerialFlash/library.json
lib/SerialFlash/util/SerialFlash_directwrite.h
platformio.ini
src/display_sync.cpp
src/display_sync.h
src/epaper_13inch_transfer.h
src/epaper_display.cpp
src/epaper_display.h
src/image_format.h
src/image_storage.cpp
src/image_storage.h
src/main.cpp
tests/host/Arduino.h
tests/host/SPI.h
tests/host/display_test.cpp
tests/host/download_test.cpp
tests/host/rotation_test.cpp
tests/host/storage_test.cpp
tests/run_host_tests.sh
```

Zusätzlich wird ausschließlich `FORK_PUBLICATION_REPORT.md` im Dokumentationscommit ergänzt. Vor dessen Commit wird diese Datei gesondert auf Secret-Verdachtsstellen, Binärinhalt und unbeabsichtigte Änderungen geprüft.

## Automatische Prüfung und bewusste Ausschlüsse

Geprüft wurden alle 53 versionierten Dateien des ursprünglichen geprüften HEAD sowie die vollständigen Trees der beiden lokalen V6-Commits. Prüfungen: ausgeschlossene Pfade/Dateiendungen, NUL-/Nicht-UTF8-Binärinhalt, private Schlüssel, GitHub-/AWS-/API-Tokenmuster, Zugangsdaten in URLs und verdächtige feste Passwort-/SSID-/Tokenzuweisungen. Ergebnis: **keine Verdachtsstellen**. Zusätzlich erfolgte die Sichtprüfung der geplanten Dateiliste. Das ersetzt keine allgemeine Garantie gegen jedes denkbare Secretformat; es gab keinen festgestellten Befund, der einen Stopp erforderte.

Nicht aufgenommen und nicht hochgeladen: artifacts/, firmware.bin, Firmware-ZIPs, .pio/, Cloud-Firmware-Backups, Flash-/NVS-/SPIFFS-Dumps, Zertifikate/Schlüssel, WLAN-Zugangsdaten, .env, temporäre Dateien und lokale Buildumgebungen. Bereits im öffentlichen Ausgangsrepository enthaltene Beispielkonfigurationen enthalten keine neu eingefügten persönlichen Zugangsdaten. Die Firmware und ihr ZIP bleiben lokale Artefakte. Auch die technischen Validierungsberichte enthalten keine gefundenen Secrets.

## Push-Nachweis

Nach dem ersten Push:

```text
lokaler HEAD: 875afa21131acc27f73757a2aadfdc3b9af233bb
origin refs/heads/fix/openpaper-l-storage-display-reliability:
875afa21131acc27f73757a2aadfdc3b9af233bb
```

`git status --short --branch`:

```text
## fix/openpaper-l-storage-display-reliability...origin/fix/openpaper-l-storage-display-reliability
```

Keine geänderten oder unversionierten Dateien in der Statusausgabe; Branch synchron. `git show --stat --oneline HEAD` bestätigte den benannten Veröffentlichungscommit ohne Tree-Änderung. `git ls-tree -r --name-only HEAD` wurde vollständig geprüft; Ausgabe vor dem zusätzlichen Bericht:

```text
.clang-format
.github/workflows/deploy.yml
.gitignore
DISPLAY_ANALYSIS.md
DISPLAY_REFRESH_TIMING_FIX.md
DISPLAY_ROTATION_RACE_FIX.md
FINAL_HARDWARE_VALIDATION.md
README.md
STORAGE_FIX.md
copilot-instructions.md
deploy/platformio.ini
lib/SerialFlash/LOCAL_PATCHES.md
lib/SerialFlash/SerialFlash.h
lib/SerialFlash/SerialFlashChip.cpp
lib/SerialFlash/SerialFlashDirectory.cpp
lib/SerialFlash/library.json
lib/SerialFlash/util/SerialFlash_directwrite.h
part.csv
platformio.ini
profiler/.gitignore
profiler/index.html
profiler/main.js
profiler/package-lock.json
profiler/package.json
profiler/style.css
set_env.py
settings_sample.json
src/display_sync.cpp
src/display_sync.h
src/epaper_13inch_transfer.h
src/epaper_display.cpp
src/epaper_display.h
src/image_format.h
src/image_storage.cpp
src/image_storage.h
src/main.cpp
src/types.h
tests/host/Arduino.h
tests/host/SPI.h
tests/host/display_test.cpp
tests/host/download_test.cpp
tests/host/rotation_test.cpp
tests/host/storage_test.cpp
tests/run_host_tests.sh
web/.prettierrc
web/package-lock.json
web/package.json
web/src/DeviceBleInterface.js
web/src/GeneratePicture.js
web/src/app.js
web/src/index.html
web/src/profiles/new.json
web/vite.config.js
```

origin/main und upstream/main wurden vor und nach dem Push geprüft und stehen beide unverändert auf `4e4ddf711b4fec6ac4004ccaba397dc161458563`. Nach dem separaten Berichts-Push werden lokaler und Remote-HEAD erneut verglichen, Status, Remotes, git show und der vollständige Tree erneut geprüft. Die einzige zusätzliche Datei ist dieser Bericht.

**Es wurde nichts zu upstream oder main gepusht. Kein Pull Request, keine GitHub Release und kein Firmware-Upload wurden erstellt.** Die automatisch von GitHub ausgegebene PR-Vorschlags-URL wurde nicht zur Erstellung eines PR verwendet.

## Verhältnis zur Hardwarevalidierung

FINAL_HARDWARE_VALIDATION.md und die übrigen technischen Berichte bleiben unverändert als Nachweis des damals lokal geprüften Stands erhalten. Deren damalige Aussagen über einen lokalen Remote und „kein Push“ beschreiben den Zeitpunkt vor dieser Veröffentlichung; für den Veröffentlichungsstatus ist dieser Bericht maßgeblich. Die physisch bestätigte Firmware bleibt 1756704 Bytes groß, SHA256 `cadcd51ae38bfd0ec6d8d413e836aa4ad0aafae76d6a484a6b1044c045b2aa78`. Wegen ausschließlich Git-/Dokumentationsänderungen wurde keine neue Firmware gebaut oder geflasht.
