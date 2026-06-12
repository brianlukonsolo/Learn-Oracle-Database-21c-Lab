# ⚖️ Oracle 10g vs 21c — A Comprehensive Comparison

This lab teaches 10g‑era listener concepts on a 21c engine — a deliberate
choice, because the listener layer barely changed while everything around it
did. This page maps out exactly **what's the same, what's different, and what
arrived in between**.

> 🧭 TL;DR — the **Oracle Net layer transfers almost 1:1** between the
> versions. The **database architecture does not** (multitenant changed
> everything). Details below.

---

## 🗓️ At a glance

| | Oracle 10g | Oracle 21c |
|---|---|---|
| Released | 10.1 (2003) · 10.2 (2005) | 2021 |
| The letter | **g** = *grid* computing | **c** = *cloud* |
| Position in history | First "self‑managing" Oracle; introduced ASM, AWR, Data Pump | "Innovation release" between 19c (long‑term support) and 23ai |
| Support status | Long desupported (extended support ended ~2013) | Short support window by design; superseded by 23ai |
| Release model | Multi‑year major versions + patchsets | Annual releases; quarterly Release Updates (RUs) |
| Typical install | Manual `runInstaller`, X11 GUI | Same OUI lineage, plus official container images, RPM installs, AutoUpgrade |

---

## 🏛️ Architecture

| Topic | 10g | 21c |
|-------|-----|-----|
| Database layout | **Non‑CDB only** — one instance, one database; apps separated by *schemas* | **CDB‑only** — multitenant is *mandatory*: a container database (CDB) hosting pluggable databases (PDBs). Non‑CDB architecture is desupported in 21c |
| "A database for each app" | A whole new instance + files (heavyweight) | A new **PDB** inside the same CDB (lightweight; clone/unplug/plug in minutes) |
| Users | One flat namespace per database | **Common users** (CDB‑wide, `C##` prefix) vs **local users** (one PDB) — this lab's `hr` is a local user in `XEPDB1` |
| Service names | Often just the SID (`ORCL`); one main service per DB | Every PDB automatically gets its own service (`XEPDB1`) — *the service you ask the listener for selects your container* |
| Memory management | Manual SGA/PGA tuning; `sga_target` (ASMM) was 10g's big novelty | `memory_target`/AMM (11g+), automatic everything, In‑Memory column store option |
| Background processes | PMON, SMON, DBWn, LGWR, CKPT, MMON… | Same family **plus** LREG (registration), and dozens of new specialists |
| Storage | ASM newly introduced in 10g | ASM mature; Oracle Managed Files everywhere; bigfile tablespaces default |

---

## 🛰️ Listener & Oracle Net — the lab's territory

### Unchanged since 10g ✅

These behave **identically** in both versions — everything this lab teaches:

| Concept | Notes |
|---------|-------|
| `tnslsnr` binary + `lsnrctl` tool | Same commands (`status`, `services`, `reload`, `stop`), same output format |
| `listener.ora` / `tnsnames.ora` / `sqlnet.ora` | Same syntax, same `TNS_ADMIN` resolution |
| **Dynamic registration** | Instance registers its services with the listener; ~60s refresh; `ALTER SYSTEM REGISTER` forces it |
| `remote_listener` parameter | Existed in 10g (mainly for RAC); exactly the mechanism this lab uses |
| Static registration (`SID_LIST`) | Same; still shows `UNKNOWN` vs dynamic `READY` |
| Default port **1521** | Unchanged |
| EZConnect `//host:port/service` | Introduced *in* 10g; works in both |
| Error taxonomy | `ORA-12154`, `ORA-12505`, `ORA-12514`, `ORA-12541`, `ORA-12170` mean the same things |
| Dedicated/shared server handoff | Listener redirects, then steps out of the conversation |

### Changed between 10g and 21c 🔁

| Topic | 10g | 21c |
|-------|-----|-----|
| Who registers | **PMON** talks to the listener | A dedicated **LREG** process (since 12c) — everyone still *says* "PMON registers" |
| Remote listener administration | Possible — the **listener password** feature allowed remote `lsnrctl stop` | Password feature deprecated (12c) and gone; **local OS authentication only**. Remote admin attempts get `TNS-01189` — exactly why this lab's dashboard poller runs *inside* the listener container |
| Listener as attack surface | Notorious — unauthenticated remote admin, TNS poisoning era | Hardened: valid‑node checking (`VALID_NODE_CHECKING_REGISTRATION`), Class of Secure Transports (COST), registration restricted by default |
| RAC client entry point | Each node's listener listed in the client's `ADDRESS_LIST` | **SCAN listeners** (11.2+) — one DNS name fronting the whole cluster |
| IP stack | IPv4 | IPv6 supported (11.2+) |
| Connection storms | Nothing built in | Listener **connection rate limiting** (`RATE_LIMIT`, 11g+) |
| Connection pooling at the server | None (apps pooled client‑side) | **DRCP** — Database Resident Connection Pooling (11g+) |
| Encryption in transit | TCPS available but clunky; weak ciphers of the era | Modern TLS, simplified wallet‑less TLS in newer releases |
| EZConnect | Basic `//host:port/service` | **EZConnect Plus** (19c+): `tcps://`, multiple hosts, `?` parameters (`wallet_location`, `connect_timeout`, …) |
| Connection Manager (CMAN) | Plain proxy/firewall | CMAN with **Traffic Director Mode** (18c+): proxy resident pooling, transparent failover |

---

## 🔐 Security & authentication

| Topic | 10g | 21c |
|-------|-----|-----|
| Password case | **Case‑insensitive** | Case‑sensitive (since 11g) |
| Password verifiers | Weak DES‑based (10g verifier) | SHA‑512 (12c+ verifier) |
| Old clients | — | A 10g client **cannot log in by default** — `SQLNET.ALLOWED_LOGON_VERSION_SERVER` rejects pre‑11.2 logon protocols |
| Default accounts | Many open, well‑known passwords (`SCOTT/TIGER` era) | Locked/expired by default; no default sample schemas |
| Auditing | Basic audit trail (`AUDIT_TRAIL`) | **Unified Auditing** (12c+): one policy‑based trail |
| Encryption at rest | TDE *column* encryption arrived in 10gR2 | TDE **tablespace** encryption (11g+), online conversion |
| Privilege analysis, data redaction | ✗ | ✓ (12c+) |
| `SYSBACKUP` / `SYSDG` / `SYSKM` admin roles | ✗ (only `SYSDBA`/`SYSOPER`) | ✓ (12c+) — least‑privilege administration |

---

## 🧰 Tooling & management

| Tool | 10g | 21c |
|------|-----|-----|
| Web SQL console | **iSQL*Plus** (removed in 11g) | — (use SQL Developer Web / ORDS) |
| Bundled GUI monitoring | **EM Database Control** (per‑database web app) | **EM Express** (lightweight, XDB‑based) |
| REST access to data | ✗ | **ORDS** — auto‑REST any table, custom modules (this lab's `ords` container) |
| Command‑line export/import | Data Pump (`expdp`/`impdp`) — *new in 10g* | Same, heavily extended (transportable, parallel, compression) |
| Performance history | **AWR + ADDM + ASH** — *new in 10g* | Same family, far richer; real‑time SQL monitoring (11g+) |
| Upgrades | Manual / DBUA | **AutoUpgrade** tool (19c+) |
| Containers | ✗ (predates Docker by a decade) | Official container images; XE images maintained by the community (`gvenzl/oracle-xe`) |
| Scheduler | `DBMS_SCHEDULER` — *new in 10g* | Same, extended |

---

## 🧪 Editions: 10g XE vs 21c XE

The free Express Edition — what this lab runs:

| Limit | 10g XE (10.2 only) | 21c XE |
|-------|--------------------|--------|
| User data | 4 GB | **12 GB** |
| RAM used | 1 GB | **2 GB** |
| CPU | 1 CPU | 2 CPU threads |
| PDBs | — (non‑CDB) | Up to **3 PDBs** |
| Feature set | Very stripped | Nearly all EE features included (partitioning, In‑Memory, Data Guard…) |
| Word size | 32‑bit | 64‑bit |

---

## 🚀 What arrived along the way (release timeline)

Features a 10g DBA would not recognise, by the release that introduced them:

| Release | Headline arrivals |
|---------|-------------------|
| **11g** (2007–09) | Case‑sensitive passwords · Result cache · Active Data Guard · Real Application Testing · DRCP · ADR diagnostics (`DIAG_ADR_ENABLED`) · Edition‑Based Redefinition · SecureFiles LOBs |
| **11.2** (2009) | SCAN listeners · IPv6 · RAC One Node · deferred segment creation |
| **12c** (2013) | 🪆 **Multitenant (CDB/PDB)** · LREG process · Identity columns · `VARCHAR2(32767)` · Unified Auditing · Application Continuity · online datafile move · `FETCH FIRST n ROWS` |
| **12.2** (2016) | PDB hot cloning & relocation · native **sharding** · long identifiers (128 bytes) |
| **18c** (2018) | Read‑only Oracle homes · CMAN Traffic Director Mode · polymorphic table functions |
| **19c** (2019) | Long‑term‑support release · automatic indexing (Exadata/Autonomous) · real‑time statistics · EZConnect Plus · AutoUpgrade |
| **21c** (2021) | **CDB‑only architecture** · native `JSON` datatype · blockchain & immutable tables · SQL macros · in‑database JavaScript (MLE) · AutoML (OML4Py) |

And going the *other* way — things a 21c‑trained person should know 10g still
had: `SCOTT/TIGER`‑style open accounts, case‑insensitive passwords, listener
passwords, iSQL*Plus, no PDBs (so no `ALTER SESSION SET CONTAINER`), and Rules
of thumb tuned for spinning disks. 💾

---

## 🔌 Client ↔ server interoperability

| Client → Server | Works? |
|------------------|--------|
| 10g client → 21c server | ❌ Rejected by default (logon protocol too old); also unsupported |
| 11.2.0.4+ client → 21c server | ✅ Supported |
| 19c/21c client → 21c server | ✅ |
| 21c client → 10g server | ❌ Unsupported (and generally fails) |

If a legacy estate must talk to both worlds, the usual bridge is an
intermediate client version (11.2/12.x) or a gateway — not a direct 10g↔21c
connection.

---

## 🎯 What this means for this lab

| You learn here (21c) | On a real 10g estate |
|----------------------|----------------------|
| `lsnrctl status` / `services` reading | Identical output, identical skill |
| `ORA-12541` vs `ORA-12514` triage | Identical |
| `remote_listener` + dynamic registration | Identical mechanism (PMON does the talking instead of LREG) |
| Service names select a **PDB** (`XEPDB1`) | No PDBs — services map to the one database; you'll often see bare SIDs |
| `ALTER SESSION SET CONTAINER` | Doesn't exist — nothing to switch into |
| Remote `lsnrctl` refused (`TNS-01189`) | ⚠️ May be *possible* — check whether a listener password is set, and treat it as a finding |
| Case‑sensitive `hr`/`hr` | Passwords are case‑insensitive — `HR`/`hr`/`Hr` all work |

**Bottom line:** the wire protocol concepts, the listener tooling and the
failure modes are version‑proof. The architecture *around* the listener —
multitenant, security defaults, tooling — is where the 18 years show. 🕰️
