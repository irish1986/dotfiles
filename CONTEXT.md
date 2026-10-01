# Context

An Ansible playbook that sets up one WSL2 distro running Ubuntu 26.04, with the shell and tools that go with it, safe to run again at any time. Why it is shaped this way is in [`docs/adr/`](docs/adr/).

## Language

### Running it

**Run**:
One execution of the playbook. A second run on an unchanged machine changes nothing.
_Avoid_: deploy, apply

**Bootstrap**:
What takes a bare distro to the point where a run can start, then starts one; on a work machine it trusts the corporate CA before anything else. It asks no questions.
_Avoid_: installer, setup wizard

**Verify**:
The checks at the end of every role, and the check on each tool entry, asserting that what was installed actually works.
_Avoid_: test, smoke test

### What a machine gets

**Profile**:
A committed description of what a kind of machine gets: `base` for every machine, plus exactly one of `personal` or `work`. A profile supplies values; it never chooses roles.
_Avoid_: home (for personal), role, environment

**Local file**:
The one never-committed file per machine that names its profile and holds what must not be public or differs per machine: identity, names, package mirrors.
_Avoid_: override file, group_vars, config

**Layer**:
One of base profile, named profile, local file, applied in that order; a later layer overrides values and appends to lists.

**Role**:
One area of the machine that runs on every machine, in a fixed order: certificates, system, zsh, tools, ssh, git, herdr. A role with nothing to do does nothing.
_Avoid_: module, component

**Tool entry**:
One item in a profile's tool lists. Adding a tool means adding a tool entry, not a role.
_Avoid_: package (unless it is an apt package)

**Agent skill**:
A skill folder that every agent CLI on the machine loads, installed once for all of them.
_Avoid_: plugin

### Windows and the work network

**Windows side**:
What a run reads from the Windows host through WSL: the machine key and, on a work machine, the corporate CA. A run never writes to Windows.

**Machine key**:
The one SSH key a machine has: the Windows user's key, created by hand on Windows and copied into the distro on every run.
_Avoid_: distro key, GitHub key

**Corporate CA**:
The root certificate of the work network's TLS-inspecting proxy (Zscaler), exported on Windows. The distro trusts it before anything is downloaded.
_Avoid_: proxy certificate, zscaler.crt

**Package mirror**:
An internal registry the work network requires in place of a public one: for Python packages, Python builds or npm packages. Read anonymously.
_Avoid_: proxy, private repo
