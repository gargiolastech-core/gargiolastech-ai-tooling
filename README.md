# gargiolastech-ai-tooling

Piattaforma DevEx per la gestione centralizzata dei segreti AI a runtime su workstation Windows — integrazione **multi-IDE** (JetBrains Rider, Visual Studio 2022, …) con **Continue.dev** e **Aider** tramite **Infisical** e **Machine Identity**.

> 📖 **Documentazione tecnica completa:** [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md)

---

## Panoramica

Questo repository fornisce lo scaffolding operativo per avviare l'IDE preferito dello sviluppatore in un contesto in cui gli strumenti AI (Continue.dev, Aider) abbiano accesso alle chiavi API senza che queste vengano mai scritte in file persistenti, committate su Git o distribuite manualmente.

I segreti vengono generati **a runtime** ad ogni avvio dell'IDE: recuperati da Infisical tramite Machine Identity, materializzati in file `.env` effimeri, iniettati come variabili d'ambiente nel processo IDE e cancellati/rigenerati alla sessione successiva. Il launcher è **IDE-agnostic**: ogni progetto dichiara quale IDE aprire, e l'engine sceglie l'eseguibile corretto dalla configurazione.

```
Windows Credential Manager     ← Client ID + Client Secret (bootstrap, one-shot)
        ↓
    Infisical                  ← Sorgente di tutti i segreti AI
        ↓
 File .env runtime             ← Generati a ogni avvio, mai persistiti
        ↓
  Rider / VS2022 / …           ← IDE selezionato per il progetto
        +
  Continue + Aider             ← Consumano i segreti via env vars
```

---

## Contenuto del repository

| Percorso | Descrizione |
|---|---|
| `scripts/windows/bootstrap-ai-tooling.cmd` | Wizard interattivo per il bootstrap iniziale delle credenziali in Windows Credential Manager |
| `scripts/windows/Set-InfisicalCredential.ps1` | Scrive Machine Identity Client ID e Client Secret in WCM tramite `cmdkey` |
| `scripts/windows/Install-Aider.cmd` | Wrapper double-clickable per `Install-Aider.ps1` |
| `scripts/windows/Install-Aider.ps1` | Provisioner: installa Aider in un virtualenv Python isolato (`~/.venvs/aider-env`) |
| `scripts/windows/Install-PowerShellProfile.ps1` | Aggiunge la funzione `aider-here` al `$PROFILE` PowerShell — alias globale per `Start-AiderHere.cmd` |
| `scripts/windows/Uninstall-PowerShellProfile.ps1` | Rimuove il blocco `aider-here` dal `$PROFILE` PowerShell |
| `scripts/windows/Start-AiIde.cmd` | Entry point per uso quotidiano: seleziona il progetto e avvia l'IDE corrispondente con i segreti AI iniettati |
| `scripts/windows/Start-AiIde.ps1` | Dispatcher multi-progetto / multi-IDE: legge `projects.json`, valida la configurazione, risolve l'IDE e delega all'engine |
| `scripts/windows/Start-Aider.cmd` | Wrapper double-clickable per `Start-Aider.ps1` |
| `scripts/windows/Start-Aider.ps1` | Avvia Aider nella **directory corrente** — nessuna selezione progetto, legge solo i campi root di `projects.json` |
| `scripts/windows/Start-Ide-With-AiSecrets.ps1` | Engine core IDE-agnostic: legge WCM, autentica con Infisical, esporta i segreti, lancia l'IDE selezionato |
| `scripts/windows/Install-AiIdeDesktopShortcut.ps1` | Crea collegamento desktop "AI IDE Launcher" con icona dedicata dal repository |
| `templates/projects.json.template` | Template di configurazione multi-progetto e multi-IDE (copiato automaticamente al primo avvio) |
| `images/Icona.ico` · `images/Icona.png` | Icona ufficiale del launcher utilizzata dal collegamento desktop |
| `docs/DOCUMENTATION.md` | Documentazione tecnica enterprise completa |

---

## Avvio rapido

### 1. Bootstrap (una volta per workstation)

```cmd
cd scripts\windows
bootstrap-ai-tooling.cmd
```

Inserire **Client ID** e **Client Secret** della Machine Identity Infisical quando richiesto. Le credenziali vengono archiviate in Windows Credential Manager — mai su file.

### 2. Installazione Aider (una volta per workstation)

```cmd
Install-Aider.cmd
```

### 2b. Alias PowerShell `aider-here` (una volta per workstation, opzionale)

```powershell
.\Install-PowerShellProfile.ps1
```

Aggiunge `aider-here` al `$PROFILE` PowerShell. Da quel momento, da qualsiasi directory in PowerShell:

```powershell
cd C:\dev\qualsiasi-repo
aider-here
```

### 3. Avvio quotidiano — IDE

```cmd
Start-AiIde.cmd
```

Il launcher mostra la lista dei progetti e avvia l'IDE associato con i segreti AI iniettati.

### 3b. Avvio Aider (da qualsiasi directory)

```cmd
cd C:\dev\qualsiasi-progetto
Start-Aider.cmd
```

**Zero interazione**: nessuna lista, nessuna selezione. Legge solo le credenziali Infisical da `projects.json` e avvia Aider nella directory corrente. Funziona su qualsiasi directory — progetti in `projects.json`, nuovi progetti, directory temporanee.

### 4. Collegamento desktop (opzionale)

```powershell
.\Install-AiIdeDesktopShortcut.ps1
```

Crea sul desktop il collegamento "AI IDE Launcher" con l'icona presente in `images/Icona.ico`.

---

## Supporto multi-IDE

A partire dalla versione corrente, ogni progetto in `projects.json` dichiara quale IDE utilizzare. Gli IDE disponibili sono definiti centralmente nella sezione `ides`:

```json
{
  "ides": {
    "rider": {
      "path": "C:\\Program Files\\JetBrains\\JetBrains Rider 2025.1\\bin\\rider64.exe"
    },
    "visualstudio": {
      "path": "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\Common7\\IDE\\devenv.exe"
    }
  },
  "projects": [
    {
      "key": "wcm",
      "name": "GargiolasTech DevEx WCM",
      "ide": "rider",
      "solutionPath": "C:\\dev\\gargiolastech-devex-wcm",
      "infisicalProjectId": "..."
    },
    {
      "key": "legacy-app",
      "name": "Legacy WPF App",
      "ide": "visualstudio",
      "solutionPath": "C:\\dev\\legacy-app",
      "infisicalProjectId": "..."
    }
  ]
}
```

Aggiungere un nuovo IDE significa aggiungere una entry alla sezione `ides` e referenziarla nel campo `ide` del progetto. Nessuna modifica di codice richiesta.

---

## Requisiti

| Requisito | Versione |
|---|---|
| Windows | 10 / 11 (64-bit) |
| Windows PowerShell | 5.1+ |
| Infisical CLI | 0.20.0+ |
| Python 3.12 (con Python Launcher `py.exe`) | per `Install-Aider.ps1` |
| IDE supportato | JetBrains Rider 2024.1+ · Visual Studio 2022 · (altri configurabili) |
| Continue.dev plugin | Da marketplace dell'IDE selezionato |

Installazione Infisical CLI:

```powershell
scoop bucket add org https://github.com/Infisical/scoop-infisical.git
scoop install infisical
```

Installazione Python (se non presente): scaricare l'installer ufficiale da [python.org](https://www.python.org/downloads/) assicurandosi di selezionare "Install launcher for all users (recommended)" e "Add Python to PATH".

---

## Principi architetturali

- **Zero segreti nel repository** — il repo è scansionabile con GitLeaks senza alcun hit.
- **Zero file `.env` permanenti** — i segreti AI sono effimeri, rigenerati ad ogni avvio.
- **IDE-agnostic by design** — l'engine non conosce Rider o Visual Studio: riceve un path eseguibile e una solution.
- **Machine Identity disaccoppiata dall'utente** — lifecycle indipendente, revoca granulare.
- **Windows Credential Manager + DPAPI** — cifratura OS-native, nessuna dipendenza esterna.
- **Single source of truth** — Infisical è autoritativo su tutti i segreti; `projects.json` è autoritativo sulla configurazione locale (progetti + IDE disponibili).

---

## Documentazione

La documentazione tecnica completa è disponibile in [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) e include:

- Architettura dettagliata con diagrammi Mermaid
- Threat model e security boundaries
- Setup tutorial completo da zero
- Spiegazione di ogni script PowerShell
- Configurazione multi-IDE (Rider, Visual Studio, estensione ad altri editor)
- Integrazione Continue e Aider
- Provisioning automatizzato di Aider in virtualenv isolato (razionale architetturale e operativo)
- Procedura di rotazione delle credenziali
- Troubleshooting e FAQ

---

## Utilizzo in altri repository (Git Submodule)

Per usare il launcher AI in qualsiasi repository applicativo senza copiare gli script, aggiungere questo repo come **Git submodule**:

```powershell
cd C:\dev\tuo-progetto

# Setup automatico: aggiunge submodule + crea i tre thin wrapper
$url = "https://raw.githubusercontent.com/gargiolastech/gargiolastech-ai-tooling/main/scripts/windows/Add-AiToolingSubmodule.ps1"
Invoke-WebRequest -Uri $url -OutFile "Add-AiToolingSubmodule.ps1"
powershell -ExecutionPolicy Bypass -File .\Add-AiToolingSubmodule.ps1
Remove-Item .\Add-AiToolingSubmodule.ps1

# Commit
git commit -m "chore: add gargiolastech-ai-tooling submodule"
```

Nella root del repo consumer vengono creati tre thin wrapper:

```
tuo-progetto/
├── bootstrap-ai-tooling.cmd   ← onboarding: credenziali WCM (one-shot)
├── Install-Aider.cmd          ← onboarding: virtualenv Aider (one-shot)
├── Start-Aider.cmd            ← uso quotidiano: Aider nella root del repo
└── gargiolastech-ai-tooling/  ← submodule
```

Flusso di onboarding per un developer che clona il repo consumer:

```powershell
git clone --recurse-submodules https://github.com/org/tuo-progetto.git
cd tuo-progetto

bootstrap-ai-tooling.cmd   # configura credenziali Infisical
Install-Aider.cmd          # installa Aider nel virtualenv
Start-Aider.cmd            # avvia Aider (da quel momento, uso quotidiano)
```

> `Start-AiIde.cmd` **non** va nel repo consumer: l'IDE si avvia dal collegamento desktop del repo centrale.

Per la documentazione completa sul modello di distribuzione vedi [`docs/DOCUMENTATION.md — Sezione 35`](docs/DOCUMENTATION.md#35-distribuzione-via-git-submodule).

---

## Licenza

MIT — © 2026 GargiolasTech
