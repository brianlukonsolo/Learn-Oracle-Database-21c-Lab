import { useEffect, useRef, useState } from "react";

const POLL_MS = 2500;
const MAX_LOG = 40;

// ----------------------------------------------------------------- helpers
function statusTone(status) {
  const s = (status || "").toUpperCase();
  if (s === "READY") return "ok";
  if (s === "RESTRICTED" || s === "BLOCKED") return "warn";
  return "muted"; // UNKNOWN etc.
}

function fmtTime(iso) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleTimeString();
  } catch {
    return iso;
  }
}

// Hide Oracle's internal 32-hex-char CDB GUID service -- it's noise for
// a teaching dashboard. Everything else (XE, XEPDB1, FREE...) is shown.
function isInternal(name) {
  return /^[0-9a-f]{32}$/i.test(name || "");
}
function visibleServices(listener) {
  return (listener?.services || []).filter((s) => !isInternal(s.name));
}

// Build a comparable signature of what the listener currently knows.
function signature(listener) {
  const map = {};
  if (listener && Array.isArray(listener.services)) {
    for (const svc of listener.services) {
      if (isInternal(svc.name)) continue;
      map[svc.name] = (svc.instances || [])
        .map((i) => `${i.name}:${i.status}`)
        .sort()
        .join(",");
    }
  }
  return map;
}

// Diff two signatures into human-readable change events.
function diffSignatures(prev, next) {
  const events = [];
  const names = new Set([...Object.keys(prev), ...Object.keys(next)]);
  for (const name of names) {
    if (!(name in prev) && name in next) {
      events.push({ kind: "up", text: `Service "${name}" registered with the listener` });
    } else if (name in prev && !(name in next)) {
      events.push({ kind: "down", text: `Service "${name}" dropped off the listener` });
    } else if (prev[name] !== next[name]) {
      events.push({ kind: "change", text: `Service "${name}" instances changed → ${next[name] || "none"}` });
    }
  }
  return events;
}

// ----------------------------------------------------------------- subcomponents
function Pill({ tone, children }) {
  return <span className={`pill pill-${tone}`}>{children}</span>;
}

function FlowNode({ emoji, title, subtitle, tone }) {
  return (
    <div className={`flow-node node-${tone}`}>
      <div className="flow-emoji">{emoji}</div>
      <div className="flow-title">{title}</div>
      <div className="flow-sub">{subtitle}</div>
    </div>
  );
}

function FlowArrow({ label, tone, dashed }) {
  return (
    <div className={`flow-arrow arrow-${tone} ${dashed ? "dashed" : ""}`}>
      <span className="flow-arrow-label">{label}</span>
      <span className="flow-arrow-line" />
    </div>
  );
}

// ----------------------------------------------------------------- app
export default function App() {
  const [data, setData] = useState(null);
  const [fetchOk, setFetchOk] = useState(false);
  const [log, setLog] = useState([]);
  const sigRef = useRef({});
  const prevConnRef = useRef({ listener: null, db: null });

  useEffect(() => {
    let alive = true;

    const pushLog = (events) => {
      if (!events.length) return;
      const stamped = events.map((e) => ({ ...e, at: new Date().toLocaleTimeString() }));
      setLog((old) => [...stamped.reverse(), ...old].slice(0, MAX_LOG));
    };

    const tick = async () => {
      try {
        const res = await fetch(`api/status.json?_=${Date.now()}`, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (!alive) return;
        setData(json);
        setFetchOk(true);

        // listener up/down + db up/down transitions
        const lReach = !!json.listener?.reachable;
        const dReach = !!json.db?.reachable;
        const trans = [];
        if (prevConnRef.current.listener !== null && prevConnRef.current.listener !== lReach) {
          trans.push(
            lReach
              ? { kind: "up", text: "Listener host is reachable again" }
              : { kind: "down", text: "Listener host became unreachable" }
          );
        }
        if (prevConnRef.current.db !== null && prevConnRef.current.db !== dReach) {
          trans.push(
            dReach
              ? { kind: "up", text: "Database reachable through the listener" }
              : { kind: "down", text: "Database unreachable through the listener" }
          );
        }
        prevConnRef.current = { listener: lReach, db: dReach };

        // service registration diff
        const nextSig = signature(json.listener);
        const svcEvents = diffSignatures(sigRef.current, nextSig);
        sigRef.current = nextSig;

        pushLog([...trans, ...svcEvents]);
      } catch (e) {
        if (!alive) return;
        setFetchOk(false);
      }
    };

    tick();
    const id = setInterval(tick, POLL_MS);
    return () => {
      alive = false;
      clearInterval(id);
    };
  }, []);

  const listener = data?.listener;
  const db = data?.db;
  const services = visibleServices(listener);
  const lReach = !!listener?.reachable;
  const dReach = !!db?.reachable;
  const registered = services.length > 0;

  const listenerTone = lReach ? "ok" : "down";
  const dbTone = dReach ? "ok" : "down";
  const regArrowTone = registered ? "ok" : "down";

  return (
    <div className="page">
      <header className="hero">
        <h1>🛰️ Listener&nbsp;↔&nbsp;Database — Live Registration</h1>
        <p className="tagline">
          Watch <strong>PMON</strong> register the database with the listener host in real time.
          Stop the <code>oracle-db</code> container and watch its services disappear. 🔭
        </p>
        <div className="hero-pills">
          <Pill tone={fetchOk ? "ok" : "down"}>
            {fetchOk ? "📡 monitor online" : "📡 monitor offline"}
          </Pill>
          <Pill tone={listenerTone}>{lReach ? "🟢 listener up" : "🔴 listener down"}</Pill>
          <Pill tone={registered ? "ok" : "warn"}>
            {registered ? `🤝 ${services.length} service(s) registered` : "⚠️ no services registered"}
          </Pill>
          <Pill tone={dbTone}>{dReach ? "🟢 DB reachable" : "🔴 DB unreachable"}</Pill>
          <span className="updated">updated {fmtTime(data?.ts)}</span>
        </div>
      </header>

      {/* ----------------------------------------------------------- flow */}
      <section className="card flow-card">
        <h2>🧭 The path a client takes</h2>
        <div className="flow">
          <FlowNode emoji="💻" title="Client" subtitle="sqlplus · ORDS · you" tone="ok" />
          <FlowArrow label="connect :1521" tone={lReach ? "ok" : "down"} />
          <FlowNode
            emoji="🛰️"
            title="listener"
            subtitle={lReach ? listener?.alias || "LISTENER" : "unreachable"}
            tone={listenerTone}
          />
          <FlowArrow label="redirect to instance" tone={regArrowTone} />
          <FlowNode
            emoji="🗄️"
            title="oracle-db"
            subtitle={dReach ? `XEPDB1 · ${db?.headcount} employees` : "down"}
            tone={dbTone}
          />
        </div>
        <div className="registration-strip">
          <span className={`reg-arrow reg-${regArrowTone}`}>
            ⤺ PMON dynamic registration {registered ? "ACTIVE" : "INACTIVE"}
          </span>
          {listener?.uptime && lReach && (
            <span className="reg-meta">listener uptime: {listener.uptime}</span>
          )}
        </div>
      </section>

      <div className="grid">
        {/* --------------------------------------------------- services */}
        <section className="card">
          <h2>🤝 Registered services</h2>
          {!lReach && (
            <p className="empty">
              Listener host unreachable{listener?.error ? ` (${listener.error})` : ""}.
            </p>
          )}
          {lReach && services.length === 0 && (
            <p className="empty">
              The listener is up but no database has registered yet. ⏳
              <br />
              (On a cold start, PMON registers ~60s after the DB opens.)
            </p>
          )}
          <div className="svc-list">
            {services.map((svc) => (
              <div key={svc.name} className="svc">
                <div className="svc-head">
                  <span className="svc-name">{svc.name}</span>
                  <span className="svc-count">
                    {svc.instances.length} instance{svc.instances.length === 1 ? "" : "s"}
                  </span>
                </div>
                <div className="svc-instances">
                  {svc.instances.map((inst) => (
                    <span key={inst.name} className={`badge badge-${statusTone(inst.status)}`}>
                      {inst.name} · {inst.status}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* --------------------------------------------------- details + db */}
        <section className="card">
          <h2>🔎 Listener details</h2>
          <dl className="kv">
            <dt>Alias</dt>
            <dd>{lReach ? listener?.alias || "—" : "—"}</dd>
            <dt>Version</dt>
            <dd className="mono small">{lReach ? listener?.version || "—" : "—"}</dd>
            <dt>Started</dt>
            <dd className="mono small">{lReach ? listener?.start_date || "—" : "—"}</dd>
            <dt>Uptime</dt>
            <dd>{lReach ? listener?.uptime || "—" : "—"}</dd>
          </dl>
          <h2 style={{ marginTop: "1.1rem" }}>🗄️ Database probe (via listener)</h2>
          <dl className="kv">
            <dt>Reachable</dt>
            <dd>{dReach ? "✅ yes" : "❌ no"}</dd>
            <dt>HR headcount</dt>
            <dd>{dReach ? db?.headcount : "—"}</dd>
            {!dReach && db?.error && (
              <>
                <dt>Error</dt>
                <dd className="mono small">{db.error}</dd>
              </>
            )}
          </dl>
        </section>
      </div>

      {/* ----------------------------------------------------------- log */}
      <section className="card">
        <h2>📜 Registration event log</h2>
        {log.length === 0 ? (
          <p className="empty">
            No changes observed yet. Try <code>docker compose stop oracle-db</code> in another
            terminal and watch this fill up. 🪄
          </p>
        ) : (
          <ul className="log">
            {log.map((e, i) => (
              <li key={i} className={`log-${e.kind}`}>
                <span className="log-at">{e.at}</span>
                <span className="log-dot">{e.kind === "up" ? "🟢" : e.kind === "down" ? "🔴" : "🟡"}</span>
                <span className="log-text">{e.text}</span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <footer className="foot">
        Polling <code>api/status.json</code> every {POLL_MS / 1000}s · the JSON is produced by the{" "}
        <code>monitor</code> container running <code>lsnrctl status</code> against the listener host.
        No scripts run on your laptop. 🐳
      </footer>
    </div>
  );
}
