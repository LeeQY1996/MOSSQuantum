#!/usr/bin/env python3
"""Audit/assemble the CPU batch performance records without running Julia.

Default inputs are /tmp/moss-batch-{before,after}-n{4,6}-t{1,4}.tsv.
Nothing is written to the repository. --assemble-dir copies raw records,
environment, frozen scripts, and the production-only patch after all audits pass.
"""
import argparse
import collections
import csv
import hashlib
import json
import math
import pathlib
import shutil
import statistics
import subprocess
import tomllib

# The archive also carries this file. Pass --root explicitly there, or invoke
# from the desired checkout; do not depend on the original measurement path.
ROOT = pathlib.Path.cwd()
KEY_FIELDS = ('phase', 'case', 'kind', 'batch_count', 'operation',
              'parameter_slots', 'independent_parameters')
CONTROL_FIELDS = ('julia_version', 'julia_executable', 'julia_threads',
    'blas_threads', 'blas_configuration', 'cpu', 'logical_cpu_threads', 'os',
    'architecture', 'word_size', 'benchmark_project_sha256',
    'benchmark_manifest_sha256', 'active_project_sha256',
    'active_manifest_sha256', 'script_sha256', 'helper_script_sha256',
    'qubits', 'depth', 'seconds_per_trial', 'seed', 'scalar_type', 'method',
    'with_zygote', 'zygote_loaded', 'chainrulescore_loaded', 'batch_counts',
    'cases', 'reduction', 'parameter_sharing', 'input_note', 'mutating_note',
    'reference_note', 'operation_definitions')
EXPECTED_CHANGED_SOURCE = {'src/differentiation/batch.jl',
    'src/differentiation/circuit.jl',
    'src/observables/batch_density_expectation.jl'}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])

def source_snapshot(root, revision=None):
    if revision:
        files = git(root, 'ls-tree', '-r', '--name-only', revision, 'src', 'ext').decode().splitlines()
        hashes = {p: sha(git(root, 'show', revision + ':' + p))
                  for p in files if p.endswith('.jl')}
    else:
        hashes = {str(p.relative_to(root)): sha(p.read_bytes())
                  for folder in ('src', 'ext') for p in (root / folder).rglob('*.jl')}
    summary = '\n'.join(p + '\0' + hashes[p] for p in sorted(hashes))
    return hashes, sha(summary.encode())

def load(path, root):
    with path.open() as stream:
        rows = list(csv.DictReader(stream, delimiter='\t'))
    with pathlib.Path(str(path) + '.metadata.toml').open('rb') as stream:
        meta = tomllib.load(stream)
    keys = [tuple(row[k] for k in KEY_FIELDS) for row in rows]
    assert len(keys) == len(set(keys)), f'duplicate row key: {path}'
    assert {row['phase'] for row in rows} == {'steady_median'}, f'unexpected phase: {path}'
    assert all(int(row['evals']) == 1 for row in rows), f'evals differs: {path}'
    assert all(int(row['samples']) > 0 for row in rows), f'no samples: {path}'
    assert all(float(row['time_ns']) > 0 for row in rows), f'nonpositive time: {path}'
    assert all(int(row['bytes']) >= 0 and int(row['allocations']) >= 0 for row in rows)
    assert not meta['zygote_loaded'] and not meta['chainrulescore_loaded'] and not meta['with_zygote']
    assert len(rows) == 26 * len(meta['batch_counts']), f'row count: {path}'
    assert meta['script_sha256'] == sha((root / 'benchmark/batch_execution.jl').read_bytes())
    assert meta['helper_script_sha256'] == sha((root / 'benchmark/repeated_evaluation.jl').read_bytes())
    return dict(zip(keys, rows)), meta

def compare_pair(before_path, after_path, baseline_snapshot, after_snapshot, root):
    before, bm = load(before_path, root)
    after, am = load(after_path, root)
    assert set(before) == set(after), f'row keys differ: {before_path}'
    for field in CONTROL_FIELDS:
        assert bm[field] == am[field], f'control differs ({field}): {before_path}'
    for meta, snapshot, name in ((bm, baseline_snapshot, 'before'), (am, after_snapshot, 'after')):
        assert meta['source_file_sha256'] == snapshot[0], f'{name} individual source hashes differ'
        assert meta['source_snapshot_sha256'] == snapshot[1], f'{name} combined source hash differs'
    comparisons = []
    for key in before:
        b, a = before[key], after[key]
        result = {field: b[field] for field in KEY_FIELDS}
        result.update(qubits=bm['qubits'], threads=bm['julia_threads'],
            before_time_ns=float(b['time_ns']), after_time_ns=float(a['time_ns']),
            speedup=float(b['time_ns']) / float(a['time_ns']),
            before_bytes=int(b['bytes']), after_bytes=int(a['bytes']),
            bytes_saved=int(b['bytes']) - int(a['bytes']),
            before_allocations=int(b['allocations']), after_allocations=int(a['allocations']),
            before_samples=int(b['samples']), after_samples=int(a['samples']))
        result['bytes_reduction_percent'] = (100 * result['bytes_saved'] / result['before_bytes']
                                             if result['before_bytes'] else None)
        comparisons.append(result)
    return comparisons, bm, am

def summarize(comparisons):
    groups = collections.defaultdict(list)
    for row in comparisons:
        groups[(row['qubits'], row['threads'], row['operation'])].append(row)
    result = []
    for (n, t, operation), rows in sorted(groups.items()):
        byte_reductions = [r['bytes_reduction_percent'] for r in rows
                           if r['bytes_reduction_percent'] is not None and
                           math.isfinite(r['bytes_reduction_percent'])]
        result.append(dict(qubits=n, threads=t, operation=operation, rows=len(rows),
            geometric_mean_speedup=math.exp(statistics.mean(math.log(r['speedup']) for r in rows)),
            min_speedup=min(r['speedup'] for r in rows),
            max_speedup=max(r['speedup'] for r in rows),
            min_bytes_reduction_percent=min(byte_reductions) if byte_reductions else None,
            max_bytes_reduction_percent=max(byte_reductions) if byte_reductions else None))
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=pathlib.Path, default=ROOT)
    parser.add_argument('--baseline-revision', default='cd127e6')
    parser.add_argument('--data-dir', type=pathlib.Path, default=pathlib.Path('/tmp'))
    parser.add_argument('--assemble-dir', type=pathlib.Path)
    parser.add_argument('--output-json', type=pathlib.Path, default=pathlib.Path('/tmp/moss-cpu-batch-comparison.json'))
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--repeat-before', type=pathlib.Path)
    parser.add_argument('--repeat-after', type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    baseline = source_snapshot(root, args.baseline_revision)
    optimized = source_snapshot(root)
    changed = {p for p in set(baseline[0]) | set(optimized[0])
               if baseline[0].get(p) != optimized[0].get(p)}
    if not args.baseline_only:
        assert changed == EXPECTED_CHANGED_SOURCE, f'unexpected production patch: {sorted(changed)}'
    comparisons, records, metas = [], [], []
    for n in (4, 6):
        for t in (1, 4):
            before = args.data_dir / f'moss-batch-before-n{n}-t{t}.tsv'
            if args.baseline_only:
                rows, meta = load(before, root)
                assert meta['source_file_sha256'] == baseline[0]
                assert meta['source_snapshot_sha256'] == baseline[1]
                assert meta['qubits'] == n and meta['julia_threads'] == t
                assert meta['batch_counts'] == [1, 4, 16, 64]
                print(f'PASS {before.name}: {len(rows)} rows, samples '
                      f'{min(int(r["samples"]) for r in rows.values())}..'
                      f'{max(int(r["samples"]) for r in rows.values())}')
                continue
            after = args.data_dir / f'moss-batch-after-n{n}-t{t}.tsv'
            rows, bm, am = compare_pair(before, after, baseline, optimized, root)
            comparisons.extend(rows)
            metas.extend([bm, am])
            records.extend([before, after])
    if args.baseline_only:
        print('Baseline snapshot:', baseline[1])
        return
    repeat = []
    if args.repeat_before or args.repeat_after:
        assert args.repeat_before and args.repeat_after, 'both repeat paths required'
        repeat, bm, am = compare_pair(args.repeat_before, args.repeat_after, baseline, optimized, root)
        assert bm['batch_counts'] == [16] and bm['qubits'] == 6 and bm['julia_threads'] == 1
        assert bm['seconds_per_trial'] == 2
        records.extend([args.repeat_before, args.repeat_after])
        metas.extend([bm, am])
    for meta in metas:
        assert meta['benchmark_project_sha256'] == sha((root / 'benchmark/Project.toml').read_bytes())
        assert meta['benchmark_manifest_sha256'] == sha((root / 'benchmark/Manifest.toml').read_bytes())
    payload = dict(baseline_revision=git(root, 'rev-parse', args.baseline_revision).decode().strip(),
        baseline_source_sha256=baseline[1], optimized_source_sha256=optimized[1],
        changed_source_files=sorted(changed), rows=comparisons,
        operation_summaries=summarize(comparisons), repeat_rows=repeat,
        note='Geometric means assign equal weight to each listed row; they are descriptive, not a workload-wide runtime ratio.')
    args.output_json.write_text(json.dumps(payload, indent=2) + '\n')
    print(f'Audited {len(comparisons)} matched before/after rows and {len(repeat)} repeat rows.')
    print(f'Saved {args.output_json}')
    for row in payload['operation_summaries']:
        print(row)
    if args.assemble_dir:
        target = args.assemble_dir
        target.mkdir(parents=True, exist_ok=True)
        for path in records:
            shutil.copy2(path, target / path.name)
            meta = pathlib.Path(str(path) + '.metadata.toml')
            shutil.copy2(meta, target / meta.name)
        for name in ('Project.toml', 'Manifest.toml', 'batch_execution.jl', 'repeated_evaluation.jl'):
            shutil.copy2(root / 'benchmark' / name, target / name)
        patch = git(root, 'diff', '--binary', '--unified=0', args.baseline_revision, '--', 'src', 'ext')
        (target / 'optimized-source.patch').write_bytes(patch)
        shutil.copy2(args.output_json, target / 'comparison.json')
        hashes = {p.name: sha(p.read_bytes()) for p in sorted(target.iterdir())
                  if p.is_file() and p.name != 'SHA256SUMS'}
        (target / 'SHA256SUMS').write_text(''.join(f'{hashes[name]}  {name}\n' for name in sorted(hashes)))
        print(f'Assembled {len(hashes)} files in {target}')

if __name__ == '__main__':
    main()
