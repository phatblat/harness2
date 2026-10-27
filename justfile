set ignore-comments
set script-interpreter := ['bash', '-eu']
set unstable

python := "3.12"
venv := ".venv"
bin := venv / "bin"

[default]
_default:
    @just --list

#
# configuration group recipes
#

# Create the Python 3.12 virtualenv
[group('configuration')]
venv:
    @test -x {{ bin }}/python || uv venv --python {{ python }} {{ venv }}

# Create the venv and install Harness² with render extras (editable)
[group('configuration')]
deps: venv
    uv pip install --python {{ bin }}/python -e '.[render]'

# Install Harness² with render + bridge extras (needed for the Codex executor)
[group('configuration')]
deps-bridge: venv
    uv pip install --python {{ bin }}/python -e '.[render,bridge]'

# Copy .env.example to .env if .env does not exist yet
[group('configuration')]
env:
    @if [ -e .env ]; then echo ".env already exists"; else cp .env.example .env && echo "Created .env; edit it with your Vertex AI project and model IDs"; fi

# Authenticate Application Default Credentials for Vertex AI
[group('configuration')]
auth:
    gcloud auth application-default login

# Remove the main virtualenv (restore with `just deps`)
[group('configuration')]
clean:
    rm -rf {{ venv }}

#
# benchmarks group recipes
#

# Install a benchmark: jb, lab, or wb (extra args e.g. --subset office, --substrate cx, --dry-run)
[group('benchmarks')]
setup bench *args:
    {{ bin }}/harness2-setup {{ bench }} {{ args }}

# Check installation, credentials, and configuration without calling a model
[group('benchmarks')]
check bench *args:
    {{ bin }}/harness2-check --bench {{ bench }} {{ args }}

# Run the refinement sweep (e.g. `just run lab --k 1 --mode parallel --max-tasks 1`)
[group('benchmarks')]
run bench *args:
    {{ bin }}/harness2 --bench {{ bench }} {{ args }}

# Judge a finished run; use the same bench, subset, k, mode, substrate, and seed as `run`
[group('benchmarks')]
judge bench *args:
    {{ bin }}/harness2-judge --bench {{ bench }} {{ args }}

# Report results; use the same bench, subset, k, mode, substrate, and seed as `run`
[group('benchmarks')]
report bench *args:
    {{ bin }}/harness2-report --bench {{ bench }} {{ args }}

# Run the local demo (deterministic editors, no model credentials needed)
[group('benchmarks')]
demo k="2":
    {{ bin }}/harness2-demo --output runs/demo --k {{ k }}

# Start the Codex Responses API bridge for Gemini on Vertex AI (run in a separate session)
[group('benchmarks')]
bridge *args:
    {{ bin }}/harness2-bridge {{ args }}

# Start the bridge on all interfaces, as WorkBuddy's Docker containers require
[group('benchmarks')]
bridge-docker:
    {{ bin }}/harness2-bridge --host 0.0.0.0

#
# checks group recipes
#

# Run the test suite
[group('checks')]
test *args:
    uv pip install --python {{ bin }}/python pytest
    {{ bin }}/python -m pytest {{ args }}

# Lint with ruff
[group('checks')]
lint:
    uvx ruff check .

# Auto-format code and the justfile
[group('checks')]
format:
    uvx ruff format .
    just --fmt
