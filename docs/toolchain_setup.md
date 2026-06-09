# Toolchain Setup

This project is intended to run under a Linux-style Verilator flow. On Windows, the recommended path is WSL with Ubuntu.

## Ubuntu or WSL Setup

Install the basic simulation toolchain:

```bash
sudo apt-get update
sudo apt-get install -y make python3 verilator
```

Confirm the tools are visible:

```bash
make --version
python3 --version
verilator --version
```

## Baseline Verification

From the repository root, run:

```bash
make test_all
make assertions
make stress
make event_stress
```

The CI entrypoint runs the same core checks:

```bash
make ci
```

If Verilator is not installed yet, the repository consistency check can still run with Python:

```bash
python3 scripts/check_repo_static.py
```

## Windows Helper

On Windows, if Verilator or make are installed but not on PATH, run the PowerShell helper with explicit paths:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_windows_verification.ps1 `
  -VerilatorPath "C:\path\to\verilator.exe" `
  -MakePath "C:\path\to\make.exe" `
  -PythonPath "C:\path\to\python.exe"
```

By default, the helper runs:

```text
static_check event_parser event_book event_risk event_engine event_latency
```

Pass `-Targets` to run a smaller or larger set.

## Event Verification

Useful focused targets:

```bash
make event_parser
make event_book
make event_book_randomized
make event_risk
make event_engine
make event_engine_risk
make event_latency
make event_stress
```

Integrated legacy and event-engine targets use ordered Verilator filelists under `filelists/`. If you add or rename RTL used by top-level simulations, update the relevant `.f` file and run:

```bash
python3 scripts/check_repo_static.py
```

The randomized event-book test first runs `scripts/generate_event_tests.py` to create `sim/generated_event_order_book_vectors.txt`, then Verilator runs the SystemVerilog testbench against those expected snapshots.

## Generated Files

The repo ignores simulator outputs, waveforms, generated randomized vectors, and Python bytecode:

```text
obj_dir/
*.vcd
*.fst
sim/generated_event_order_book_vectors.txt
__pycache__/
*.pyc
```

These files are meant to be regenerated during verification, not committed.
