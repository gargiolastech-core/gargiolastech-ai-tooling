# Guida operativa — Aggiungere il submodule AI Tooling a un nuovo progetto

> **Scope**: questa guida è rivolta al developer che ha già completato il setup
> della workstation (bootstrap credenziali, Install-Aider, alias PowerShell)
> e vuole abilitare il tooling AI su un **nuovo repository applicativo**.
>
> Per il setup iniziale della macchina consultare `DOCUMENTATION.md — Sezione 11`.
> Per la documentazione architetturale completa sul modello submodule consultare
> `DOCUMENTATION.md — Sezione 37`.

---

## Prerequisiti

Prima di procedere, verificare:

```powershell
# 1. Credenziali Infisical in WCM
cmdkey /list | Select-String "gargiolastech"
# Atteso: due entry (client-id, client-secret)

# 2. Aider installato
& "$HOME\.venvs\aider-env\Scripts\aider.exe" --version
# Atteso: aider x.y.z

# 3. Git disponibile
git --version
# Atteso: git version 2.x

# 4. Repo centrale clonato localmente
Test-Path "C:\dev\gargiolastech-ai-tooling\scripts\windows\Add-AiToolingSubmodule.ps1"
# Atteso: True
```

Se uno dei check fallisce, eseguire prima `DOCUMENTAZIONE.md — Sezione 11`
(setup workstation) o `Sezione 36` (reset e ripristino).

---

## Step 1 — Portarsi nella root del nuovo progetto

```powershell
cd C:\dev\mio-nuovo-progetto
```

Verificare che sia una Git repository:

```powershell
git status
# Se non è una repo: git init
```

---

## Step 2 — Eseguire Add-AiToolingSubmodule.ps1

```powershell
powershell -ExecutionPolicy Bypass -File `
    C:\dev\gargiolastech-ai-tooling\scripts\windows\Add-AiToolingSubmodule.ps1
```

Lo script esegue automaticamente:

1. Valida che la directory sia una Git repository.
2. Verifica che i template wrapper esistano in `templates/consumer-wrappers/`.
3. Esegue `git submodule add --branch main <url> gargiolastech-ai-tooling`.
4. Copia i tre thin wrapper nella root del progetto:
   - `Start-Aider.cmd` — uso quotidiano
   - `bootstrap-ai-tooling.cmd` — onboarding credenziali
   - `Install-Aider.cmd` — onboarding tool AI
5. Aggiunge tutto al git index (pronti per commit).

**Output atteso:**

```
============================================================
 Validazione
============================================================
Repo consumer  : C:\dev\mio-nuovo-progetto
Wrappers source: C:\dev\gargiolastech-ai-tooling\templates\consumer-wrappers
Repository Git : OK

============================================================
 Aggiunta submodule
============================================================
URL    : https://github.com/gargiolastech/gargiolastech-ai-tooling.git
Path   : C:\dev\mio-nuovo-progetto\gargiolastech-ai-tooling
Branch : main

Cloning into 'C:\dev\mio-nuovo-progetto\gargiolastech-ai-tooling'...

Submodule aggiunto.

============================================================
 Installazione thin wrapper
============================================================
  Start-Aider.cmd            — installato
  bootstrap-ai-tooling.cmd   — installato
  Install-Aider.cmd          — installato

============================================================
 Staging per commit
============================================================
File aggiunti al git index:
  .gitmodules
  gargiolastech-ai-tooling/ (submodule reference)
  Start-Aider.cmd
  bootstrap-ai-tooling.cmd
  Install-Aider.cmd

============================================================
 Completato
============================================================
```

---

## Step 3 — Verificare i file creati

```
mio-nuovo-progetto/
├── .gitmodules                       ← generato da git submodule add
├── gargiolastech-ai-tooling/         ← submodule (cartella)
│   ├── aider/.aider.conf.yml
│   ├── continue/config.yaml
│   └── scripts/windows/*.ps1 *.cmd
├── bootstrap-ai-tooling.cmd         ← thin wrapper
├── Install-Aider.cmd                ← thin wrapper
└── Start-Aider.cmd                  ← thin wrapper
```

```powershell
# Verifica che i file siano in staging
git status
# Atteso: Changes to be committed: .gitmodules, gargiolastech-ai-tooling,
#         Start-Aider.cmd, bootstrap-ai-tooling.cmd, Install-Aider.cmd
```

---

## Step 4 — Aggiornare .gitignore del progetto

Aggiungere al `.gitignore` del repo consumer per evitare commit accidentali
di file Aider generati localmente:

```gitignore
# Aider — file di sessione locali
.aider.chat.history.md
.aider.input.history
.aider.tags.cache.v3/

# AI tooling runtime (non serve versionare)
gargiolastech-ai-tooling/templates/consumer-wrappers/
```

> **Nota**: NON aggiungere `gargiolastech-ai-tooling/` al `.gitignore`.
> Il submodule stesso deve essere tracciato da Git.

---

## Step 5 — Committare

```powershell
git commit -m "chore: add gargiolastech-ai-tooling submodule"
```

Il commit include:
- `.gitmodules` — puntatore URL + branch del submodule
- `gargiolastech-ai-tooling` — riferimento al commit del submodule
- I tre thin wrapper

---

## Step 6 — Testare il launcher

```powershell
cd C:\dev\mio-nuovo-progetto

# Avvia Aider nella root del progetto
.\Start-Aider.cmd
```

Flusso atteso:

```
============================================================
 Aider
============================================================
Directory corrente: C:\dev\mio-nuovo-progetto

Modello : anthropic/claude-sonnet-4-20250514
Aider   : C:\Users\<utente>\.venvs\aider-env\Scripts\aider.exe

...login Infisical...

============================================================
 Generazione env runtime
============================================================

============================================================
 Avvio Aider — sessione interattiva
============================================================
Premi CTRL+C o digita /exit per terminare la sessione.
```

---

## Flusso onboarding per un collega che clona il progetto

Quando un altro developer clona il repo per la prima volta:

```powershell
# Clone con inizializzazione submodule automatica
git clone --recurse-submodules https://github.com/org/mio-nuovo-progetto.git
cd mio-nuovo-progetto

# Se clonato senza --recurse-submodules
git submodule update --init

# Onboarding completo dalla root del progetto (zero conoscenza del repo centrale)
.\bootstrap-ai-tooling.cmd     # inserisce ClientId e ClientSecret in WCM
.\Install-Aider.cmd            # crea virtualenv Python con Aider

# Uso quotidiano
.\Start-Aider.cmd
```

---

## Aggiornare il submodule a una nuova versione

Il submodule è pinnato al commit al momento dell'aggiunta. Per allinearlo
all'ultima versione del repo centrale:

```powershell
cd C:\dev\mio-nuovo-progetto

# Aggiorna all'ultimo commit del branch main
git submodule update --remote --merge

# Verifica cosa è cambiato
cd gargiolastech-ai-tooling
git log --oneline -5
cd ..

# Committa il bump di versione
git add gargiolastech-ai-tooling
git commit -m "chore: update gargiolastech-ai-tooling submodule"
```

> **Quando aggiornare**: in genere quando il repo centrale rilascia una nuova
> versione (vedi `CHANGELOG.md` nel repo centrale) che contiene fix o feature
> rilevanti per il progetto.

---

## Troubleshooting

| Sintomo | Causa | Soluzione |
|---|---|---|
| `ERRORE: submodule non inizializzato` | Clone senza `--recurse-submodules` | `git submodule update --init` |
| `gargiolastech-ai-tooling/` vuota | Come sopra | Come sopra |
| `fatal: repository not found` | URL errato o mancanza di accesso GitHub | Verificare URL in `.gitmodules` e permessi |
| `Wrappers source non trovato` in Add-AiToolingSubmodule | Il repo centrale non ha `templates/consumer-wrappers/` | Aggiornare il repo centrale |
| `ClientId non trovato nel Credential Manager` | Bootstrap non eseguito su questa macchina | `.\bootstrap-ai-tooling.cmd` |
| Submodule in stato `(modified content)` | File modificati dentro il submodule | `cd gargiolastech-ai-tooling && git checkout .` |
| Submodule in detached HEAD | Normale dopo `git submodule update` | `git submodule update --remote` se si vuole l'ultimo commit |
| `.aider.conf.yml` non copiato | `aider/` non presente nel repo centrale o submodule non aggiornato | `git submodule update --remote` poi `.\Start-Aider.cmd` |
