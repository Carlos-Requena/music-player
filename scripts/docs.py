#!/usr/bin/env python3
"""Índices y comprobaciones de la documentación.

    python3 scripts/docs.py index   regenera las tablas generadas (docs/INDEX.md, docs/decisions/README.md)
    python3 scripts/docs.py check   solo comprueba: falla (código 1) si algo está desfasado o roto

Lo que se genera sale del código siempre que se puede (qué archivos hay, qué opciones lee la
interfaz, de qué otras áreas depende cada una) y del frontmatter de las fichas de
`docs/areas/` y de las ADR. Formato de una ficha: docs/templates/area.md.

Qué comprueba:
- Fichas: frontmatter, secciones obligatorias y su orden, que sus archivos existan, que cada
  archivo de código pertenezca a una sola ficha, que sus opciones existan en el código y que
  cada opción del código esté en una ficha, que «Dependencias» enlace las áreas que el código
  usa de verdad, su «Estado actual» y su historial de verificación.
- ADR: nombre del archivo, numeración sin huecos, frontmatter, estado y que las áreas que
  citan las citen también a ellas.
- Código: cada QML registrado en build.rs, cada puente de cxx-qt en `.files([...])` y cada
  módulo declarado en main.rs (las trampas que más veces han roto la compilación).
- Toda la documentación: enlaces y anclas, símbolos enlazados (`[`símbolo`](archivo)`) que
  existan en su archivo, sin cifras que caducan ni frases de historia fuera de docs/history,
  sin comandos que borren datos del propietario y sin archivos ajenos en docs/.
- Que las tablas generadas estén al día.

Sin dependencias: Python 3.9 o más.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
AREAS = DOCS / "areas"
ADRS = DOCS / "decisions"
HISTORY = DOCS / "history" / "verificacion"

errors: list[str] = []


def error(where: Path | str, msg: str) -> None:
    rel = where.relative_to(ROOT) if isinstance(where, Path) else where
    errors.append(f"{rel}: {msg}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


# ─── Frontmatter y secciones ────────────────────────────────────────────────

def frontmatter(text: str) -> tuple[dict, str] | tuple[None, str]:
    """Frontmatter YAML mínimo: `clave: valor` y `clave: [a, b]`."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    data: dict = {}
    for line in m.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, _, value = line.partition(":")
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            data[key.strip()] = [v.strip() for v in value[1:-1].split(",") if v.strip()]
        else:
            data[key.strip()] = value
    return data, text[m.end():]


def strip_code(text: str) -> str:
    """Quita los bloques de código (```) y los comentarios HTML para no leer enlaces ni títulos de dentro."""
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def sections(body: str) -> list[tuple[str, str]]:
    """Secciones de nivel 2: [(título, texto)]."""
    out: list[tuple[str, str]] = []
    for part in re.split(r"^## ", strip_code(body), flags=re.M)[1:]:
        title, _, rest = part.partition("\n")
        out.append((title.strip(), rest))
    return out


def slug(title: str) -> str:
    """Ancla de un título al estilo de GitHub."""
    s = title.strip().lower()
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def anchors(text: str) -> set[str]:
    seen: dict[str, int] = {}
    out: set[str] = set()
    for m in re.finditer(r"^#{1,6} (.+)$", strip_code(text), re.M):
        base = slug(m.group(1))
        n = seen.get(base, 0)
        out.add(base if n == 0 else f"{base}-{n}")
        seen[base] = n + 1
    return out


# ─── Código ─────────────────────────────────────────────────────────────────

CODE_GLOBS = ["src/**/*.rs", "src/*.mm", "src/*.cpp", "src/*.py", "qml/*.qml", "login/src/*", "skins/*.json"]


def code_files() -> list[str]:
    files: set[str] = set()
    for pattern in CODE_GLOBS:
        for p in ROOT.glob(pattern):
            if p.is_file():
                files.add(p.relative_to(ROOT).as_posix())
    return sorted(files)


def without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?m)^\s*//.*$|\s//[^\n\"]*$", "", text)


def option_keys() -> dict[str, list[str]]:
    """Claves de `AppSettings.opcion` que usa el código → archivos donde aparecen."""
    keys: dict[str, list[str]] = {}
    patterns = [
        r'opcion\("([A-Za-z0-9_]+:?)"',
        r'setOpcion\("([A-Za-z0-9_]+:?)"',
        r'opciones\.get\("([A-Za-z0-9_]+)"\)',
    ]
    for f in code_files():
        if not f.endswith((".qml", ".rs")):
            continue
        text = without_comments(read(ROOT / f))
        found = set()
        for pat in patterns:
            found.update(re.findall(pat, text))
        if f == "qml/SettingsSheet.qml":
            found.update(re.findall(r'\{\s*cat:\s*"\w+",\s*key:\s*"(\w+)"', text))
        for k in found:
            k = k + "*" if k.endswith(":") else k
            keys.setdefault(k, []).append(f)
    return keys


def option_rows() -> dict[str, tuple[str, str]]:
    """Filas de Opciones: clave → (categoría, etiqueta)."""
    text = read(ROOT / "qml/SettingsSheet.qml")
    return {m[1]: (m[0], m[2]) for m in re.findall(r'\{\s*cat:\s*"(\w+)",\s*key:\s*"(\w+)",\s*label:\s*"([^"]+)"', text)}


# Singletons QML → archivo que los define.
SINGLETONS = {
    "Player": "src/player.rs",
    "Library": "src/library.rs",
    "Account": "src/account.rs",
    "AppSettings": "src/settings.rs",
    "Plugins": "src/plugins.rs",
    "Catalog": "qml/Catalog.qml",
    "Theme": "qml/Theme.qml",
}

# Lo que usa casi todo: no hace falta citarlo en «Dependencias».
TRANSVERSAL = {
    "qml/Theme.qml", "qml/Icon.qml", "qml/IconButton.qml", "qml/PillButton.qml",
    "qml/Slider.qml", "qml/TextField.qml", "qml/TabStrip.qml", "qml/Glass.qml", "qml/Cover.qml",
}


def used_files(f: str) -> set[str]:
    """Archivos de código que usa `f` (módulos de Rust, singletons y componentes QML)."""
    text = without_comments(read(ROOT / f))
    used: set[str] = set()
    if f.endswith(".rs"):
        base = "src/plugins/" if f.startswith("src/plugins/") else "src/"
        mods = {p.stem for p in (ROOT / "src").glob("*.rs")} - {"main"}
        for m in re.findall(r"\bcrate::(\w+)", text):
            if m in mods:
                used.add(f"src/{m}.rs")
        for m in re.findall(r"\b(\w+)::", text):
            if m in mods and base == "src/":
                used.add(f"src/{m}.rs")
        # `use crate::{a, b}`
        for group in re.findall(r"use crate::\{([^}]*)\}", text):
            for m in re.findall(r"\b(\w+)\b", group):
                if m in mods:
                    used.add(f"src/{m}.rs")
    elif f.endswith(".qml"):
        for name, target in SINGLETONS.items():
            if re.search(rf"\b{name}\.", text):
                used.add(target)
        for p in (ROOT / "qml").glob("*.qml"):
            if p.stem not in SINGLETONS and re.search(rf"(?m)(^|[\s:]){p.stem}\s*\{{", text):
                used.add(f"qml/{p.stem}.qml")
    used.discard(f)
    return used


def check_registration() -> None:
    build = read(ROOT / "build.rs")
    for p in sorted((ROOT / "qml").glob("*.qml")):
        rel = p.relative_to(ROOT).as_posix()
        if f'"{rel}"' not in build:
            error(ROOT / "build.rs", f"{rel} no está registrado en QML_FILES ni en QML_SINGLETONS")
    files_block = re.search(r"\.files\(\[([^\]]*)\]\)", build)
    bridged = set(re.findall(r'"([^"]+)"', files_block.group(1))) if files_block else set()
    main = read(ROOT / "src/main.rs")
    for p in sorted((ROOT / "src").glob("*.rs")):
        rel = p.relative_to(ROOT).as_posix()
        if "#[cxx_qt::bridge" in read(p) and rel not in bridged:
            error(ROOT / "build.rs", f"{rel} es un puente de cxx-qt y no está en .files([...])")
        if p.stem != "main" and not re.search(rf"(?m)^\s*(pub )?mod {p.stem};", main):
            error(ROOT / "src/main.rs", f"falta `mod {p.stem};`")


# ─── Fichas de área ─────────────────────────────────────────────────────────

AREA_KEYS = ["area", "titulo", "resumen", "archivos", "opciones", "adr"]
REQUIRED = ["Qué hace", "Reglas y decisiones", "Archivos", "Dependencias", "Estado actual"]
ORDER = ["Qué hace", "Reglas y decisiones", "Cómo funciona", "Interfaz", "Medidas",
         "Archivos", "Dependencias", "Estado actual", "Pendiente"]


def load_areas() -> dict[str, dict]:
    areas: dict[str, dict] = {}
    for p in sorted(AREAS.glob("*.md")):
        text = read(p)
        fm, body = frontmatter(text)
        if fm is None:
            error(p, "falta el frontmatter (ver docs/templates/area.md)")
            continue
        for key in AREA_KEYS:
            if key not in fm:
                error(p, f"falta `{key}:` en el frontmatter")
        extra = set(fm) - set(AREA_KEYS)
        if extra:
            error(p, f"claves desconocidas en el frontmatter: {', '.join(sorted(extra))}")
        if fm.get("area") != p.stem:
            error(p, f"`area: {fm.get('area')}` no coincide con el nombre del archivo")
        for key in ("archivos", "opciones", "adr"):
            if not isinstance(fm.get(key, []), list):
                error(p, f"`{key}:` tiene que ser una lista: [a, b]")
                fm[key] = []
        fm["path"] = p
        fm["body"] = body
        fm["text"] = text
        areas[p.stem] = fm
    return areas


def check_areas(areas: dict[str, dict], adrs: dict[str, dict]) -> dict[str, str]:
    owner: dict[str, str] = {}
    for name, a in areas.items():
        p = a["path"]
        for f in a.get("archivos", []):
            if not (ROOT / f).is_file():
                error(p, f"el archivo `{f}` no existe")
            elif f in owner:
                error(p, f"`{f}` ya está en la ficha de {owner[f]}: cada archivo, en una sola")
            else:
                owner[f] = name
        titles = [t for t, _ in sections(a["body"])]
        for req in REQUIRED:
            if req not in titles:
                error(p, f"falta la sección «{req}»")
        known = [t for t in titles if t in ORDER]
        if known != sorted(known, key=ORDER.index):
            error(p, f"secciones fuera de orden; el orden es: {' · '.join(ORDER)}")
        for t in titles:
            if t not in ORDER:
                error(p, f"sección «{t}» desconocida (usa ### dentro de una de las de la plantilla)")
        for ref in a.get("adr", []):
            if ref not in adrs:
                error(p, f"{ref} no existe en docs/decisions/")
            elif name not in adrs[ref].get("areas", []):
                error(p, f"cita {ref}, pero {ref} no la cita en `areas:`")
        state = dict(sections(a["body"])).get("Estado actual", "")
        if not re.search(r"\*\*Última verificación:\*\* (\d{4}-\d{2}-\d{2}|sin registrar)", state):
            error(p, "«Estado actual» necesita «**Última verificación:** AAAA-MM-DD, cómo» (o «sin registrar»)")
        hist = HISTORY / f"{name}.md"
        if not hist.is_file():
            error(p, f"falta su historial: docs/history/verificacion/{name}.md")
        elif f"history/verificacion/{name}.md" not in state:
            error(p, "«Estado actual» debe enlazar su historial de verificación")
    for f in code_files():
        if f not in owner:
            error(f, "no está en ninguna ficha de docs/areas/ (añádelo a `archivos:` de la suya)")
    # Opciones
    keys = option_keys()
    declared: dict[str, str] = {}
    for name, a in areas.items():
        for k in a.get("opciones", []):
            if k in declared:
                error(a["path"], f"la opción `{k}` ya está en la ficha de {declared[k]}")
            declared[k] = name
            if k not in keys:
                error(a["path"], f"la opción `{k}` no aparece en el código")
    for k, files in sorted(keys.items()):
        if k not in declared:
            error(files[0], f"la opción `{k}` no está en el `opciones:` de ninguna ficha")
    # Dependencias reales
    for name, a in areas.items():
        deps = area_deps(name, a, owner)
        dep_text = dict(sections(a["body"])).get("Dependencias", "")
        for d in sorted(deps):
            if f"({d}.md" not in dep_text:
                error(a["path"], f"su código usa el área «{d}»: enlázala en «Dependencias» como [{d}]({d}.md) y di para qué")
        for d in re.findall(r"(?m)^- \*\*\[([\w-]+)\]\(\1\.md\)\*\*", dep_text):
            if d not in deps:
                error(a["path"], f"«Dependencias» dice que usa «{d}», pero su código no la usa: quítala o muévela a «La usan»")
    return owner


def area_deps(name: str, a: dict, owner: dict[str, str]) -> set[str]:
    deps: set[str] = set()
    for f in a.get("archivos", []):
        if not (ROOT / f).is_file() or f.endswith(".json"):
            continue
        for u in used_files(f):
            if u in TRANSVERSAL:
                continue
            o = owner.get(u)
            if o and o != name:
                deps.add(o)
    return deps


# ─── ADR ────────────────────────────────────────────────────────────────────

ADR_KEYS = ["adr", "titulo", "estado", "fecha", "areas"]


def load_adrs() -> dict[str, dict]:
    adrs: dict[str, dict] = {}
    for p in sorted(ADRS.glob("ADR-*.md")):
        m = re.match(r"^ADR-(\d{2})-[a-z0-9-]+\.md$", p.name)
        if not m:
            error(p, "el nombre debe ser ADR-NN-palabras-en-minusculas.md")
            continue
        fm, body = frontmatter(read(p))
        if fm is None:
            error(p, "falta el frontmatter (ver docs/templates/adr.md)")
            continue
        for key in ADR_KEYS:
            if key not in fm:
                error(p, f"falta `{key}:` en el frontmatter")
        ref = f"ADR-{m.group(1)}"
        if fm.get("adr") != ref:
            error(p, f"`adr: {fm.get('adr')}` no coincide con el nombre ({ref})")
        estado = fm.get("estado", "")
        if not re.fullmatch(r"aceptada|(ampliada|sustituida) por ADR-\d{2}", estado):
            error(p, "`estado:` es «aceptada», «ampliada por ADR-NN» o «sustituida por ADR-NN»")
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", fm.get("fecha", "")):
            error(p, "`fecha:` en formato AAAA-MM-DD")
        titles = [t for t, _ in sections(body)]
        for req in ("Decisión", "Alternativas descartadas", "Motivo", "Consecuencias"):
            if req not in titles:
                error(p, f"falta la sección «{req}»")
        fm["path"] = p
        fm["num"] = int(m.group(1))
        adrs[ref] = fm
    nums = sorted(a["num"] for a in adrs.values())
    if nums != list(range(1, len(nums) + 1)):
        error(ADRS, f"la numeración de las ADR tiene huecos o repetidos: {nums}")
    return adrs


def check_adrs(adrs: dict[str, dict], areas: dict[str, dict]) -> None:
    for ref, a in adrs.items():
        for area in a.get("areas", []):
            if area not in areas:
                error(a["path"], f"el área «{area}» no existe en docs/areas/")
            elif ref not in areas[area].get("adr", []):
                error(a["path"], f"cita el área «{area}», pero su ficha no la cita en `adr:`")
        m = re.match(r"(ampliada|sustituida) por (ADR-\d{2})", a.get("estado", ""))
        if m and m.group(2) not in adrs:
            error(a["path"], f"{m.group(2)} no existe")


# ─── Enlaces, símbolos y textos prohibidos ──────────────────────────────────

def doc_files() -> list[Path]:
    files = [ROOT / "README.md", ROOT / "AGENTS.md", ROOT / "COMPILAR.md", ROOT / "CLAUDE.md"]
    files += sorted(DOCS.rglob("*.md"))
    return [f for f in files if f.is_file() and "guia/" not in f.relative_to(ROOT).as_posix()]


DESTRUCTIVE = [
    (r"rm\s+(-\w+\s+)*[^\n]*(\.config/musicplayer|Application Support/musicplayer|cookies\.txt|settings\.json|plugins\.json|Caches/musicplayer|\.cache/musicplayer)",
     "un comando que borraría datos del propietario (sus preferencias, su sesión o su caché)"),
    (r"--cookies-from-browser\s+\w", "importar las cookies del navegador en una prueba (usa un cookies.txt falso)"),
]
CADUCAN = [
    (r"\b\d+\s+tests?\b", "un número de tests (caduca: lo da `cargo test`)"),
    (r"\b\d[\d.]*\s+líneas\b", "un número de líneas de código (caduca)"),
]
HISTORIA = [
    (r"\b[Aa]ntes (se|era|eran|había|hacía|daba|salía)\b", "historia («antes…»): va a docs/history/"),
    (r"(?m)(^|[.:;(]\s*)Hubo (un|una)\b", "historia («Hubo…»): va a docs/history/"),
    (r"\bhasta que exista\b", "una promesa («hasta que exista…»): va a «Pendiente» o al ROADMAP"),
]


def check_docs(owner: dict[str, str]) -> None:
    for f in doc_files():
        text = read(f)
        rel = f.relative_to(ROOT).as_posix()
        in_history = rel.startswith("docs/history/")
        is_template = rel.startswith("docs/templates/")
        prose = strip_code(text)
        prose_no_inline = re.sub(r"`[^`\n]*`|«[^»\n]*»", "", prose)
        for i, (pat, msg) in enumerate(DESTRUCTIVE):
            # Importar cookies solo está prohibido en los procedimientos de prueba.
            if i == 1 and not rel.startswith("docs/runbooks/"):
                continue
            if re.search(pat, text):
                error(f, f"contiene {msg}")
        if not in_history and not is_template:
            for pat, msg in CADUCAN + HISTORIA:
                if re.search(pat, prose_no_inline):
                    error(f, f"contiene {msg}")
        if is_template:
            continue
        for m in re.finditer(r"\[([^\]]*)\]\(([^)\s]+)\)", prose):
            label, target = m.group(1), m.group(2)
            if re.match(r"^[a-z]+:", target):
                continue
            path_part, _, anchor = target.partition("#")
            dest = f if not path_part else (f.parent / path_part).resolve()
            if path_part and not dest.exists():
                error(f, f"enlace roto: {target}")
                continue
            if anchor and dest.suffix == ".md" and anchor not in anchors(read(dest)):
                error(f, f"ancla que no existe: {target}")
            sym = re.fullmatch(r"`([A-Za-z_][\w.]*)`", label)
            if sym and dest.is_file() and dest.suffix in (".rs", ".qml", ".mm", ".cpp", ".py"):
                name = sym.group(1).split(".")[-1]
                if not re.search(rf"\b{re.escape(name)}\b", read(dest)):
                    error(f, f"el símbolo `{name}` no está en {path_part}")


def check_foreign() -> None:
    def git(*args: str) -> list[str]:
        try:
            out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout
        except (OSError, subprocess.CalledProcessError):
            return []
        return [l for l in out.splitlines() if l]

    files = set(git("ls-files", "docs")) | set(git("ls-files", "--others", "--exclude-standard", "docs"))
    for f in sorted(files):
        if not (ROOT / f).exists():
            continue
        if f.startswith("docs/guia/"):
            if not re.search(r"\.(tex|pdf)$", f):
                error(f, "archivo generado al compilar la guía: no va en git (ver docs/guia/ en .gitignore)")
        elif not re.search(r"\.(md|png|jpe?g|svg|gif|webp)$", f):
            error(f, "archivo ajeno en docs/: solo Markdown e imágenes")


# ─── Tablas generadas ───────────────────────────────────────────────────────

def link_area(name: str, areas: dict, base: str = "areas/") -> str:
    return f"[{areas[name].get('titulo', name)}]({base}{name}.md)"


def areas_table(areas: dict, adrs: dict) -> str:
    rows = ["| Área | Qué es | Opciones | ADR |", "|---|---|---|---|"]
    for name, a in areas.items():
        opts = ", ".join(f"`{o}`" for o in a.get("opciones", [])) or "—"
        adr = ", ".join(f"[{r}](decisions/{adrs[r]['path'].name})" for r in a.get("adr", []) if r in adrs) or "—"
        rows.append(f"| {link_area(name, areas)} | {a.get('resumen', '')} | {opts} | {adr} |")
    return "\n".join(rows)


def files_table(areas: dict, owner: dict[str, str]) -> str:
    rows = ["| Archivo | Área |", "|---|---|"]
    for f in sorted(owner, key=lambda x: (x.split("/")[0], x)):
        rows.append(f"| [`{f}`](../{f}) | {link_area(owner[f], areas)} |")
    return "\n".join(rows)


def options_table(areas: dict) -> str:
    rows_info = option_rows()
    rows = ["| Clave | En Opciones | Área |", "|---|---|---|"]
    declared = sorted((k, n) for n, a in areas.items() for k in a.get("opciones", []))
    for k, n in declared:
        cat, label = rows_info.get(k, ("", ""))
        shown = f"{label} ({cat})" if label else "— (interna)"
        rows.append(f"| `{k}` | {shown} | {link_area(n, areas)} |")
    return "\n".join(rows)


def deps_table(areas: dict, owner: dict[str, str]) -> str:
    rows = ["| Área | Usa | La usan |", "|---|---|---|"]
    deps = {n: area_deps(n, a, owner) for n, a in areas.items()}
    for n in areas:
        uses = ", ".join(link_area(d, areas) for d in sorted(deps[n])) or "—"
        by = ", ".join(link_area(o, areas) for o in sorted(o for o in deps if n in deps[o])) or "—"
        rows.append(f"| {link_area(n, areas)} | {uses} | {by} |")
    return "\n".join(rows)


def adr_table(adrs: dict, areas: dict) -> str:
    rows = ["| ADR | Decisión | Estado | Áreas | Registrada |", "|---|---|---|---|---|"]
    for ref in sorted(adrs):
        a = adrs[ref]
        ar = ", ".join(f"[{x}](../areas/{x}.md)" for x in a.get("areas", []) if x in areas) or "—"
        rows.append(f"| [{ref}]({a['path'].name}) | {a.get('titulo', '')} | {a.get('estado', '')} | {ar} | {a.get('fecha', '')} |")
    return "\n".join(rows)


NOTE = "> Esta tabla se genera con `python3 scripts/docs.py index`. No la edites a mano: se pierde al regenerarla."


def fill(path: Path, blocks: dict[str, str], write: bool) -> None:
    text = read(path)
    new = text
    for name, content in blocks.items():
        pat = re.compile(rf"(<!-- generado:{name} -->\n).*?(<!-- /generado -->)", re.S)
        if not pat.search(new):
            error(path, f"falta el bloque <!-- generado:{name} --> … <!-- /generado -->")
            continue
        new = pat.sub(lambda m: f"{m.group(1)}{NOTE}\n\n{content}\n{m.group(2)}", new)
    if new != text:
        if write:
            path.write_text(new, encoding="utf-8")
            print(f"actualizado: {path.relative_to(ROOT)}")
        else:
            error(path, "las tablas generadas están desfasadas: python3 scripts/docs.py index")


# ─── Resultado ──────────────────────────────────────────────────────────────

def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode not in ("index", "check"):
        print(__doc__)
        return 2
    adrs = load_adrs()
    areas = load_areas()
    check_adrs(adrs, areas)
    owner = check_areas(areas, adrs)
    check_registration()
    check_foreign()
    fill(DOCS / "INDEX.md", {
        "areas": areas_table(areas, adrs),
        "archivos": files_table(areas, owner),
        "opciones": options_table(areas),
        "dependencias": deps_table(areas, owner),
    }, write=mode == "index")
    fill(ADRS / "README.md", {"adr": adr_table(adrs, areas)}, write=mode == "index")
    check_docs(owner)
    if errors:
        print(f"La documentación tiene {len(errors)} problema(s):\n")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"Documentación correcta: {len(areas)} áreas, {len(adrs)} ADR, {len(owner)} archivos de código.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
