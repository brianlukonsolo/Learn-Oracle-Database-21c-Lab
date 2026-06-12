# ✅ Solutions — Answer Key for the Student Workbook

Complete answers to every question in **[EXERCISES.md](EXERCISES.md)**.
The workbook deliberately contains **no answers** — they live only in this
file, so instructors can withhold or delete it to turn the workbook into an
assessment.

> 🙈 **Students:** attempt each mission first and write your answers down!
> The learning is in the head-scratching, not the answer.

---

## Mission 1 — Tour the listener 🟢

**Q1. How many services, and which one for HR?**
Five services: `XE`, `xepdb1`, `FREE`, `freepdb1`, plus a 32-hex-character
internal CDB GUID service. HR lives in the pluggable database, so clients use
**`xepdb1`**.

**Q2. Who told the listener about them?**
The database's **PMON** process registered them over the network
(`remote_listener`). You can tell it's dynamic because
[`listener/network/admin/listener.ora`](../listener/network/admin/listener.ora)
contains **no `SID_LIST`** — the listener was born knowing nothing.
`READY` specifically means *dynamically registered and accepting connections*;
statically configured services would show `UNKNOWN` instead.

**Q3. What does `Security ON: Local OS Authentication` mean?**
Administrative commands (`stop`, `reload`) only work for the OS user who owns
the listener process, *on that host*. Remote `lsnrctl` admin is refused with
`TNS-01189` — which is exactly why this lab's dashboard poller runs **inside**
the listener container.

---

## Mission 2 — Watch a registration happen 🟢

**Q1. Did the listener go down when the DB stopped?**
No — the listener stayed up the whole time. Only its **service registrations**
vanished; the dashboard event log recorded each one dropping off. The listener
is a switchboard; it doesn't die when a database does.

**Q2. How long until `xepdb1` reappeared?**
A few seconds after the DB opened — PMON registers immediately at open, then
refreshes every ~60s. The lab's startup script also issues an explicit
`ALTER SYSTEM REGISTER` to hurry it along.

**Q3. "The listener is down" — what's the precise diagnosis?**
The listener is **up** but has *no registered service* to hand the client to.
Clients get `ORA-12514` (listener knows no such service), **not** `ORA-12541`
(no listener at all). Distinguishing these two errors is half of real-world
Oracle connectivity triage.

---

## Mission 3 — The two paths 🟡

**Q1. Which connection failed with the listener stopped?**
The `@//listener:1521/...` path fails — in this Docker lab with
**`ORA-12154: TNS:could not resolve the connect identifier`**, because stopping
the container also removes its DNS name from Docker's network. (On a real
network, where the host stays up and only the listener process dies, you'd see
`ORA-12541: TNS:no listener` instead — Mission 5 explores exactly this
difference.) The direct `@//oracle-db:1521/...` path succeeds either way.

**Q2. Why did the direct path still work?**
The database container runs its **own local listener** (every DB needs one to
accept TCP connections). The lab's "listener host" is an *additional, remote*
listener — exactly like the Solaris box at work.

**Q3. Why force all clients through the listener host?**
A single well-known address for clients (the DB can move without reconfiguring
anyone), a control/audit point, and the ability to firewall the database host
so *only* the listener host can reach it.

---

## Mission 4 — Force a registration 🟡

**Q1. What is `remote_listener` set to, and by what?**
`(ADDRESS=(PROTOCOL=TCP)(HOST=listener)(PORT=1521))` — set at every DB start by
[`db/startup/01_register_remote_listener.sh`](../db/startup/01_register_remote_listener.sh).

**Q2. How do you verify `ALTER SYSTEM REGISTER` did anything?**
Watch the dashboard event log, or run
`docker compose exec listener lsnrctl status` and confirm the services are
present. If they were already registered there's no visible change — stop/start
the DB first to make the effect dramatic.

**Q3. What if `remote_listener` were unset?**
PMON would only register with its *local* listener. The remote listener host
would know no services: remote clients get `ORA-12514` while direct connections
keep working. The Solaris-style topology silently breaks (this is Mission 6).

---

## Mission 5 — Crime scene: no listener 🟡

**Q1. Why `ORA-12154` in Part A, not `ORA-12541`?**
Stopping a Docker container removes its **DNS entry** from the network, so the
hostname `listener` no longer resolves — the client fails at the *name
resolution* stage, before any TCP attempt. A real Solaris outage is different:
the host (and its DNS record) stay up while only the listener *process* dies,
so a real client gets through name resolution and then has its TCP connection
refused → `ORA-12541`. Lab lesson: **`12154` = name problem, `12541` = nothing
on the port** — they fail at different layers.

**Q2. What does Part B's genuine `ORA-12541` tell you?**
Name resolution **succeeded** and the client attempted TCP to `listener:1599` —
but the connection was refused because nothing listens there. The client never
got far enough to ask for a service, so this is a *process/port* problem, not a
database problem. Real-world equivalents: the listener process crashed, it's
listening on a different port than the client expects, or a firewall is
rejecting (not dropping — dropping gives timeouts) the connection.

**Q3. After the fix, what does the dashboard show in the first ~60s?**
The listener comes back up with **zero services** — it restarted empty, because
dynamic registration means it remembers nothing across restarts. It stays empty
until PMON's next ~60s registration cycle (or an explicit
`ALTER SYSTEM REGISTER`) repopulates it. That empty window *is* dynamic
registration made visible.

---

## Mission 6 — Crime scene: ghost service 🔴

**Q1. What error now, and how does it differ from Mission 5?**
**`ORA-12514: TNS:listener does not currently know of service requested`** —
the TCP connection *succeeded* (so a listener is there, unlike `12541`), but
the listener has no `xepdb1` to redirect you to.

**Q2. Prove the DB is healthy, and explain the paradox.**
`docker compose exec oracle-db sqlplus hr/hr@//oracle-db:1521/XEPDB1` connects
fine — the database is up. The break is purely in *registration*: with
`remote_listener` empty, PMON only tells its **local** listener about its
services; the remote listener host is left in the dark.

**Q3. Repair without restarting any container.**
```sql
-- as sysdba on oracle-db:
ALTER SYSTEM SET remote_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=listener)(PORT=1521))' SCOPE=MEMORY;
ALTER SYSTEM REGISTER;
```
The services snap back onto the dashboard within seconds. (`SCOPE=MEMORY` is
fine because the startup script re-sets the parameter on every boot anyway.)

---

## Mission 7 — Deploy + verify over REST 🟡

**Q1. Every hop employee #200 took:**
`deploy.sh` (listener container) → sqlplus connects via the **HRDB** alias →
listener accepts and redirects to the registered instance → row inserted in
`XEPDB1` → ORDS (which itself connects through the listener host,
`DBHOST=listener`) runs the auto-REST/module query → ORDS serves JSON →
curl on your laptop.

**Q2. What made a deploy possible on a box with no database?**
**sqlplus** (the client) and **tnsnames.ora** (name resolution). A client
install needs no database — exactly like the real Solaris host.

**Q3. Where do the two headcounts come from?**
Both ultimately run `SELECT COUNT(*) FROM hr.employees` in `XEPDB1` — the
dashboard's poller via the `HRDB` alias every 3s, the REST report via ORDS on
request. Same table, so they agree (modulo the 3-second poll lag).

---

## Mission 8 — Capstone: launch your own service 🔴

**Q1. You never touched the listener, yet it offers `payroll`. Mechanism?**
`START_SERVICE` makes the service active in the instance; PMON's next
registration message (forced by `ALTER SYSTEM REGISTER`) includes it, and the
listener — configured with no static services at all — simply believes PMON.
That's dynamic registration end-to-end.

**Q2. Why multiple services for one database?**
Services are the unit of **workload management**: separate apps get separate
services for monitoring/AWR attribution, resource-manager consumer-group
mapping, fine-grained failover policies, and the ability to relocate or disable
one app's entry point without touching the others.

**Q3. When does the listener stop offering `payroll` after `STOP_SERVICE`?**
When the next PMON update arrives without `payroll` in it (≤ ~60s, or instantly
with `ALTER SYSTEM REGISTER`). The dashboard's event log shows it drop off —
your cue that cleanup worked.

---

## 🏁 Self-assessment answers

| Question | The short answer |
|----------|------------------|
| Why does the listener show services it was never configured with? | PMON registers them dynamically via `remote_listener`; the listener has no static `SID_LIST` |
| `ORA-12541` vs `ORA-12514`, mechanically? | `12541`: TCP connect refused — no listener process. `12514`: TCP connected, but no such service is registered |
| Why zero services right after the *listener* restarts? | Registrations live in listener memory; a restarted listener knows nothing until PMON's next refresh |
| What does `remote_listener` do, and who reads it? | An init parameter naming an extra listener address; **PMON** reads it and registers services there |
| Why ~60s to appear, but `ALTER SYSTEM REGISTER` is instant? | PMON refreshes registrations on a ~60s cycle; the command forces an immediate registration message |
| Why must `lsnrctl status` run *on* the listener host in 21c? | Listener admin uses Local OS Authentication; remote TCP admin is refused (`TNS-01189`) |
