# scoop-juicer

A simple PowerShell tool for tracking software versions that standard scoop manifest `checkver` can't handle easily.

## Usage

```powershell
# Run all manifests
.\core\index.ps1

# Run specific manifests
.\core\index.ps1 -Name 'ExampleApp', 'AnotherApp'
```

## How It Works

Each app has a folder under `manifests/` containing:

- `script.ps1` — fetches the latest version and populates `$State.version`
- `state.json` — auto-generated, stores only the latest version string

### Manifest Script Convention

`script.ps1` receives two variables from the runner:

| Variable | Type | Description |
|---|---|---|
| `$State` | hashtable | Set `version` (required) and optionally `compareMode`, `ignore` |
| `$PreviousState` | hashtable | Read-only, contains the last recorded `version` (empty on first run) |

### compareMode

| Mode | Behavior                                                                       |
|---|--------------------------------------------------------------------------------|
| _(not set)_ | Any string change is recorded                                                  |
| `"semver"` | (Default) Only records when new version > old version (e.g. `1.2.3` > `1.2.2`) |
| `"numeric"` | Only records when new number > old number                                      |

### ignore

Set `$State.ignore` to a regex in `script.ps1` to skip versions matching it —
the run is logged as ignored and `state.json` stays untouched.

```powershell
$State.ignore = 'SNAPSHOT'
```

| Pattern | Behavior |
|---|---|
| _(not set)_ | Every detected version is compared normally |
| `'SNAPSHOT'` | Ignores versions like `5.0.0-M1-SNAPSHOT` |
| `'-beta\|-rc'` | Ignores beta and release-candidate versions |


