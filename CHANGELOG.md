# Changelog

Tutte le modifiche rilevanti a questo progetto sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).
Il versioning segue [Semantic Versioning](https://semver.org/lang/it/).

---

## [3.0.0] — 2026-05-27

### Breaking Changes

- `templates/aider/.aider.conf.yml` spostato in `aider/.aider.conf.yml` (root del repo).
- `templates/continue/config.yaml` spostato in `continue/config.yaml` (root del repo).
- Chi faceva riferimento ai vecchi path deve aggiornare eventuali script o documentazione interna.

### Added

- **`aider/` (root)**: cartella dedicata alla configurazione Aider. Contiene `.aider.conf.yml`, unica fonte di verità per la configurazione Aider condivisa tra tutti i progetti.
- **`continue/` (root)**: cartella dedicata alla configurazione Continue. Contiene `config.yaml` con i modelli AI disponibili per GargiolasTech.
- **`CHANGELOG.md`**: questo file.

### Changed

- `Start-Aider.ps1`: copia automaticamente `aider/.aider.conf.yml` nella working directory prima di avviare Aider. Se nella cwd esiste già un `.aider.conf.yml` (override locale del developer), non viene sovrascritto.
- `Start-Ide-With-AiSecrets.ps1`: copia automaticamente `continue/config.yaml` in `~/.continue/config.yaml` ad ogni avvio dell'IDE, mantenendo la configurazione Continue allineata all'ultima versione del repo.

### Removed

- `templates/aider/` (spostato a root).
- `templates/continue/` (spostato a root).

---

## [2.1.0] — 2026-05-26

### Fixed

- **CRITICO** `projects.json.template`: rimosso path utente-specifico hardcoded (`C:\Users\giuse\...`) nel campo `ides.rider.path`. Sostituito con placeholder `REPLACE_WITH_RIDER_PATH`.
- **CRITICO** `Start-AiIde.ps1`: rinominata variabile locale `$matches` → `$matchedProjects` per evitare conflitto con la variabile automatica PowerShell `$matches` (popolata dall'operatore `-match`).
- **CRITICO** `Start-Ide-With-AiSecrets.ps1`: rimossa `Import-DotEnvFile` che causava merge implicito tra namespace `/continue` e `/aider`. Segreti Continue ora scritti direttamente in `~/.continue/.env` (path di ricerca nativo di Continue per IDE extensions). Variabile `$env:CONTINUE_ENV_FILE` rimossa (non supportata dalle IDE extensions di Continue). Variabile `$env:AIDER_ENV_FILE` mantenuta come hint per terminali integrati.
- **CRITICO** `Start-Ide-With-AiSecrets.ps1`: aggiunta validazione fail-fast per `$ProjectId == "REPLACE_WITH_INFISICAL_PROJECT_ID"`.
- **SERIO** `Start-AiIde.ps1`: aggiornato messaggio di `New-DefaultConfig` — indicava `riderPath` (campo legacy v1) invece di `ides.rider.path`.
- **SERIO** `Start-AiIde.ps1`: corretta indentazione inconsistente nei blocchi `throw` della funzione di validazione.
- **SERIO** `Start-AiIde.ps1`: aggiunta validazione placeholder `REPLACE_WITH_*` per i path IDE prima di `Test-Path`.
- **SERIO** `templates/consumer-wrappers/`: rinominati i file rimuovendo il prefisso `consumer-root-`. Rimosso `consumer-root-.gitmodules` (generato automaticamente da `git submodule add`).
- **SERIO** `Add-AiToolingSubmodule.ps1`: eliminato `$WrapperTemplate` inline. Lo script ora legge i wrapper da `templates/consumer-wrappers/` (single source of truth, no drift tra template inline e file su disco).
- **SERIO** `Install-AiIdeDesktopShortcut.ps1`: aggiunta validazione esistenza `Start-AiIde.ps1` (oltre al wrapper `.cmd`) prima di creare il collegamento desktop.
- **SERIO** `Install-Aider.ps1`: aggiunto `Set-StrictMode -Version Latest` (mancava rispetto a tutti gli altri script).
- **SERIO** `Start-Aider.ps1`, `Start-Ide-With-AiSecrets.ps1`: aggiunto check `PathType Container` sulle directory runtime prima di creare file, evitando errori criptici se il path esiste come file.
- **MINORE** `bootstrap-ai-tooling.cmd`: aggiornato messaggio finale — indicava di chiamare direttamente `Start-Ide-With-AiSecrets.ps1` (engine) invece dei launcher `Start-AiIde.cmd` e `Start-Aider.cmd`.
- **MINORE** `Set-InfisicalCredential.ps1`: corretti riferimenti a script e path inesistenti nella documentazione interna (`Sync-InfisicalUserSecrets.ps1`, `infisical-sync.json`, `scripts\infisical\`). Uniformata la lingua a italiano.

### Added

- **`Reset-AiTooling.ps1`** (`scripts/windows/`): script di teardown completo. Rimuove credenziali WCM, virtualenv Aider, alias `$PROFILE`, file runtime, `~/.continue/.env`, `projects.json` (con conferma). Supporta `-Force`, `-KeepProjectsJson`, `-CredentialScope`.
- **`.gitignore`**: aggiunto al repo centrale (mancava). Esclude `runtime/`, `.aider*`, `projects.json`, `.env`, `.continue/.env`, directory IDE.

---

## [2.0.0] — 2026-05-22

### Breaking Changes

- Script rinominati da `*-AiRider*` a `*-AiIde*` per supporto multi-IDE.
- `Start-Rider-With-AiSecrets.ps1` rinominato in `Start-Ide-With-AiSecrets.ps1`.
- `projects.json`: `riderPath` (stringa root) sostituito da `ides` (dizionario) + campo `ide` per-progetto.

### Added

- Supporto multi-IDE dichiarativo via `ides` dictionary in `projects.json`.
- `Install-AiIdeDesktopShortcut.ps1`: collegamento desktop con icona dedicata.
- `images/Icona.ico` e `images/Icona.png`: asset icona launcher.
- `Start-Aider.ps1` + `Start-Aider.cmd`: launcher Aider one-shot nella directory corrente.
- `Install-Aider.ps1` + `Install-Aider.cmd`: provisioning virtualenv Python isolato `~/.venvs/aider-env`.
- `Install-PowerShellProfile.ps1` + `Uninstall-PowerShellProfile.ps1`: alias `aider-here` nel `$PROFILE` PowerShell.
- `Add-AiToolingSubmodule.ps1`: setup one-shot per aggiungere il repo come submodule in repo consumer.
- `templates/consumer-wrappers/`: thin wrapper per repo consumer (`Start-Aider.cmd`, `bootstrap-ai-tooling.cmd`, `Install-Aider.cmd`).
- Sezione `aider` in `projects.json` per configurazione modello e path eseguibile.
- `infisicalProjectId` spostato da per-progetto a campo root unico.

---

## [1.0.0] — 2026-05-15

### Added

- Release iniziale.
- `Start-AiIde.cmd` + `Start-AiIde.ps1`: launcher multi-progetto per JetBrains Rider.
- `Start-Ide-With-AiSecrets.ps1`: engine WCM → Infisical → env runtime → avvio IDE.
- `Set-InfisicalCredential.ps1` + `bootstrap-ai-tooling.cmd`: bootstrap credenziali Machine Identity in WCM.
- `projects.json.template`: schema configurazione multi-progetto.
- `docs/DOCUMENTATION.md`: documentazione tecnica enterprise.
