# 🎓 Student Workbook — Listener ↔ Database Missions

Eight hands-on missions, easiest first. Each one has a **🎯 goal**, the
**🧰 commands** you need, and **❓ check-yourself questions**.

> 🆕 **First time with Oracle?** Read the **[introduction](INTRO.md)** first —
> ten minutes on instances, PDBs, listeners and registration, and these
> missions will make far more sense.

> 📖 **No answers in this file — on purpose!** 🙅 Work each mission honestly,
> write your answers down, *then* check them against
> **[SOLUTIONS.md](SOLUTIONS.md)**. (Instructors: delete that one file and
> this workbook becomes a ready-made assessment.)

> **Setup:** `docker compose up -d --build`, then wait until
> `docker compose ps` shows `oracle-db` as **healthy** (~90s first run).
> Keep the 📊 dashboard open at <http://localhost:8090> for every mission —
> it's your window into what the listener is thinking.

**Difficulty legend:** 🟢 warm-up · 🟡 core · 🔴 challenge

---

## 🧭 Table of missions

| # | Mission | Difficulty | You will learn |
|---|---------|------------|----------------|
| 1 | [Tour the listener](#-mission-1--tour-the-listener) | 🟢 | Reading `lsnrctl status` |
| 2 | [Watch a registration happen](#-mission-2--watch-a-registration-happen) | 🟢 | Dynamic registration timing |
| 3 | [The two paths](#-mission-3--the-two-paths) | 🟡 | What the listener actually does |
| 4 | [Force a registration](#-mission-4--force-a-registration) | 🟡 | `ALTER SYSTEM REGISTER` |
| 5 | [Crime scene: no listener](#-mission-5--crime-scene-no-listener) | 🟡 | Diagnosing `ORA-12541` |
| 6 | [Crime scene: ghost service](#-mission-6--crime-scene-ghost-service) | 🔴 | Diagnosing `ORA-12514` |
| 7 | [Deploy + verify over REST](#-mission-7--deploy--verify-over-rest) | 🟡 | The full data path |
| 8 | [Capstone: launch your own service](#-mission-8--capstone-launch-your-own-service) | 🔴 | `DBMS_SERVICE` + registration |

---

## 🟢 Mission 1 — Tour the listener

**🎯 Goal:** read a `lsnrctl status` report like an operator would.

```powershell
docker compose exec listener lsnrctl status
docker compose exec listener lsnrctl services
```

**❓ Questions**
1. How many **services** does the listener know about, and which one would a
   client asking for the HR schema use?
2. The summary says every instance is `status READY`. Who *told* the listener
   that — and how do you know no static config is involved?
3. What does `Security ON: Local OS Authentication` mean for someone trying to
   run `lsnrctl stop` from another machine?

---

## 🟢 Mission 2 — Watch a registration happen

**🎯 Goal:** see a service deregister and re-register, live.

Open the 📊 dashboard, then:

```powershell
docker compose stop oracle-db     # watch the dashboard...
docker compose start oracle-db    # ...and watch it again
```

**❓ Questions**
1. When the database stopped, did the **listener** go down? What exactly
   changed on the dashboard?
2. Roughly how long after `start` did `xepdb1` reappear?
3. A colleague says *"the listener is down"* because clients get errors while
   the DB is stopped. What's the more precise diagnosis?

---

## 🟡 Mission 3 — The two paths

**🎯 Goal:** prove the listener is genuinely in the middle — by removing it.

```powershell
# Both paths work while everything is up:
docker compose exec listener bash /deploy/deploy.sh hr hr HRDB           # via listener
docker compose exec listener bash /deploy/deploy.sh hr hr HRDB_DIRECT    # bypass

# Now take the listener away and try both again:
docker compose stop listener
docker compose exec listener ...   # ⚠️ won't work -- container is stopped! Why?
```

Hmm — you can't `exec` into a stopped container. 🤔 So run the comparison from
the **database** container instead (it has sqlplus too):

```powershell
docker compose exec oracle-db sqlplus hr/hr@//listener:1521/XEPDB1      # via listener host
docker compose exec oracle-db sqlplus hr/hr@//oracle-db:1521/XEPDB1    # direct
docker compose start listener     # put it back!
```

**❓ Questions**
1. With the listener stopped, which connection failed, with what error?
2. Why did the *direct* path still work even though the "listener" was down?
3. In the real Solaris setup this lab models, why might a company force all
   clients through the listener host instead of letting them connect direct?

---

## 🟡 Mission 4 — Force a registration

**🎯 Goal:** make PMON register *right now*, and find the setting that makes
remote registration possible.

```powershell
# Ask the DB where it registers:
docker compose exec oracle-db sqlplus / as sysdba
SQL> show parameter remote_listener
SQL> ALTER SYSTEM REGISTER;
SQL> exit
```

**❓ Questions**
1. What is `remote_listener` set to, and which file in this repo set it?
2. `ALTER SYSTEM REGISTER` returned instantly. How can you *verify* it did
   anything?
3. What would happen if `remote_listener` were unset? (Predict — then Mission 6
   lets you live it.)

---

## 🟡 Mission 5 — Crime scene: no listener

**🎯 Goal:** meet `ORA-12541` *and* its imposter — and learn what each one
tells you about how far the connection attempt got.

**Part A** — sabotage (or have a classmate do it secretly 🕵️):

```powershell
docker compose stop listener
docker compose exec oracle-db sqlplus hr/hr@//listener:1521/XEPDB1
```

🤨 Look closely at the error. It's probably **not** the one you expected for
"the listener is down"...

**Part B** — bring the listener back, then aim at a port where nothing listens:

```powershell
docker compose start listener
docker compose exec oracle-db sqlplus hr/hr@//listener:1599/XEPDB1
```

*(If you have sqlplus/SQL Developer on your laptop, there's a third variant:
with the listener container stopped, connect to `localhost:1521` — the
unmapped port gives you the same error as Part B.)*

**❓ Questions**
1. Part A gave `ORA-12154` (could not resolve), not `ORA-12541` (no listener).
   Why? What did Docker do that a real Solaris outage wouldn't?
2. Part B's error is the genuine `ORA-12541`. What *exactly* does it tell you
   about how far the connection got — and what's the equivalent real-world
   scenario it represents?
3. After Part A's fix (`start listener`), what does the dashboard show in the
   first ~60 seconds, and why?

---

## 🔴 Mission 6 — Crime scene: ghost service

**🎯 Goal:** create and diagnose the *other* classic error — listener up, but
the service missing. This is the subtle one that confuses real on-call DBAs.

Sabotage — make the database forget to register remotely:

```powershell
docker compose exec oracle-db sqlplus / as sysdba
SQL> ALTER SYSTEM SET remote_listener='' SCOPE=MEMORY;
SQL> exit
docker compose exec listener lsnrctl status     # still shows services... for now
```

⏳ Registrations don't vanish instantly — the listener drops them when PMON's
next refresh doesn't renew them, or immediately if you bounce the listener:

```powershell
docker compose restart listener
```

Now reproduce the victim's experience:

```powershell
docker compose exec oracle-db sqlplus hr/hr@//listener:1521/XEPDB1
```

**❓ Questions**
1. What error do you get now, and how does it differ from Mission 5's?
2. The database is **up** and healthy — prove it, then explain why clients
   still can't connect through the listener host.
3. Repair the system *without restarting any container*.

---

## 🟡 Mission 7 — Deploy + verify over REST

**🎯 Goal:** trace one row of data through every box in the architecture
diagram: deploy script → listener → database → ORDS → your browser.

```powershell
# 1. Deploy the payload from the "Solaris box", through the listener:
docker compose exec listener bash /deploy/deploy.sh

# 2. (first time only) expose HR over REST:
docker compose exec listener bash /deploy/enable-rest.sh

# 3. Read it back over HTTP:
curl http://localhost:8085/ords/hr/reports/headcount
curl http://localhost:8085/ords/hr/employees/200
```

**❓ Questions**
1. List every hop employee #200 took from SQL script to JSON in your terminal.
2. The deploy ran "on the Solaris box" — yet no Oracle database is installed
   there. What two client tools made that possible?
3. The dashboard's headcount and the REST report should agree. Where does each
   one get its number from?

---

## 🔴 Mission 8 — Capstone: launch your own service

**🎯 Goal:** create a brand-new database service, watch it register with the
remote listener, connect through it, then clean up. If you can do this and
explain each step, you understand dynamic registration. 🏆

```powershell
docker compose exec oracle-db sqlplus / as sysdba
```
```sql
ALTER SESSION SET CONTAINER = XEPDB1;
BEGIN
  DBMS_SERVICE.CREATE_SERVICE(service_name => 'payroll', network_name => 'payroll');
  DBMS_SERVICE.START_SERVICE('payroll');
END;
/
ALTER SYSTEM REGISTER;
exit
```

👀 **Watch the dashboard** — a new `payroll` service card appears within
seconds, and the event log records its arrival.

Now connect through it, from the listener host:

```powershell
docker compose exec listener sqlplus hr/hr@//listener:1521/payroll
```

```sql
SELECT SYS_CONTEXT('USERENV','SERVICE_NAME') FROM dual;   -- proof!
exit
```

🧹 Clean up:

```sql
-- as sysdba, in XEPDB1:
BEGIN
  DBMS_SERVICE.STOP_SERVICE('payroll');
  DBMS_SERVICE.DELETE_SERVICE('payroll');
END;
/
ALTER SYSTEM REGISTER;
```

**❓ Questions**
1. You never touched the listener container, yet it now offers `payroll`.
   Explain the exact mechanism.
2. `payroll` and `xepdb1` connect you to the **same PDB**. Why would a real
   shop define multiple services for one database?
3. After `STOP_SERVICE`, when does the listener stop offering `payroll`?

---

## 🚑 Error decoder — the ones you'll actually hit

| Error | Literal meaning | What it tells you | First check |
|-------|-----------------|-------------------|-------------|
| `ORA-12154` | Could not resolve connect identifier | The **name** doesn't resolve — typo, missing `tnsnames.ora` entry, or (in Docker) a stopped container whose DNS entry vanished | Spelling, `tnsnames.ora`, `docker compose ps` |
| `ORA-12541` | No listener | TCP connect refused — host is **up** but **nothing listening** on that port | Is the listener container up? Right port? `docker compose ps` |
| `ORA-12514` | Listener knows no such service | Listener is **up**, but the service never registered (or wrong name) | `lsnrctl status` on the listener — is the service there? |
| `ORA-12505` | Listener knows no such **SID** | You used `SID=` syntax for a service-registered DB | Use `SERVICE_NAME`/EZConnect `…/XEPDB1` instead |
| `ORA-12170` / `TNS-12535` | Connect **timeout** | Packets vanish — firewall / wrong host / network, not Oracle | Can you even `ping`/`tnsping` the host? |
| `ORA-01017` | Invalid username/password | You reached the **database**! Connectivity is fine | Credentials (this lab: `hr`/`hr`) |
| `TNS-01189` | Listener can't authenticate user | Remote `lsnrctl` admin is blocked by design (21c) | Run `lsnrctl` **on** the listener host |
| `TNS-03505` | Failed to resolve name | The alias isn't in `tnsnames.ora` / wrong `TNS_ADMIN` | `tnsping <alias>` and check the file |

💡 **Triage flow:** `12154` → name problem · `12541` → process down ·
`12514` → registration problem · timeout → network problem ·
`01017` → 🎉 everything below you works.

---

## 🏁 Self-assessment

You've mastered this lab when you can answer all of these cold:

- [ ] Why does the listener show services it was never configured with?
- [ ] What's the difference between `ORA-12541` and `ORA-12514`, mechanically?
- [ ] Why does the listener show **zero** services right after *it* restarts,
      even though the database never went down?
- [ ] What does `remote_listener` do, and who reads it?
- [ ] Why does a freshly-started DB take up to ~60s to appear, while
      `ALTER SYSTEM REGISTER` is instant?
- [ ] Why must `lsnrctl status` run *on* the listener host in 21c?

When you've written your answers: **[check them here](SOLUTIONS.md)** ✅

Happy hunting! 🛰️🔭
