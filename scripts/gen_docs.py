#!/usr/bin/env python3
"""Generate documentation pages at build time.

Run by mkdocs-gen-files during `mkdocs build`. Nothing here is written into
docs/ -- pages go into MkDocs' in-memory file tree -- so generated content
cannot be committed stale, edited by mistake, or drift from the roles it
describes.

What is generated:

  roles/<role>.md      one page per role, from defaults/, vars/, meta/, tasks/,
                       handlers/, files/ and templates/
  roles/index.md       the role matrix, including whether each role is in the
                       default selection
  roles/SUMMARY.md     nav for the roles section (mkdocs-literate-nav)
  reference/variables.md    every key in the example group_vars
  reference/collections.md  the pinned Galaxy collections
  about/changelog.md        mirror of /CHANGELOG.md
  contributing/index.md     mirror of .github/CONTRIBUTING.md
  contributing/security.md  mirror of .github/SECURITY.md
  about/licence.md          mirror of .github/LICENSE

Mirrored files have no copy under docs/, so the single source of truth stays
where GitHub expects to find it.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import mkdocs_gen_files
import yaml

ROOT = Path(__file__).resolve().parent.parent
ROLES_DIR = ROOT / "roles"
REPO_URL = "https://github.com/irish1986/dotfiles"
BLOB = f"{REPO_URL}/blob/main"

# Internal helpers, not user-selectable roles.
HELPER_ROLES = {"apt_repo"}

# Set MKDOCS_STRICT_ROLES=1 to fail the build when a role has no README. Left
# off by default so the site builds while READMEs are still being written.
STRICT = os.environ.get("MKDOCS_STRICT_ROLES") == "1"

problems: list[str] = []


def load_yaml(path: Path) -> Any:
    if not path.is_file():
        return None
    try:
        return yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        problems.append(f"{path.relative_to(ROOT)}: {exc}")
        return None


def default_roles() -> list[str]:
    """Roles enabled in the example configuration, in order."""
    data = load_yaml(ROOT / "docs" / "examples" / "group_vars-all.yml") or {}
    return list(data.get("dotfiles_roles") or [])


def doc_comments(path: Path) -> dict[str, str]:
    """Map each top-level key to the comment block immediately above it.

    Comments are where the *reason* for a default lives, and that is the part
    worth publishing -- the value itself is already visible.
    """
    if not path.is_file():
        return {}
    out: dict[str, str] = {}
    buffer: list[str] = []
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            text = stripped.lstrip("#").strip()
            # Skip decorative rules such as "-- Area ----".
            if text and not re.fullmatch(r"[-=_─-╿\s]+", text):
                buffer.append(text)
            continue
        match = re.match(r"^([a-zA-Z_][\w]*):", line)
        if match:
            if buffer:
                out[match.group(1)] = " ".join(buffer)
            buffer = []
        elif not stripped or stripped == "---":
            continue
        else:
            buffer = []
    return out


def walk_tasks(tasks: Any, visit) -> None:
    for task in tasks or []:
        if not isinstance(task, dict):
            continue
        visit(task)
        for key in ("block", "rescue", "always"):
            if key in task:
                walk_tasks(task[key], visit)


def role_facts(role: Path) -> dict[str, Any]:
    """Everything mechanical, read from the role itself."""
    facts: dict[str, Any] = {
        "packages": set(),
        "removed": set(),
        "tags": set(),
        "urls": set(),
        "services": set(),
        "wsl_tasks": 0,
        "task_count": 0,
    }

    def visit(task: dict) -> None:
        facts["task_count"] += 1
        for value in task.get("tags", []) or []:
            if isinstance(value, str):
                facts["tags"].add(value)
        cond = task.get("when")
        conds = cond if isinstance(cond, list) else [cond]
        if any("dotfiles_is_wsl" in str(c) for c in conds if c):
            facts["wsl_tasks"] += 1
        for key, args in task.items():
            if not isinstance(args, dict):
                continue
            if key.endswith(".apt") or key.endswith(".package"):
                names = args.get("name")
                names = names if isinstance(names, list) else [names]
                target = "removed" if args.get("state") == "absent" else "packages"
                for name in names:
                    if isinstance(name, str):
                        facts[target].add(name)
            if "service" in key or "systemd" in key:
                name = args.get("name")
                if isinstance(name, str):
                    facts["services"].add(name)

    for path in sorted((role / "tasks").rglob("*.yml")):
        walk_tasks(load_yaml(path), visit)
        for url in re.findall(r"https?://[^\s\"'{}]+", path.read_text()):
            facts["urls"].add(url.rstrip(".,"))

    for path in sorted(role.glob("defaults/*.yml")):
        for url in re.findall(r"https?://[^\s\"'{}]+", path.read_text()):
            facts["urls"].add(url.rstrip(".,"))

    return facts


def render_role(role: Path, defaults_order: list[str]) -> str:
    name = role.name
    meta = load_yaml(role / "meta" / "main.yml") or {}
    info = meta.get("galaxy_info") or {}
    defaults = load_yaml(role / "defaults" / "main.yml") or {}
    comments = doc_comments(role / "defaults" / "main.yml")
    facts = role_facts(role)
    readme = role / "README.md"

    lines: list[str] = [f"# {name}", ""]

    if info.get("description"):
        lines += [str(info["description"]).strip(), ""]

    if readme.is_file():
        body = readme.read_text().strip()
        # Drop the H1: this page already has one, and two would trip MD025.
        body = re.sub(r"\A#\s+\S.*\n+", "", body)
        # A README links as ../../docs/x.md, which is correct when browsing
        # roles/<role>/README.md on GitHub. The rendered page lives at
        # roles/<role>.md, one level shallower, so the prefix is rewritten here
        # rather than making the READMEs wrong in one of the two places.
        body = body.replace("../../docs/", "../")
        # Demote the rest so they nest under the generated H1.
        body = re.sub(r"^(#{2,5})\s", r"#\1 ", body, flags=re.M)
        lines += [body, ""]
    else:
        problems.append(f"roles/{name}: no README.md")
        lines += [
            "!!! warning \"Undocumented\"",
            f"    `roles/{name}/README.md` does not exist yet, so this page shows",
            "    only what could be derived from the role's source.",
            "",
        ]

    enabled = name in defaults_order
    lines += ["## At a glance", ""]
    lines += ["| | |", "|---|---|"]
    if name in HELPER_ROLES:
        lines.append("| Selection | Internal helper, invoked by other roles |")
    else:
        lines.append(
            f"| Default selection | {'Yes' if enabled else 'No, opt in via `dotfiles_roles`'} |"
        )
    if facts["tags"]:
        lines.append(f"| Tags | {', '.join('`' + t + '`' for t in sorted(facts['tags']))} |")
    platforms = info.get("platforms") or []
    if platforms:
        versions = ", ".join(
            str(v) for p in platforms for v in (p.get("versions") or [])
        )
        lines.append(f"| Platforms | {versions} |")
    if facts["wsl_tasks"]:
        lines.append(f"| WSL-conditional tasks | {facts['wsl_tasks']} |")
    lines.append(f"| Tasks | {facts['task_count']} |")
    lines.append("")

    if facts["packages"]:
        lines += ["## Packages installed", ""]
        lines += [", ".join(f"`{p}`" for p in sorted(facts["packages"])), ""]
    if facts["removed"]:
        lines += ["## Packages removed", ""]
        lines += [", ".join(f"`{p}`" for p in sorted(facts["removed"])), ""]

    if defaults:
        lines += ["## Variables", "", "| Variable | Default | Notes |", "|---|---|---|"]
        for key in defaults:
            value = defaults[key]
            shown = "" if value in (None, "", [], {}) else f"`{value}`"
            if isinstance(value, (list, dict)) and value:
                shown = f"`{type(value).__name__}` of {len(value)}"
            note = comments.get(key, "")
            lines.append(f"| `{key}` | {shown} | {note} |")
        lines.append("")

    handlers = load_yaml(role / "handlers" / "main.yml")
    if handlers:
        names = [h.get("name") for h in handlers if isinstance(h, dict) and h.get("name")]
        if names:
            lines += ["## Handlers", ""] + [f"- `{n}`" for n in names] + [""]

    if facts["services"]:
        lines += ["## Services managed", ""]
        lines += [", ".join(f"`{s}`" for s in sorted(facts["services"])), ""]

    deployed = sorted(
        [p for p in (role / "files").rglob("*") if p.is_file()]
        + [p for p in (role / "templates").rglob("*") if p.is_file()]
    )
    if deployed:
        lines += ["## Files deployed", ""]
        for path in deployed[:24]:
            lines.append(f"- `{path.relative_to(role)}`")
        if len(deployed) > 24:
            lines.append(f"- ... and {len(deployed) - 24} more")
        lines.append("")

    external = sorted(u for u in facts["urls"] if "github.com/irish1986" not in u)
    if external:
        lines += [
            "## External sources",
            "",
            "Repositories, keys and archives this role fetches.",
            "",
        ]
        for url in external[:20]:
            lines.append(f"- <{url}>")
        lines.append("")

    lines += [
        "## Source",
        "",
        f"[`roles/{name}/`]({BLOB}/roles/{name})",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    roles = sorted(p for p in ROLES_DIR.iterdir() if p.is_dir())
    order = default_roles()

    summary = ["* [Overview](index.md)"]
    for role in roles:
        page = f"roles/{role.name}.md"
        with mkdocs_gen_files.open(page, "w") as handle:
            handle.write(render_role(role, order))
        mkdocs_gen_files.set_edit_path(page, f"roles/{role.name}/README.md")
        summary.append(f"* [{role.name}]({role.name}.md)")

    with mkdocs_gen_files.open("roles/SUMMARY.md", "w") as handle:
        handle.write("\n".join(summary) + "\n")

    # ---- role matrix -------------------------------------------------------
    rows = ["# Roles", "", f"{len(roles)} roles. ", ""]
    rows += [
        "Pages below are generated from each role's source on every build, so the",
        "variables, packages and tags shown cannot drift from the code.",
        "",
        "| Role | Default | Tags | Summary |",
        "|---|---|---|---|",
    ]
    for role in roles:
        meta = load_yaml(role / "meta" / "main.yml") or {}
        desc = str((meta.get("galaxy_info") or {}).get("description", "")).strip()
        facts = role_facts(role)
        tags = ", ".join(f"`{t}`" for t in sorted(facts["tags"])) or "-"
        if role.name in HELPER_ROLES:
            default = "helper"
        else:
            default = "yes" if role.name in order else "opt-in"
        rows.append(f"| [{role.name}]({role.name}.md) | {default} | {tags} | {desc} |")
    rows.append("")
    with mkdocs_gen_files.open("roles/index.md", "w") as handle:
        handle.write("\n".join(rows))

    # ---- variables reference ----------------------------------------------
    example = ROOT / "docs" / "examples" / "group_vars-all.yml"
    data = load_yaml(example) or {}
    comments = doc_comments(example)
    ref = [
        "# Variables",
        "",
        "Every key in the example configuration. Copy it to",
        "`inventory/group_vars/all.yml` and edit; `scripts/setup` does this for you",
        "on a fresh clone.",
        "",
        "Per-role variables and their defaults are on each [role page](../roles/index.md).",
        "",
        "| Variable | Example | Notes |",
        "|---|---|---|",
    ]
    for key, value in data.items():
        shown = "" if value in (None, "", [], {}) else f"`{value}`"
        if isinstance(value, (list, dict)) and value:
            shown = f"`{type(value).__name__}` of {len(value)}"
        ref.append(f"| `{key}` | {shown} | {comments.get(key, '')} |")
    ref.append("")
    with mkdocs_gen_files.open("reference/variables.md", "w") as handle:
        handle.write("\n".join(ref))

    # ---- collections reference --------------------------------------------
    req = load_yaml(ROOT / "collections" / "requirements.yml") or {}
    coll = [
        "# Collections",
        "",
        "Ansible Galaxy collections, pinned in",
        f"[`collections/requirements.yml`]({BLOB}/collections/requirements.yml).",
        "Updates are proposed by Renovate.",
        "",
        "| Collection | Version |",
        "|---|---|",
    ]
    for entry in req.get("collections") or []:
        if isinstance(entry, dict):
            coll.append(f"| `{entry.get('name')}` | `{entry.get('version', 'latest')}` |")
    coll.append("")
    with mkdocs_gen_files.open("reference/collections.md", "w") as handle:
        handle.write("\n".join(coll))

    # ---- mirrored files ----------------------------------------------------
    mirrors = {
        "about/changelog.md": ROOT / "CHANGELOG.md",
        "contributing/index.md": ROOT / ".github" / "CONTRIBUTING.md",
        "contributing/security.md": ROOT / ".github" / "SECURITY.md",
        "about/licence.md": ROOT / ".github" / "LICENSE",
    }
    for page, source in mirrors.items():
        if not source.is_file():
            problems.append(f"{source.relative_to(ROOT)}: missing, cannot mirror to {page}")
            continue
        body = source.read_text()
        if source.name == "LICENSE":
            body = "# Licence\n\n```text\n" + body.strip() + "\n```\n"
        with mkdocs_gen_files.open(page, "w") as handle:
            handle.write(body)
        mkdocs_gen_files.set_edit_path(page, str(source.relative_to(ROOT)))

    if problems:
        header = f"gen_docs: {len(problems)} problem(s)"
        print(header)
        for line in problems:
            print(f"  {line}")
        if STRICT:
            raise SystemExit(header)


main()
