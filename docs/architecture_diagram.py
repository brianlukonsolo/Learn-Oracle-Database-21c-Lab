#!/usr/bin/env python3
"""
Generate the architecture diagram for the Oracle Listener <-> Database Lab.

Usage:
    python docs/architecture_diagram.py

Produces:
    docs/architecture.png

Only dependency is matplotlib:
    pip install matplotlib
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")  # headless / no display needed
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.lines import Line2D

# ---------------------------------------------------------------- palette
INK        = "#1b2430"
HOST_FILL  = "#eef2f7"
HOST_EDGE  = "#9fb3c8"
LISTENER   = "#2f80ed"   # blue   - the listener host
DB         = "#eb5757"   # red    - the database
ORDS       = "#27ae60"   # green  - ORDS / REST
NET_FILL   = "#fbfdff"
SOLID      = "#334155"
REGISTER   = "#9b51e0"   # purple - dynamic registration
DIRECT     = "#94a3b8"   # grey   - direct/bypass paths


def box(ax, x, y, w, h, fill, edge, title, subtitle="", title_color="white",
        sub_color="white", fontsize=12, sub_fontsize=8.5, radius=0.025):
    ax.add_patch(FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.004,rounding_size={radius}",
        linewidth=2.2, edgecolor=edge, facecolor=fill, zorder=3))
    ax.text(x + w / 2, y + h - 0.034, title, ha="center", va="top",
            fontsize=fontsize, fontweight="bold", color=title_color, zorder=4)
    if subtitle:
        ax.text(x + w / 2, y + h - 0.034 - 0.052, subtitle, ha="center", va="top",
                fontsize=sub_fontsize, color=sub_color, zorder=4, linespacing=1.4)


def arrow(ax, p0, p1, color, style="-|>", lw=2.2, ls="-", rad=0.0, alpha=1.0):
    ax.add_patch(FancyArrowPatch(
        p0, p1, arrowstyle=style, mutation_scale=18,
        linewidth=lw, color=color, linestyle=ls, alpha=alpha,
        connectionstyle=f"arc3,rad={rad}", zorder=2,
        shrinkA=4, shrinkB=4))


def label(ax, x, y, text, color=INK, fontsize=8.6, weight="normal",
          bg="white", ha="center"):
    ax.text(x, y, text, ha=ha, va="center", fontsize=fontsize, color=color,
            fontweight=weight, zorder=5,
            bbox=dict(boxstyle="round,pad=0.25", fc=bg, ec="none", alpha=0.92))


fig, ax = plt.subplots(figsize=(12.5, 8.6))
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis("off")
fig.patch.set_facecolor("white")

# ---------------------------------------------------------------- title
ax.text(0.5, 0.965, "Oracle Listener  ↔  Database  Lab",
        ha="center", va="center", fontsize=20, fontweight="bold", color=INK)
ax.text(0.5, 0.927,
        "Listener host and database run as separate containers · the DB registers remotely with the listener",
        ha="center", va="center", fontsize=10.5, color="#52606d")

# ---------------------------------------------------------------- host band
box(ax, 0.06, 0.80, 0.88, 0.085, HOST_FILL, HOST_EDGE,
    "", "", )
ax.text(0.085, 0.842, "YOUR LAPTOP  (host)", ha="left", va="center",
        fontsize=11, fontweight="bold", color=INK, zorder=4)
ax.text(0.085, 0.815, "sqlplus / SQL Developer  →  localhost:1521",
        ha="left", va="center", fontsize=8.7, color="#52606d", zorder=4)
ax.text(0.62, 0.842, "curl / Insomnia / Postman  →  localhost:8085",
        ha="left", va="center", fontsize=8.7, color="#52606d", zorder=4)
ax.text(0.62, 0.815, "DB tools (direct)  →  localhost:1522",
        ha="left", va="center", fontsize=8.7, color="#52606d", zorder=4)

# ---------------------------------------------------------------- containers
# Listener host (the "Solaris box")
box(ax, 0.07, 0.46, 0.30, 0.21, LISTENER, "#1c5fc0",
    "listener", "")
ax.text(0.22, 0.588, "the “Solaris box”", ha="center", va="center",
        fontsize=9, color="white", style="italic", zorder=4)
ax.text(0.22, 0.551, "tnslsnr  :1521", ha="center", va="center",
        fontsize=10, color="white", fontweight="bold", zorder=4)
ax.text(0.22, 0.516, "NO database here", ha="center", va="center",
        fontsize=8.6, color="#dbe7ff", zorder=4)
ax.text(0.22, 0.486, "runs  deploy.sh  >", ha="center", va="center",
        fontsize=8.3, color="#dbe7ff", zorder=4)

# ORDS
box(ax, 0.63, 0.46, 0.30, 0.21, ORDS, "#1d8049",
    "ords", "")
ax.text(0.78, 0.582, "Oracle REST Data Services", ha="center", va="center",
        fontsize=8.8, color="white", zorder=4)
ax.text(0.78, 0.543, "REST API  :8080", ha="center", va="center",
        fontsize=10, color="white", fontweight="bold", zorder=4)
ax.text(0.78, 0.505, "/ords/hr/employees ...", ha="center", va="center",
        fontsize=8.4, color="#d8f5e3", zorder=4)

# Database
box(ax, 0.27, 0.12, 0.46, 0.20, DB, "#c0392b",
    "oracle-db", "")
ax.text(0.50, 0.238, "Oracle Database XE 21c", ha="center", va="center",
        fontsize=9.2, color="white", zorder=4)
ax.text(0.50, 0.202, "CDB: XE      PDB: XEPDB1      schema: HR",
        ha="center", va="center", fontsize=9, color="white",
        fontweight="bold", zorder=4)
ax.text(0.50, 0.158, "PMON  -- registers services -->  the listener host",
        ha="center", va="center", fontsize=8.4, color="#ffe0db", zorder=4)

# ---------------------------------------------------------------- arrows
# 1) host -> listener  (client connect)
arrow(ax, (0.155, 0.80), (0.175, 0.67), SOLID)
label(ax, 0.135, 0.735, "1  connect\nSERVICE=XEPDB1", color=SOLID, fontsize=8.0)

# 2) listener -> db  (redirect to registered instance)
arrow(ax, (0.205, 0.46), (0.345, 0.32), SOLID, rad=-0.12)
label(ax, 0.225, 0.385, "2  redirect to\nregistered instance", color=SOLID,
      fontsize=8.0)

# 3) db -> listener  (PMON dynamic registration)  -- dashed purple
arrow(ax, (0.40, 0.32), (0.275, 0.46), REGISTER, ls=(0, (5, 3)), rad=0.18, lw=2.0)
label(ax, 0.405, 0.405, "remote_listener\nPMON registration", color=REGISTER,
      fontsize=8.0)

# 4) host -> ords  (HTTP)
arrow(ax, (0.79, 0.80), (0.79, 0.67), ORDS)
label(ax, 0.79, 0.735, "HTTP :8085", color="#1d8049", fontsize=8.2)

# 5) ords -> listener  (ords connects to DB THROUGH the listener host)
arrow(ax, (0.63, 0.535), (0.37, 0.555), SOLID, rad=0.0)
label(ax, 0.50, 0.575, "SQL via listener host (DBHOST=listener)", color=SOLID,
      fontsize=8.0)

# 6) host -> db direct (bypass, dashed grey)
arrow(ax, (0.70, 0.80), (0.66, 0.32), DIRECT, ls=(0, (4, 3)), rad=0.10, lw=1.8)
label(ax, 0.605, 0.405, "direct\n:1522", color="#64748b", fontsize=7.8)

# ---------------------------------------------------------------- legend
legend_items = [
    Line2D([0], [0], color=SOLID, lw=2.4, label="Oracle Net client traffic"),
    Line2D([0], [0], color=REGISTER, lw=2.2, ls="--",
           label="Dynamic service registration (DB → listener)"),
    Line2D([0], [0], color=DIRECT, lw=2.0, ls="--",
           label="Direct DB access (bypasses listener)"),
]
ax.legend(handles=legend_items, loc="lower center", ncol=3,
          bbox_to_anchor=(0.5, -0.02), frameon=False, fontsize=9)

out = Path(__file__).resolve().parent / "architecture.png"
fig.savefig(out, dpi=200, bbox_inches="tight", facecolor="white")
print(f"Wrote {out}")
