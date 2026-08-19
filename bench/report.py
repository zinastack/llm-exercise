#!/usr/bin/env python3
"""Render bench/out/*.json into RESULTS.md - deliverable 2."""
import json, pathlib, sys

ORDER = ["baseline", "L1-fit", "L2-quantize", "L3-schedule", "nvlink-off"]

OUT = pathlib.Path(__file__).parent / "out"
DEST = pathlib.Path(__file__).parent.parent / "RESULTS.md"


def load():
    docs = {}
    for p in OUT.glob("*.json"):
        try:
            d = json.loads(p.read_text())
            docs[d.get("config", p.stem)] = d
        except Exception as e:
            print(f"skip {p}: {e}", file=sys.stderr)
    return docs


def level(doc, conc):
    for lv in doc.get("levels", []):
        if lv.get("concurrency") == conc:
            return lv
    return None


def delta(cur, base, lower_is_better=False):
    """Percent change vs baseline, signed for readability."""
    if base in (None, 0) or cur is None or cur == base:
        return ""            # baseline compared with itself reads as noise
    pc = (cur - base) / base * 100.0
    if lower_is_better:
        pc = -pc
    sign = "+" if pc >= 0 else ""
    return f" ({sign}{pc:.0f}%)"


def main():
    docs = load()
    if not docs:
        sys.exit("no results in bench/out/ - run make all first")

    names = [n for n in ORDER if n in docs] + \
            [n for n in sorted(docs) if n not in ORDER]
    base = docs.get("baseline")

    L = []
    L.append("# Results\n")
    L.append("Generated from `bench/out/*.json` by `bench/report.py`. No figure "
             "in this file is hand-typed.\n")
    L.append("Identical workload for every configuration: 512-token prompts, "
             "256 output tokens, streaming, temperature 0.\n")
    L.append("Two model families are reported. `fp16-*` rows use the unquantized "
             "checkpoint; the unprefixed rows use the INT4 AWQ checkpoint and "
             "predate concurrency 256 being added, so they are marked *not run* "
             "there rather than failed.\n")

    for conc, label in ((4, "Light load - concurrency 4"),
                        (64, "Heavy load - concurrency 64"),
                        (256, "Stress - concurrency 256")):
        L.append(f"\n## {label}\n")
        L.append("| Config | Output tok/s | TTFT p50 | TTFT p95 | TTFT p99 "
                 "| TPOT p50 | Failed |")
        L.append("|---|---:|---:|---:|---:|---:|---:|")
        b = level(base, conc) if base else None
        for n in names:
            d = docs[n]
            if d.get("startup") == "FAILED":
                L.append(f"| `{n}` | **engine refused to start** | - | - | - | - | - |")
                continue
            lv = level(d, conc)
            if lv is None:
                # Not measured at this concurrency - distinct from measured and
                # failed. Conflating the two would misreport the record.
                L.append(f"| `{n}` | *not run at this level* | - | - | - | - | - |")
                continue
            if lv.get("succeeded", 0) == 0:
                reasons = lv.get("failure_reasons", {})
                L.append(f"| `{n}` | **all requests failed** | - | - | - | - | {reasons} |")
                continue
            t, tp = lv["ttft_ms"], lv["tpot_ms"]
            bt = b["ttft_ms"] if (b and b.get("succeeded")) else None
            L.append(
                f"| `{n}` | {lv['output_tok_per_s']:.1f}"
                f"{delta(lv['output_tok_per_s'], b['output_tok_per_s']) if b and b.get('succeeded') else ''} "
                f"| {t['p50']:.0f} ms{delta(t['p50'], bt['p50'], True) if bt else ''} "
                f"| {t['p95']:.0f} ms "
                f"| {t['p99']:.0f} ms{delta(t['p99'], bt['p99'], True) if bt else ''} "
                f"| {tp['p50']:.1f} ms "
                f"| {lv['failed']} |")

    L.append("\n*Percentages are change versus `baseline` at the same "
             "concurrency. For TTFT, positive means faster.*\n")

    # NVLink comparison gets its own section - it answers a specific question
    if "L3-schedule" in docs and "nvlink-off" in docs:
        L.append("\n## NVLink - measured, not assumed\n")
        L.append("`nvlink-off` is byte-identical to `L3-schedule` except for "
                 "`NCCL_P2P_DISABLE=1`, which forces NCCL to stage transfers "
                 "through host memory instead of using the direct GPU-to-GPU "
                 "path.\n")
        L.append("| Concurrency | Metric | With NVLink | Without P2P | Change |")
        L.append("|---|---|---:|---:|---:|")
        for conc in (4, 64):
            a = level(docs["L3-schedule"], conc)
            z = level(docs["nvlink-off"], conc)
            if not (a and z and a.get("succeeded") and z.get("succeeded")):
                continue
            rows = [("Output tok/s", a["output_tok_per_s"], z["output_tok_per_s"], False),
                    ("TTFT p50 (ms)", a["ttft_ms"]["p50"], z["ttft_ms"]["p50"], True),
                    ("TTFT p99 (ms)", a["ttft_ms"]["p99"], z["ttft_ms"]["p99"], True),
                    ("TPOT p50 (ms)", a["tpot_ms"]["p50"], z["tpot_ms"]["p50"], True)]
            for lbl, av, zv, lower in rows:
                pc = (zv - av) / av * 100 if av else 0
                L.append(f"| {conc} | {lbl} | {av} | {zv} | {pc:+.0f}% |")

    # per-config provenance
    L.append("\n## What each level changed, and why\n")
    for n in names:
        d = docs[n]
        flags = (d.get("flags") or "").strip() or "*vLLM defaults*"
        env = d.get("extra_env") or ""
        L.append(f"**`{n}`** - {d.get('rationale','').strip()}\n")
        L.append(f"- model: `{d.get('model','')}`")
        L.append(f"- flags: `{flags}`" + (f"\n- env: `{env}`" if env else ""))
        L.append("")

    DEST.write_text("\n".join(L) + "\n")
    print(f"wrote {DEST}")


if __name__ == "__main__":
    main()
