# pytorchia_home
### home of pytorchia tools

---

### 📁 **Struttura della repo `pytorchia_home`**

```
pytorchia_home/
├── install.sh              ← home principale (eseguibile post-clone o via wget/curl)
├── embl_bash.sh            ← Funzione `br_flag()` e simili
├── emblflag                ← ASCII art grande
├── emblsmall               ← ASCII art piccola
├── README.md               ← Istruzioni d’uso
└── .pytorchia/             ← (opzionale) contenuti prestrutturati
```

---

### ✅ **install.sh** (contenuto semplificato con download auto)

```bash
#!/bin/bash
set -e

REPO_URL="https://github.com/fgirolami29/pytorchia_home"
INSTALL_DIR="$HOME/.pytorchia"
RAW_URL="https://raw.githubusercontent.com/fgirolami29/pytorchia_home/main"

echo -e "📦 Installazione PyTorchia home da repo ufficiale..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Scarica i file essenziali
for file in embl_bash.sh emblflag emblsmall; do
    echo "⬇️  Download $file..."
    curl -sSfL "$RAW_URL/$file" -o "$file"
    chmod +x "$file"
done

# Setup in .bashrc/.zshrc
for rc in .bashrc .zshrc; do
    file="$HOME/$rc"
    [[ -f "$file" ]] || touch "$file"

    grep -q 'TORCHIA_HOME=' "$file" || echo "export TORCHIA_HOME=\"$INSTALL_DIR\"" >> "$file"
    grep -q 'source "$TORCHIA_HOME/embl_bash.sh"' "$file" || echo '[[ $- == *i* ]] && source "$TORCHIA_HOME/embl_bash.sh"' >> "$file"
done

echo -e "\n✅ Installazione completata. Riavvia il terminale o esegui:"
echo -e "   source ~/.bashrc  oppure  source ~/.zshrc"
```

---

### 🚀 **Esecuzione rapida via `wget` o `curl`**

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/fgirolami29/pytorchia_home/main/install.sh)
```

oppure

```bash
wget -qO- https://raw.githubusercontent.com/fgirolami29/pytorchia_home/main/install.sh | bash
```

---

### ✍️ README.md (per GitHub)

````markdown
# Pytorchia™ home

Setup rapido per prompt ANSI, funzioni utili, e branding Pytorchia™.

## 🧪 Installazione automatica

```bash
bash <(curl -sSfL https://raw.githubusercontent.com/fgirolami29/pytorchia_home/main/install.sh)
````

## 🖼 Contenuto

* `embl_bash.sh`: contiene funzioni come `br_flag()`
* `emblflag`, `emblsmall`: ASCII banner
* Impostazione automatica di variabili d’ambiente (`TORCHIA_HOME`)

## 💡 Uso

Dopo l'installazione, puoi usare:

```bash
br_flag "Test OK!"
```
