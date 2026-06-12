# 📚 Introduction — Oracle Database & Listeners, From Zero

New to Oracle? Start here. Ten minutes of reading and the dashboard, the
missions and every error message in this lab will make sense. 🧠

---

## 🗄️ What is Oracle Database, really?

When people say "the database is running", two distinct things are running:

| Thing | What it is | Lives where |
|-------|------------|-------------|
| 💾 **The database** | The files: your tables, indexes, redo logs — bytes on disk | Storage |
| 🫀 **The instance** | The running software: a chunk of shared memory (the **SGA**) plus a family of background processes | RAM + CPU |

The **instance** opens the **database** and does all the work. One you can
back up; the other you can restart. When this lab "stops the DB", it's the
*instance* that dies — the files survive in a Docker volume.

### The background processes 👷

An Oracle instance is a *team* of cooperating processes, each with one job.
Meet the ones that matter here:

| Process | Name | Job |
|---------|------|-----|
| 🧹 **PMON** | Process Monitor | Cleans up after dead sessions — and (in older versions) the famous **service registration**. Since 12c the actual messenger is a helper called **LREG** (Listener Registration), but everyone still says "PMON registers". This lab does too. |
| ✍️ **DBWn** | Database Writer | Writes changed data blocks from memory to disk |
| 📜 **LGWR** | Log Writer | Writes the redo log — the crash-proof journal of every change |
| ⏱️ **CKPT** | Checkpoint | Stamps "everything up to here is on disk" markers |
| 🛡️ **SMON** | System Monitor | Crash recovery on startup, internal housekeeping |

You'll meet **PMON/LREG** constantly in this lab — it's the process that talks
to the listener.

### CDB and PDB — the database *inside* the database 🪆

Since Oracle 12c, one **container database (CDB)** hosts many
**pluggable databases (PDBs)** — like Docker for databases: shared engine,
isolated contents.

In this lab:

```
CDB:  XE            ← the container (you rarely touch it)
└── PDB: XEPDB1     ← "your" database: the HR schema lives here
```

That's why connect strings here say `SERVICE_NAME = XEPDB1`, and why scripts
start with `ALTER SESSION SET CONTAINER = XEPDB1;` — you're stepping into the
right box of the matryoshka. A user created in the CDB root is a different
beast (a *common user*) from one created inside a PDB (a *local user* — like
our `hr`).

---

## 🛰️ What is a listener?

Here's the surprise: **clients never connect directly to a database.**

A database instance doesn't accept TCP connections out of nowhere. Something
has to sit on a port, answer the phone, and put callers through. That
something is the **listener** (`tnslsnr`) — Oracle's switchboard operator 🎧:

1. 📞 A client dials `listener-host:1521` and asks for a **service** by name:
   *"XEPDB1, please."*
2. 📋 The listener checks its list of registered services.
3. 🤝 If the service is registered, the listener hands the client over to the
   database instance (spawning a dedicated server process for it). From then
   on, **client and database talk directly** — the listener steps out of the
   conversation entirely.
4. 🚫 If the service *isn't* on the list: `ORA-12514`. If nobody answers the
   phone at all: `ORA-12541`.

Two consequences students find counter-intuitive:

- 💪 **A dead listener doesn't kill existing sessions.** It only answers *new*
  calls. Sessions already connected keep working.
- 🪶 **The listener is tiny and knows almost nothing.** It's not a proxy, not
  a cache, not a database. It's a receptionist with a list.

### How does the listener's list get filled? 🤔

Two ways:

| | Static registration | Dynamic registration ✨ |
|--|--------------------|------------------------|
| How | You hand-write services into `listener.ora` (`SID_LIST`) | The instance **registers itself**: PMON/LREG calls the listener and says "I offer XEPDB1" |
| Status shown | `UNKNOWN` (listener takes your word for it) | `READY` (the instance itself vouched, ~every 60s) |
| Survives listener restart | Yes (it's in the config file) | **No** — a restarted listener starts with an **empty list** until the next registration |
| Used in this lab | ❌ never | ✅ exclusively |

Dynamic registration is the heart of this lab. The listener container's
`listener.ora` contains **no services at all** — everything you see on the
📡 dashboard arrived over the network from PMON.

### Remote registration — the trick this whole lab exists for 🎯

By default, an instance registers with the listener on its **own** machine.
But one parameter changes everything:

```sql
ALTER SYSTEM SET remote_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=listener)(PORT=1521))';
```

Now PMON also registers with a listener on a **different host**. That host
needs no database, no data files, nothing but `tnslsnr` and a port. Clients
connect *there* and get redirected to wherever the database actually lives.

That's precisely the topology this lab models — and the real-world setup it
recreates: a Solaris box running *only* a listener, fronting a database on a
separate machine. The database can move; clients never notice. 📦➡️

---

## 🗺️ Finding the database: TNS

"TNS" (Transparent Network Substrate) is Oracle-speak for its networking
layer. You'll meet it in two places:

**1. Connect strings** — how a client says where it's going:

```
# EZConnect: host : port / service
sqlplus hr/hr@//listener:1521/XEPDB1

# Or a tnsnames.ora alias (an address book entry):
sqlplus hr/hr@HRDB
```

`HRDB` is defined in [`tnsnames.ora`](../listener/network/admin/tnsnames.ora)
on the listener host — look it up, it's just the long form written down.

**2. Error codes** — anything starting `TNS-` or many `ORA-12xxx` errors is
the *network* layer talking, **not** the database. Decoding them is a core
skill — the workbook has a full [error decoder](EXERCISES.md#-error-decoder--the-ones-youll-actually-hit),
but the two stars are:

| Error | Means | Layer that failed |
|-------|-------|-------------------|
| `ORA-12541` | Nobody listening on that host:port | TCP — the phone rings out ☎️ |
| `ORA-12514` | Listener answered, but never heard of your service | Registration — the receptionist's list 📋 |

---

## 🧩 This lab, mapped to the concepts

![Architecture diagram](architecture.png)

| Container | Plays the role of | The concept it teaches |
|-----------|-------------------|------------------------|
| 🛰️ `listener` | The "Solaris box" — listener only, **no database** | A listener is independent of any database |
| 🗄️ `oracle-db` | The remote database server | Instance + CDB/PDB; PMON registers *outward* via `remote_listener` |
| 🌐 `ords` | A REST gateway (talks to the DB **through** the listener) | Apps are just clients too |
| 📊 `dashboard` | Your X-ray glasses 🕶️ | Watches the listener's service list change in real time |

And the cast of characters in one sentence each:

- **Instance** 🫀 — the running Oracle software (memory + processes).
- **PMON / LREG** 🧹 — the background process that registers services with listeners.
- **Service** 🎫 — a *name* clients ask for (`XEPDB1`); the unit of registration. One database can offer many.
- **Listener** 🛰️ — the switchboard; matches requested service names to registered instances.
- **`remote_listener`** 🎯 — the parameter that makes PMON register with a listener on another host.
- **`lsnrctl`** 🔧 — the command-line tool to interrogate a listener (`status`, `services`).
- **TNS / `tnsnames.ora`** 🗺️ — Oracle's networking layer and its address book.
- **CDB / PDB** 🪆 — container database / pluggable database; `hr` lives in the PDB `XEPDB1`.

---

## ✅ Check yourself before the missions

You're ready for the [🎓 workbook](EXERCISES.md) if you can answer these:

- [ ] A client connects "to the database" — what does it *actually* connect to first?
- [ ] Who fills the listener's service list in this lab, and how often is it refreshed?
- [ ] Why does a freshly restarted listener know about **zero** services, even though the database never stopped?
- [ ] What single parameter makes a database register with a listener on a *different* machine?
- [ ] `ORA-12541` vs `ORA-12514` — which one means the listener is actually running?

If any of these feel shaky, skim the matching section above once more — then
go break things in the missions. That's where it sticks. 🔨😄
