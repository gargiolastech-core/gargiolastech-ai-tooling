# gargiolastech-ai-tooling

Piattaforma DevEx per la gestione centralizzata dei segreti AI a runtime su workstation Windows — integrazione con **Continue.dev**, **Aider** e **JetBrains Rider** tramite **Infisical** e **Machine Identity**.

> 📖 **Documentazione tecnica completa:** [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md)

---

## Panoramica

Questo repository fornisce lo scaffolding operativo per avviare JetBrains Rider in un contesto in cui gli strumenti AI (Continue.dev, Aider) abbiano accesso alle chiavi API senza che queste vengano mai scritte in file persistenti, committate su Git o distribuite manualmente.

I segreti vengono generati **a runtime** ad ogni avvio dell'IDE: recuperati da Infisical tramite Machine Identity, materializzati in file `.env` effimeri, iniettati come variabili d'ambiente nel processo Rider e cancellati/rigenerati alla sessione successiva.

```
Windows Credential Manager     ← Client ID + Client Secret (bootstrap, one-shot)
        ↓
    Infisical                  ← Sorgente di tutti i segreti AI
        ↓
 File .env runtime             ← Generati a ogni avvio, mai persistiti
        ↓
  Rider + Continue + Aider     ← Consumano i segreti via env vars
```

---

## Contenuto del repository

| Percorso | Descrizione |
|---|---|
| `scripts/windows/bootstrap-ai-tooling.cmd` | Wizard interattivo per il bootstrap iniziale delle credenziali in Windows Credential Manager |
| `scripts/windows/Set-InfisicalCredential.ps1` | Scrive Machine Identity Client ID e Client Secret in WCM tramite `cmdkey` |
| `scripts/windows/Start-AiRider.cmd` | Entry point per uso quotidiano: seleziona il progetto e avvia Rider con segreti AI iniettati |
| `scripts/windows/Start-AiRider.ps1` | Dispatcher multi-progetto: legge `projects.json`, valida la configurazione, delega all'engine |
| `scripts/windows/Start-Rider-With-AiSecrets.ps1` | Engine core: legge WCM, autentica con Infisical, esporta i segreti, lancia Rider |
| `scripts/windows/Install-AiRiderDesktopShortcut.ps1` | Crea collegamento desktop "Rider AI" per avvio rapido |
| `templates/projects.json.template` | Template di configurazione multi-progetto (copiato automaticamente al primo avvio) |
| `docs/DOCUMENTATION.md` | Documentazione tecnica enterprise completa |

---

## Avvio rapido

### 1. Bootstrap (una volta per workstation)

```cmd
cd scripts\windows
bootstrap-ai-tooling.cmd
```

Inserire **Client ID** e **Client Secret** della Machine Identity Infisical quando richiesto. Le credenziali vengono archiviate in Windows Credential Manager — mai su file.

### 2. Avvio quotidiano

```cmd
Start-AiRider.cmd
```

Il launcher mostra la lista dei progetti configurati e avvia Rider con i segreti AI iniettati.

### 3. Collegamento desktop (opzionale)

```powershell
.\Install-AiRiderDesktopShortcut.ps1
```

---

## Requisiti

| Requisito | Versione |
|---|---|
| Windows | 10 / 11 (64-bit) |
| Windows PowerShell | 5.1+ |
| Infisical CLI | 0.20.0+ |
| JetBrains Rider | 2024.1+ |
| Continue.dev plugin | Da JetBrains Marketplace |

Installazione Infisical CLI:

```powershell
scoop bucket add org https://github.com/Infisical/scoop-infisical.git
scoop install infisical
```

---

## Principi architetturali

- **Zero segreti nel repository** — il repo è scansionabile con GitLeaks senza alcun hit.
- **Zero file `.env` permanenti** — i segreti AI sono effimeri, rigenerati ad ogni avvio.
- **Machine Identity disaccoppiata dall'utente** — lifecycle indipendente, revoca granulare.
- **Windows Credential Manager + DPAPI** — cifratura OS-native, nessuna dipendenza esterna.
- **Single source of truth** — Infisical è autoritativo su tutti i segreti; `projects.json` è autoritativo sulla configurazione locale.

---

## Documentazione

La documentazione tecnica completa è disponibile in [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) e include:

- Architettura dettagliata con diagrammi Mermaid
- Threat model e security boundaries
- Setup tutorial completo da zero
- Spiegazione di ogni script PowerShell
- Integrazione Continue, Aider e Rider
- Procedura di rotazione delle credenziali
- Troubleshooting e FAQ

---

## Licenza

MIT — © 2026 GargiolasTech