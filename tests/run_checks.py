#!/usr/bin/env python3
"""Run combat/session regressions and optional two-process ENet suites."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]
OFFLINE = [
    ('regression', 'Failures: 0'),
    ('boss_fight', 'Boss fight failures: 0'),
    ('jefferson_tactics', 'Jefferson tactics failures: 0'),
    ('dot_presentation', 'DoT presentation failures: 0'),
    ('hero_classes', 'Hero class failures: 0'),
    ('session_loop', 'Session loop failures: 0'),
]
NETWORK = [
    ('boss_network', 'NETWORK'),
    ('class_network', 'CLASS_NETWORK'),
    ('session_network', 'SESSION_NETWORK'),
]


def validate(output, marker):
    if marker not in output or re.search(r'^(?:ERROR:|SCRIPT ERROR:)', output, re.M):
        raise RuntimeError(output)
    return len(re.findall(r'^PASS:', output, re.M))


def network(godot, scene, prefix):
    processes = []
    with tempfile.TemporaryDirectory(prefix='wowcopycraft-tests-') as directory:
        logs = {side: Path(directory) / f'{side}.log' for side in ['server', 'client']}
        base = [godot, '--headless', '--path', str(PROJECT), f'res://tests/{scene}.tscn', '--']
        try:
            with logs['server'].open('w') as so, logs['client'].open('w') as co:
                server = subprocess.Popen(base + ['--server'], stdout=so, stderr=subprocess.STDOUT)
                processes.append(server)
                deadline = time.monotonic() + 15
                while f'{prefix}_SERVER_READY' not in logs['server'].read_text(errors='replace'):
                    if server.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError(logs['server'].read_text(errors='replace'))
                    time.sleep(.1)
                client = subprocess.Popen(base + ['--client'], stdout=co, stderr=subprocess.STDOUT)
                processes.append(client)
                client_code = client.wait(timeout=55)
                server_code = server.wait(timeout=10)
                if client_code or server_code:
                    raise RuntimeError('\n'.join(path.read_text(errors='replace') for path in logs.values()))
            count = sum(validate(logs[side].read_text(errors='replace'), f'{prefix}_{side.upper()}_PASS') for side in logs)
            print(f'{scene}: OK ({count} checks)')
            return count
        except (RuntimeError, subprocess.TimeoutExpired):
            for side, path in logs.items():
                print(f'{side}:\n{path.read_text(errors="replace")}')
            raise
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--network', action='store_true')
    args = parser.parse_args()
    total = 0
    for scene, marker in OFFLINE:
        result = subprocess.run([args.godot, '--headless', '--path', str(PROJECT), f'res://tests/{scene}.tscn'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=50)
        if result.returncode:
            raise RuntimeError(result.stdout)
        count = validate(result.stdout, marker)
        total += count
        print(f'{scene}: OK ({count} checks)')
    if args.network:
        for scene, prefix in NETWORK:
            total += network(args.godot, scene, prefix)
    print(f'Total: {total} checks passed')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
