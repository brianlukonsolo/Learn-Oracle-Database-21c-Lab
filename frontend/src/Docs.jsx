import { useEffect, useRef, useState } from "react";
import { marked } from "marked";

// GitHub-style heading slugs so the workbook's own table-of-missions
// anchor links keep working inside the app.
function slugify(text) {
  return text.toLowerCase().replace(/[^\w\s-]/g, "").replace(/\s/g, "-");
}

/**
 * Fetches a markdown file from /docs (mounted read-only into nginx from the
 * repo's docs/ folder) and renders it. The .md files stay the single source
 * of truth -- edit them on disk and refresh, no rebuild needed.
 */
export default function Docs({ file, onNavigate }) {
  const [html, setHtml] = useState(null);
  const [error, setError] = useState(null);
  const ref = useRef(null);

  useEffect(() => {
    let alive = true;
    setHtml(null);
    setError(null);
    fetch(`docs/${file}`, { cache: "no-store" })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.text();
      })
      .then((md) => alive && setHtml(marked.parse(md)))
      .catch((e) => alive && setError(String(e)));
    return () => {
      alive = false;
    };
  }, [file]);

  // After each render: give headings GitHub-compatible ids, and rewrite
  // relative image paths (the .md files use GitHub-relative paths like
  // "architecture.png"; in-app they're served from /docs/).
  useEffect(() => {
    if (!ref.current || html == null) return;
    ref.current
      .querySelectorAll("h1, h2, h3, h4")
      .forEach((h) => (h.id = slugify(h.textContent)));
    ref.current.querySelectorAll("img").forEach((img) => {
      const src = img.getAttribute("src") || "";
      if (src && !/^(https?:|\/|docs\/)/i.test(src)) img.src = `docs/${src}`;
    });
  }, [html]);

  // Map links between the doc files onto tab switches.
  const DOC_TABS = { "INTRO.md": "intro", "EXERCISES.md": "exercises", "SOLUTIONS.md": "solutions" };

  const onClick = (e) => {
    const a = e.target.closest("a");
    if (!a || !ref.current?.contains(a)) return;
    const href = a.getAttribute("href") || "";
    if (href.startsWith("#")) return; // in-page anchor: let the browser scroll
    e.preventDefault();
    const doc = href.match(/(INTRO|EXERCISES|SOLUTIONS)\.md(#|$)/i);
    if (doc) onNavigate(DOC_TABS[`${doc[1].toUpperCase()}.md`]);
    else if (/^https?:/i.test(href)) window.open(href, "_blank", "noopener");
    // other relative links point at repo files (configs, scripts) that only
    // exist in the git checkout -- view those in your editor instead.
  };

  if (error) {
    return (
      <div className="card">
        <p className="empty">
          😕 Couldn't load <code>docs/{file}</code> ({error}). Is the{" "}
          <code>./docs</code> volume mounted? Try{" "}
          <code>docker compose up -d dashboard</code>.
        </p>
      </div>
    );
  }
  if (html == null) return <div className="card"><p className="empty">📖 Loading…</p></div>;

  return (
    <div
      className="card md"
      ref={ref}
      onClick={onClick}
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
