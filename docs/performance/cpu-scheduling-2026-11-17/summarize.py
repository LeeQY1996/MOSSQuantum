#!/usr/bin/env python3
"""Validate CPU scheduling calibration and paired observations (Python 3.11+)."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import tomllib

STAGES = ("before", "candidate", "after")
GROUPS = ("public", "raw", "rotations", "cnots")
CHANGED = {"src/utils/parallel_for.jl", "src/backends/cpu/gates/batch.jl",
    "src/backends/cpu/gates/threaded_short_range.jl", "src/backends/cpu/gates/specific/cz_gate.jl",
    "src/backends/cpu/gates/specific/phase_gate.jl", "src/backends/cpu/gates/specific/swap_gates.jl",
    "src/execution/batch_density_gates.jl"}
DRIVERS = ("cpu_gap_diagnostics.jl", "cpu_schedule_calibration.jl", "cpu_thread_scan.jl")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return tomllib.loads(path.read_text())


def affinity(value):
    text = value.split(":", 1)[-1].replace("\\t", "").strip()
    cpus = []
    for item in text.split(","):
        if "-" in item:
            first, last = map(int, item.split("-"))
            require(0 <= first <= last, "invalid CPU range")
            cpus.extend(range(first, last + 1))
        else:
            cpus.append(int(item))
    require(cpus and len(cpus) == len(set(cpus)) and min(cpus) >= 0, "invalid CPU allocation")
    return sorted(cpus)


def resources(value):
    cpus = affinity(value["cpuset"])
    require(affinity(value["affinity"]) == cpus, "process affinity and cpuset differ")
    return cpus


def stats(entry, count):
    values = entry["seconds"]
    require(len(values) == count and all(finite(x) and x > 0 for x in values), "invalid timing samples")
    result = {"samples": values, "median_seconds": statistics.median(values),
              "minimum_seconds": min(values), "maximum_seconds": max(values), "repetitions": count}
    for key in ("median_seconds", "minimum_seconds", "maximum_seconds"):
        if key in entry:
            require(finite(entry[key]) and math.isclose(entry[key], result[key], rel_tol=1e-12), f"incorrect {key}")
    for key in ("allocated_bytes", "gc_seconds"):
        if key in entry:
            require(len(entry[key]) == count and all(finite(x) and x >= 0 for x in entry[key]), f"invalid {key}")
            result[key] = entry[key]
            result[f"median_{key}"] = statistics.median(entry[key])
    return result


def correctness(check, n):
    require(check["amplitudes_checked"] == 2**n and
            all(finite(check[key]) and 0 <= check[key] < 1e-10 for key in
                ("relative_l2_error", "maximum_amplitude_error")) and
            all(finite(check[key]) and abs(check[key] - 1) < 1e-8 for key in
                ("reference_norm_squared", "actual_norm_squared")), "old-reference comparison failed")


def summarize(directory):
    source_maps, observations, raw_files = {}, [], {}
    cpu_allocation, software, drivers = None, None, None
    baseline_records = {}
    for stage in STAGES:
        thread_counts = (1, 8, 16) if stage != "after" else (1, 2, 4, 8, 16)
        names = [f"calibration-{threads}.toml" for threads in thread_counts] + ["calibration-25-16.toml"]
        for name in names:
            path = directory / stage / name
            record = load(path)
            require(record.get("complete") is True and record["mode"] == ("write" if stage == "before" else "check"),
                    f"{stage}/{name}: incomplete or wrong measurement mode")
            cpus = resources(record["resource_before"])
            cpu_allocation = cpu_allocation or cpus
            require(cpus == cpu_allocation and resources(record["resource_after"]) == cpus,
                    "CPU allocation changed across calibration measurements")
            current = {key: record[key] for key in ("scalar", "julia_version", "mossquantum_version", "blas_threads")}
            software = software or current
            require(current == software and record["scalar"] == "ComplexF64" and record["blas_threads"] == 1,
                    "software or precision changed")
            threads = 16 if name == "calibration-25-16.toml" else int(name.removeprefix("calibration-").removesuffix(".toml"))
            require(record["threads"] == threads, "thread count differs from filename")
            expected = {(25, 10)} if "25-16" in name else {(15, 20), (20, 20)}
            require(len(record["cases"]) == len(expected) and
                    {(case["qubits"], case["depth"]) for case in record["cases"]} == expected, "wrong calibration cases")
            count = 3 if "25-16" in name else 5
            require(record["repetitions"] == count, "unexpected repetition count")
            source_map = record["core_source_sha256"]
            source_maps.setdefault(stage, source_map)
            require(source_map == source_maps[stage] and source_map, "stage mixes core source versions")
            for source, expected_sha in source_map.items():
                relative = Path(source)
                require(relative.parts[0] == "src" and ".." not in relative.parts and
                        sha(directory / stage / "source" / relative.relative_to("src")) == expected_sha,
                        f"{stage}: core source fingerprint differs: {source}")
            drivers = drivers or record["diagnostic_source_sha256"]
            require(record["diagnostic_source_sha256"] == drivers and set(drivers) == set(DRIVERS),
                    "calibration driver changed")
            for source, expected_sha in drivers.items():
                require(sha(directory / "benchmark-source" / source) == expected_sha, "diagnostic source fingerprint differs")
            raw_files[str(path.relative_to(directory))] = sha(path)
            for case in record["cases"]:
                n, depth = case["qubits"], case["depth"]
                require(case["gates"] == depth * (2*n - 1), "changed circuit gate count")
                baseline = directory / Path(record["baseline_directory"]).name / case["reference_metadata"]
                reference = load(baseline)
                require(sha(baseline) == case["reference_metadata_sha256"] and
                        re.fullmatch(r"[0-9a-f]{64}", reference["sha256"]) and
                        reference["sha256"] == case["reference_sha256"] and reference["scalar"] == "ComplexF64" and
                        reference["qubits"] == n and reference["depth"] == depth and reference["bytes"] == 16 * 2**n and
                        reference["core_source_sha256"] == source_maps["before"], "old reference provenance differs")
                require(baseline.parent.name == f"baseline-{reference['created_threads']}", "baseline thread metadata differs")
                angles = reference["angles_by_layer"]
                require(len(angles) == depth and all(len(row) == n and all(finite(x) for x in row) for row in angles),
                        "invalid baseline angles")
                key = (n, depth)
                if key in baseline_records:
                    require(baseline_records[key]["angles_by_layer"] == angles and
                            baseline_records[key]["sha256"] == reference["sha256"], "thread configurations use different reference states")
                baseline_records[key] = reference
                for group in GROUPS:
                    entry = case[group]
                    require(all(field in entry for field in ("minimum_seconds", "maximum_seconds", "allocated_bytes", "gc_seconds")),
                            "incomplete timing or allocation evidence")
                    require(resources(entry["resource_before"]) == cpus == resources(entry["resource_after"]),
                            "CPU allocation changed within a group")
                    if group in ("public", "raw"):
                        correctness(entry["correctness"], n)
                    observations.append({"stage": stage, "threads": threads, "qubits": n, "depth": depth,
                        "group": group, **stats(entry, count), "raw_file": str(path.relative_to(directory)),
                        "reference_sha256": reference["sha256"], "reference_metadata": str(baseline.relative_to(directory)),
                        "correctness": entry.get("correctness"), "started_at_utc": record["started_at_utc"],
                        "finished_at_utc": record["finished_at_utc"]})
    require(all(set(mapping) == set(source_maps["before"]) for mapping in source_maps.values()), "core source file set changed")
    for stage in ("candidate", "after"):
        changed = {name for name, digest in source_maps[stage].items() if digest != source_maps["before"][name]}
        require(changed == CHANGED, f"{stage}: unexpected production files changed")
    old_rows = {(row["threads"], row["qubits"], row["depth"], row["group"]): row
                for row in observations if row["stage"] == "before"}
    for row in observations:
        old = old_rows.get((row["threads"], row["qubits"], row["depth"], row["group"]))
        row["before_median_seconds"] = old["median_seconds"] if old else None
        row["before_over_current"] = old["median_seconds"] / row["median_seconds"] if old else None

    sweep_path = directory / "task-sweep.toml"
    sweep = load(sweep_path)
    require(sweep.get("complete") is True and affinity(sweep["affinity_before"]) == cpu_allocation ==
            affinity(sweep["affinity_after"]), "task-sweep allocation or completion differs")
    expected_sweep = {(n, group, tasks) for n in (15, 20, 25) for group in ("rotations", "cnots")
                      for tasks in ((1, 2, 4, 8, 16) if n != 25 else (4, 8, 16))}
    require(len(sweep["cases"]) == len(expected_sweep) and
            {(c["qubits"], c["kind"], c["tasks"]) for c in sweep["cases"]} == expected_sweep,
            "missing or duplicate task-sweep configuration")
    sweep_rows = [{"qubits": c["qubits"], "depth": c["depth"], "group": c["kind"], "tasks": c["tasks"],
                   **stats(c, 5)} for c in sweep["cases"]]
    raw_files[sweep_path.name] = sha(sweep_path)

    paired = []
    paired_cases = {(15, 20, "public"), (15, 20, "cnots_raw"), (20, 20, "public"), (25, 10, "public")}
    for name, script, shared in (("paired-16.toml", "paired_separate_buffers.jl", False),
                                  ("paired-shared-16.toml", "paired_shared_buffer.jl", True)):
        path = directory / name
        record = load(path)
        require(record.get("complete") is True and record["threads"] == 16 and
                affinity(record["affinity_before"]) == cpu_allocation == affinity(record["affinity_after"]),
                "paired measurement incomplete or changed allocation")
        require(("one shared state buffer" in record["measurement"]) == shared,
                "paired buffer methodology differs")
        require(len(record["cases"]) == len(paired_cases) and
                {(c["qubits"], c["depth"], c["kind"]) for c in record["cases"]} == paired_cases,
                "paired cases are missing or duplicated")
        script_sha = sha(directory / "benchmark-source" / script)
        raw_files[name] = sha(path)
        for case in record["cases"]:
            require(finite(case["l2_error"]) and 0 <= case["l2_error"] < 1e-10, "paired full-state comparison failed")
            entry = {"experiment": "shared_buffer" if shared else "separate_buffers", "qubits": case["qubits"],
                "depth": case["depth"], "group": case["kind"], "threads": 16, "raw_file": name,
                "driver": script, "driver_sha256": script_sha, "l2_error": case["l2_error"]}
            for stage in ("before", "after"):
                entry[stage] = stats({"seconds": case[f"{stage}_seconds"],
                                      "median_seconds": case[f"{stage}_median_seconds"]}, 7)
            entry["before_over_after"] = entry["before"]["median_seconds"] / entry["after"]["median_seconds"]
            entry["paired_before_over_after_samples"] = [old / new for old, new in
                zip(entry["before"]["samples"], entry["after"]["samples"])]
            entry["paired_ratio_median"] = statistics.median(entry["paired_before_over_after_samples"])
            entry["after_slower_pairs"] = sum(ratio < 1 for ratio in entry["paired_before_over_after_samples"])
            paired.append(entry)

    auxiliary_path = directory / "before" / "moss-16.toml"
    auxiliary = load(auxiliary_path)
    require(auxiliary.get("complete") is True and auxiliary["threads"] == 16 and
            affinity(auxiliary["affinity_before"]) == cpu_allocation == affinity(auxiliary["affinity_after"]),
            "auxiliary diagnostic incomplete or changed allocation")
    raw_files[str(auxiliary_path.relative_to(directory))] = sha(auxiliary_path)
    auxiliary_samples = sum(stats(case[group], 7)["repetitions"] for case in auxiliary["cases"]
                            for group in GROUPS if group in case)
    tests = {}
    for name, expected in (("scheduling-1.log", 261), ("scheduling-4.log", 263),
                           ("scheduling-julia-1.13.3-16.log", 263),
                           ("scheduling-julia-1.10.13-16.log", 263), ("core-tests-4.log", 13391)):
        path = directory / "tests" / name
        entries = []
        for line in path.read_text().splitlines():
            if "|" in line:
                fields = line.rsplit("|", 1)[1].split()
                if len(fields) == 3 and fields[0].isdigit() and fields[1].isdigit():
                    entries.append((int(fields[0]), int(fields[1])))
        require(entries and all(passed == total for passed, total in entries) and
                sum(passed for passed, _ in entries) == expected, f"{name}: missing or failed test assertions")
        tests[name] = {"assertions_passed": expected, "testsets": len(entries), "sha256": sha(path)}
    test_sources = {}
    for archive, source in (("parallel_scheduling.jl", "test/unit/parallel_scheduling.jl"),
                             ("runtests.jl", "test/runtests.jl")):
        digest = sha(directory / "tests" / archive)
        require(digest == sha(directory.parents[2] / source), "archived test source differs from current repository")
        test_sources[source] = digest
    require(sum(row["repetitions"] for row in observations) == 476 and len(observations) == 100 and
            auxiliary_samples == 84, "unexpected calibration/auxiliary sample coverage")
    return {"metadata": {"software": software, "cpu_affinity": cpu_allocation,
                         "measurement": "CF64 CPU scheduling only; resets/GC/reference checks outside circuit timing"},
            "core_source_sha256": source_maps, "diagnostic_source_sha256": drivers, "raw_file_sha256": raw_files,
            "task_sweep_driver_sha256": sha(directory / "benchmark-source" / "task_sweep.jl"),
            "calibration_samples": sum(row["repetitions"] for row in observations),
            "calibration_full_reference_checks": sum(row["group"] in ("public", "raw") for row in observations),
            "task_sweep_samples": sum(row["repetitions"] for row in sweep_rows),
            "paired_samples": sum(row[stage]["repetitions"] for row in paired for stage in ("before", "after")),
            "auxiliary_diagnostic_samples": auxiliary_samples, "tests": tests,
            "test_source_sha256": test_sources, "observations": observations,
            "task_sweep": sweep_rows, "paired": paired,
            "limitations": ["Sequential phases have substantial 20/25-qubit noise; they do not establish a universal latency gain.",
                "The shared-buffer paired run is the primary timing evidence. Separate buffers can differ in memory placement.",
                "Seven paired repetitions alternate first execution, with a four/three first-position split; ranges are not confidence intervals.",
                "Public/raw calibration checks every saved old amplitude. Rotation/CNOT subcircuits only check normalization and are not additive time decompositions.",
                "Large reference binaries remain on the server. This report verifies their metadata/SHA linkage and the saved comparisons, not their binary contents locally.",
                "Paired and task-sweep raw files lack embedded core source hashes; archived drivers and the separately verified frozen source snapshots provide provenance.",
                "No new MindQuantum timings or universal CPU/GPU speedup claims are inferred from this scheduler experiment."]}


def write_outputs(directory, summary):
    (directory / "summary.json").write_text(json.dumps(summary, indent=2, allow_nan=False) + "\n")
    fields = ("stage", "threads", "qubits", "depth", "group", "repetitions", "median_seconds", "minimum_seconds",
              "maximum_seconds", "median_allocated_bytes", "median_gc_seconds", "before_median_seconds",
              "before_over_current", "raw_file")
    with (directory / "summary.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows({key: row.get(key) for key in fields} for row in summary["observations"])
    fields = ("experiment", "threads", "qubits", "depth", "group", "before_median_seconds", "after_median_seconds",
              "before_minimum_seconds", "before_maximum_seconds", "after_minimum_seconds", "after_maximum_seconds",
              "before_over_after", "paired_ratio_median", "after_slower_pairs", "l2_error", "raw_file")
    with (directory / "paired.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for entry in summary["paired"]:
            row = {key: entry[key] for key in fields if key in entry}
            row.update({f"{stage}_{stat}": entry[stage][stat] for stage in ("before", "after")
                        for stat in ("median_seconds", "minimum_seconds", "maximum_seconds")})
            writer.writerow(row)
    with (directory / "task-sweep.csv").open("w", newline="") as stream:
        fields = ("qubits", "depth", "group", "tasks", "median_seconds", "minimum_seconds", "maximum_seconds")
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows({key: row[key] for key in fields} for row in summary["task_sweep"])


def self_test():
    # Small records exercise validation without loading Julia or running a benchmark.
    require(affinity("Cpus_allowed_list:\\t0-2,4") == [0, 1, 2, 4], "CPU list parser failed")
    require(stats({"seconds": [0.2, 0.1, 0.3], "median_seconds": 0.2}, 3)["median_seconds"] == 0.2,
            "median computation failed")
    bad_records = [({"seconds": [0.1], "median_seconds": 0.1}, 3),
                   ({"seconds": [0.1, 0.2, 0.3], "median_seconds": 0.1}, 3),
                   ({"seconds": [0.1, float("nan"), 0.3]}, 3)]
    for entry, count in bad_records:
        try:
            stats(entry, count)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid timing record accepted")
    good = {"amplitudes_checked": 32768, "relative_l2_error": 0.0, "maximum_amplitude_error": 0.0,
            "reference_norm_squared": 1.0, "actual_norm_squared": 1.0}
    correctness(good, 15)
    try:
        correctness({**good, "amplitudes_checked": 16}, 15)
    except ValueError:
        pass
    else:
        raise AssertionError("partial amplitude comparison accepted")
    print("Self-test passed: CPU lists, recomputed statistics and four corruption rejections.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    summary = summarize(args.directory.resolve())
    write_outputs(args.directory, summary)
    print(f"Validated {summary['calibration_samples']} calibration samples, {summary['paired_samples']} paired samples, "
          f"{summary['task_sweep_samples']} task-sweep samples; {summary['calibration_full_reference_checks']} full-reference checks.")
    for row in summary["paired"]:
        print(f"{row['experiment']} n={row['qubits']} d={row['depth']} {row['group']}: "
              f"{row['before']['median_seconds']:.8g}s -> {row['after']['median_seconds']:.8g}s "
              f"ratio={row['before_over_after']:.5g}")


if __name__ == "__main__":
    main()
