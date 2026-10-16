#!/usr/bin/env python3
"""Builds the player guide's generated parts from CURRENT game data.

    godot --headless --path game -s res://tools/guide_data.gd -- /tmp/guide_data.json
    python3 tools/build_guide_appendix.py /tmp/guide_data.json

Writes:
  docs/TINY_STREET_PLAYER_GUIDE.md        guide source (docs/guide_src/player_guide.md)
                                          + the level reference appendix
  docs/TINY_STREET_SOLUTIONS_APPENDIX.md  spoilers: verified walkthroughs

Every level, page and challenge comes from the exported data (which the Godot
tool reads from the shipped JSON and replays with the real rules), so nothing
is omitted or invented. Display names use the English UI strings.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from strings_en import EN  # noqa: E402

NAMES = {"mira": "Mira", "theo": "Theo", "basil": "Mr. Basil"}
for k in range(6):
    NAMES["n%d" % k] = EN.get("name_n%d" % k, "n%d" % k)

GOALS = {"win": EN["goal_win"], "three": EN["goal_three"], "no_hint": EN["goal_no_hint"], "no_undo": EN["goal_no_undo"]}
TUT = {"tut_tap": "Tutorial: tapping crates", "tut_counter": "Tutorial: the counter", "tut_priority": "Tutorial: which order gets an item",
       "tut_fresh": "Introduces fresh (hot) items", "tut_bag": "Introduces paper bags", "tut_lock": "Introduces strapped crates",
       "tut_two_stage": "Introduces two-part orders", "tut_bell": "Introduces the bell", "tut_oven": "Introduces the oven"}


def objective(e):
    o = "Serve %d orders" % e["orders"]
    o += " · %d ticket%s · counter %d" % (e["trays"], "" if e["trays"] == 1 else "s", e["counter"])
    return o


def rules(e, bakery=False):
    r = []
    if e.get("tutorial"):
        r.append(TUT.get(e["tutorial"], e["tutorial"]))
    if e["fresh"]:
        r.append("%d fresh item%s" % (e["fresh"], "" if e["fresh"] == 1 else "s"))
    if e["bags"]:
        r.append("%d paper bag%s" % (e["bags"], "" if e["bags"] == 1 else "s"))
    for c, n in e["locks"]:
        r.append(("oven" if bakery else "strapped crate") + " %d opens after %d order%s" % (c, n, "" if n == 1 else "s"))
    if e["two_stage"]:
        r.append("%d two-part order%s" % (e["two_stage"], "" if e["two_stage"] == 1 else "s"))
    if e["special"]:
        rw = e["special"]["reward"]
        nice = {"extra:chalkboard": "chalkboard for the café", "unlock:bakery": "opens Mira's Bakery",
                "extra:breadbasket": "bread basket for the café"}.get(rw, rw)
        r.append("special order from %s (reward: %s)" % (NAMES.get(e["special"]["customer"], e["special"]["customer"]), nice))
    if not e["bell"]:
        r.append("bell not available")
    if e["bell_budget"] >= 0:
        r.append("bell budget %d" % e["bell_budget"])
    if e["sequence"]:
        r.append("serve in order: " + " → ".join(NAMES.get(x, x) for x in e["sequence"]))
    return "; ".join(r) if r else "—"


def actions(sol):
    out = []
    for a in sol:
        out.append("B%d" % (-a) if a < 0 else str(a + 1))
    # compress runs: 1 1 1 -> 1×3
    comp = []
    k = 0
    while k < len(out):
        j = k
        while j + 1 < len(out) and out[j + 1] == out[k]:
            j += 1
        n = j - k + 1
        comp.append(out[k] + ("×%d" % n if n > 1 else ""))
        k = j + 1
    return " ".join(comp)


def build(data_path):
    d = json.load(open(data_path))
    ver = d["version"]
    camp = d["campaign"]
    lines = []
    A = lines.append
    A("# Appendix A: Every level and page")
    A("")
    A("Generated from the game's level files for version **%s** (`tools/build_guide_appendix.py`). "
      "Campaign %d levels, Mira's Bakery %d, Daily/Rush pool %d, challenge cards %d, Midnight Ledger %d pages." % (
          ver, len(camp), len(d["bakery"]), len(d["daily"]), len(d["challenges"]), len(d["ledger"])))
    A("")
    A("Columns: **Objective** counts orders, order tickets on screen at once, and counter spaces. **Special rules** names the mechanics "
      "the level uses. Unlock conditions follow the game's rules: campaign levels open one after another; bakery levels open one after another "
      "once the bakery is open; ledger lessons open in order, puzzles after the three lessons, and the final page after any six puzzles.")
    A("")
    A("## Campaign")
    A("")
    for ch in d["chapters"]:
        A("### %s (levels %d–%d)" % (EN.get(ch["title"], ch["title"]), ch["first"], ch["last"]))
        A("")
        A("| ID | Display name | Mode | Objective | Special rules | Unlock condition |")
        A("|---|---|---|---|---|---|")
        for e in camp[ch["first"] - 1:ch["last"]]:
            unlock = "Available from the start" if e["n"] == 1 else "Clear level %d" % (e["n"] - 1)
            A("| %s | Level %d | Campaign | %s | %s | %s |" % (e["id"], e["n"], objective(e), rules(e), unlock))
        A("")
    A("## Mira's Bakery")
    A("")
    A("The bakery opens when you serve Mira's special order in level %d (p12). Bakery levels use the campaign rules plus ovens." %
      next(e["n"] for e in camp if e["id"] == "p12"))
    A("")
    A("| ID | Display name | Mode | Objective | Special rules | Unlock condition |")
    A("|---|---|---|---|---|---|")
    for e in d["bakery"]:
        unlock = "Bakery open" if e["n"] == 1 else "Clear Bakery %d" % (e["n"] - 1)
        A("| %s | Bakery %d | Bakery | %s | %s | %s |" % (e["id"], e["n"], objective(e), rules(e, True), unlock))
    A("")
    A("## Challenge cards")
    A("")
    p01 = next(e["n"] for e in camp if e["id"] == "p01")
    A("Challenge cards open after level %d (the bell lesson). Each card replays one puzzle from the Daily pool with one goal; "
      "its token reward is paid once." % p01)
    A("")
    A("| ID | Display name | Mode | Objective | Special rules | Unlock condition |")
    A("|---|---|---|---|---|---|")
    dmap = {e["id"]: e for e in d["daily"]}
    for c in d["challenges"]:
        e = dmap[c["level"]]
        goal = EN["goal_tidy"] % c["tidy_target"] if c["goal"] == "tidy" else GOALS[c["goal"]]
        A("| %s | Challenge %d | Challenge card (puzzle %s) | %s; goal: %s; reward %d tokens | %s | Clear level %d |" % (
            c["id"], int(c["id"][2:]), c["level"], objective(e), goal, c["reward"], rules(e), p01))
    A("")
    A("## Daily puzzle and Café Rush pool")
    A("")
    A("The **Daily** puzzle is chosen from this pool by the device's local date (everyone on the same version gets the same puzzle on "
      "the same date). **Café Rush** plays 3 different puzzles from the same pool, picked at random each run. Both are available "
      "from the Challenges screen at any time; the pool itself never changes during play.")
    A("")
    A("| ID | Display name | Mode | Objective | Special rules | Unlock condition |")
    A("|---|---|---|---|---|---|")
    for e in d["daily"]:
        A("| %s | Daily Challenge / Rush | Daily pool | %s | %s | Picked by date (Daily) or at random (Rush) |" % (e["id"], objective(e), rules(e)))
    A("")
    A("## The Midnight Ledger")
    A("")
    A("The ledger opens after level %d. It pays no tokens. Each page's rules are shown on its rule card (book icon)." % p01)
    A("")
    A("| ID | Display name | Mode | Objective | Special rules | Unlock condition |")
    A("|---|---|---|---|---|---|")
    for e in d["ledger"]:
        grp = e["group"]
        mode = {"lesson": "Ledger lesson", "puzzle": "Ledger puzzle", "final": "Ledger final page"}[grp]
        if grp == "lesson":
            unlock = "Ledger open" if e["n"] == 1 else "Stamp page %d" % (e["n"] - 1)
        elif grp == "puzzle":
            unlock = "Stamp all 3 lessons"
        else:
            unlock = "Stamp any 6 puzzles"
        extra = rules(e)
        if e["precision_target"]:
            extra += "; precision badge at %d moves" % e["precision_target"]
        A("| %s | %s | %s | %s | %s | %s |" % (e["id"], EN.get(e["name"], e["name"]), mode, objective(e) + ". " + EN.get(e["tagline"], ""), extra, unlock))
    A("")
    guide_src = open(os.path.join(ROOT, "docs", "guide_src", "player_guide.md"), encoding="utf-8").read()
    guide = guide_src.replace("<!-- version -->", ver).replace("<!-- appendix -->", "\n".join(lines))
    open(os.path.join(ROOT, "docs", "TINY_STREET_PLAYER_GUIDE.md"), "w", encoding="utf-8").write(guide)

    # ---------------------------------------------------------------- solutions
    S = []
    W = S.append
    W("# Tiny Street: Solutions Appendix (spoilers)")
    W("")
    W("<!-- subtitle: Verified walkthroughs for every level and ledger page · game version %s · SPOILERS -->" % ver)
    W("")
    W("> **Spoilers.** This appendix gives a complete solution for every puzzle in the game. The main player guide is spoiler-free; "
      "read this only when you are stuck or want to compare routes.")
    W("")
    W("## How to read a walkthrough")
    W("")
    W("- A number is one tap on that crate, counting crates **from left to right** as they appear in the English layout "
      "(in Arabic the row is mirrored, so count from the right).")
    W("- `B1`, `B2`, `B3` means ring the bell on order ticket 1, 2 or 3 (tickets show their number in the corner).")
    W("- `2×3` means tap crate 2 three times in a row.")
    W("- **Verified** means the route was replayed through the game's own rules for this version and finishes the level. "
      "It is *one* working route, not necessarily the shortest or the tidiest. The stars column is what this exact route earns "
      "with no undo; a different route can earn more.")
    W("- Midnight Ledger routes are the ledger's **proven reference solutions**: each uses the proven minimum number of bell rings, "
      "and because every solution taps each item exactly once, also the minimum number of moves.")
    W("")
    W("Generated from game data for version %s by `tools/build_guide_appendix.py`." % ver)
    W("")

    def table(title, rows, kind):
        W("## " + title)
        W("")
        W("| ID | Name | Verified | Moves | Peak counter | Stars | Walkthrough |")
        W("|---|---|---|---|---|---|---|")
        for name, e in rows:
            ok = "yes" if e["solution_won"] else "**NO**"
            W("| %s | %s | %s | %d | %d | %d | %s |" % (e["id"], name, ok, e["solution_moves"], e["solution_peak"],
                                                       e["solution_stars"], actions(e["solution"])))
        W("")

    table("Campaign", [("Level %d" % e["n"], e) for e in camp], "campaign")
    table("Mira's Bakery", [("Bakery %d" % e["n"], e) for e in d["bakery"]], "bakery")
    table("Daily / Rush pool (also covers the challenge cards)", [(e["id"], e) for e in d["daily"]], "daily")
    W("## The Midnight Ledger")
    W("")
    W("| ID | Page | Verified | Moves | Bell rings (proven minimum) | Walkthrough |")
    W("|---|---|---|---|---|---|")
    for e in d["ledger"]:
        ok = "yes" if e["solution_won"] and e["witness_replay"] else "**NO**"
        mr = "%d%s" % (e["min_rings"], " (proved)" if e["min_rings_proved"] else " (not proved)")
        W("| %s | %s | %s | %d | %s | %s |" % (e["id"], EN.get(e["name"], e["name"]), ok, e["solution_moves"], mr, actions(e["solution"])))
    W("")
    W("The reasoning behind each ledger page is in the game (*Why this works*, after you finish a page) and in "
      "`docs/EXPERT_SOLUTIONS_SPOILERS.md`.")
    W("")
    open(os.path.join(ROOT, "docs", "TINY_STREET_SOLUTIONS_APPENDIX.md"), "w", encoding="utf-8").write("\n".join(S))
    bad = [e["id"] for k in ("campaign", "bakery", "daily", "ledger") for e in d[k] if not e["solution_won"]]
    print("guide appendix: %d campaign, %d bakery, %d daily, %d challenges, %d ledger; unverified routes: %s" % (
        len(camp), len(d["bakery"]), len(d["daily"]), len(d["challenges"]), len(d["ledger"]), bad or "none"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(build(sys.argv[1]))
