# Pytorchia™ home

Setup rapido per prompt ANSI, funzioni utili e branding Pytorchia™.

![Pytorchia Certified™](https://img.shields.io/badge/Pytorchia%E2%84%A2-Certified-29abe2?style=for-the-badge&logo=github)

---

## 📁 Struttura della repo `pytorchia_home`

```
pytorchia_home/
├── install.sh              ← Script principale installazione
├── embl_bash.sh            ← Funzione `br_flag()` e simili
├── emblflag                ← ASCII Art grande
├── emblsmall               ← ASCII Art piccola
├── README.md               ← Istruzioni d’uso
└── .pytorchia/             ← (opzionale) contenuti prestrutturati
```

---

## 🖼 Contenuto

-   `embl_bash.sh`: contiene la funzione `br_flag()`
-   `emblflag`, `emblsmall`: ASCII banner grandi e piccoli
-   Impostazione automatica di `TORCHIA_HOME` in `.bashrc` / `.zshrc`

---

## 📦 USO

```bash
br_flag "<modulo>" "<versione>" "<autore>" "<ritardo>" "<modalità>" "<specific_val>"
```

---

## 📘 ESEMPI

```bash
br_flag "SEO Engine" "1.2.0" "F.Girolami" 0.5 specific docker
br_flag "Docker Booster" "2.0" "" 0.3 dual
br_flag "Tiny Mode" "" "" 0.2 right
br_flag "" "" "" 0.7 left
```

---

## 🎨 MODALITÀ SUPPORTATE

| Modalità   | Descrizione                                                  |
| ---------- | ------------------------------------------------------------ |
| `specific` | ➤ Stampa il file `.embl_<specific_val>` (es: `.embl_docker`) |
| `dual`     | ➤ Stampa affiancati `.emblflag` e `.emblsmall` _(default)_   |
| `left`     | ➤ Stampa solo `.emblflag` (grande)                           |
| `right`    | ➤ Stampa solo `.emblsmall` (piccolo)                         |
| `centered` | ➤ _(🧪 Work in progress)_ Centra `.emblflag` nel terminale   |

> ⚠️ **N.B.** Se usi la modalità `specific`, il **6° parametro è obbligatorio**

---

## 🧪 Installazione automatica

```bash
bash <(curl -sSfL https://github.com/fgirolami29/pytorchia_home/releases/download/v1.5.6/install.sh)
```

Oppure:

```bash
wget -qO- https://github.com/fgirolami29/pytorchia_home/releases/download/v1.5.6/install.sh | bash
```

---
