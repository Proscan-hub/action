# Proscan GitHub Action

Run Proscan security scans as part of your GitHub Actions workflow. Scan on every push, pull request, or on a schedule — and fail builds when security quality gates aren't met.

## Quick Start

```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  security:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Run Proscan
        uses: Proscan-hub/action@v1
        with:
          server-url: ${{ secrets.PROSCAN_URL }}
          api-token: ${{ secrets.PROSCAN_API_TOKEN }}
          scan-type: sast
          target: .
          quality-gate: true
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `server-url` | Yes | — | URL of your Proscan instance |
| `api-token` | Yes | — | API token for authentication (use GitHub Secrets) |
| `scan-type` | Yes | — | Scanner to run: `sast`, `sca`, `secrets`, `iac`, `container`, `api`, `dast` |
| `target` | No | `.` | Path to scan (for SAST, SCA, secrets, IaC) or URL (for DAST, API) |
| `quality-gate` | No | `true` | Fail the workflow if the quality gate is not met |
| `sarif-upload` | No | `false` | Upload results to GitHub Code Scanning in SARIF format |
| `severity-threshold` | No | `high` | Minimum severity to trigger a failure: `critical`, `high`, `medium`, `low` |
| `timeout` | No | `30` | Maximum scan duration in minutes before timeout |

## Outputs

| Output | Description |
|--------|-------------|
| `findings-count` | Total number of findings |
| `critical-count` | Number of critical findings |
| `high-count` | Number of high severity findings |
| `scan-url` | URL to view full results in Proscan |
| `status` | Scan result: `passed` or `failed` |

## Examples

### SAST on Pull Requests

Scan source code for vulnerabilities on every pull request. Fail the check if critical or high severity issues are found.

```yaml
name: SAST

on:
  pull_request:
    branches: [main, develop]

jobs:
  sast:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Run SAST
        uses: Proscan-hub/action@v1
        with:
          server-url: ${{ secrets.PROSCAN_URL }}
          api-token: ${{ secrets.PROSCAN_API_TOKEN }}
          scan-type: sast
          target: .
          quality-gate: true
          severity-threshold: high
```

### SCA and Secrets Together

Run multiple scan types in the same workflow.

```yaml
name: Security Checks

on:
  push:
    branches: [main]

jobs:
  sca:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Dependency Scan
        uses: Proscan-hub/action@v1
        with:
          server-url: ${{ secrets.PROSCAN_URL }}
          api-token: ${{ secrets.PROSCAN_API_TOKEN }}
          scan-type: sca
          target: .

  secrets:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Secrets Scan
        uses: Proscan-hub/action@v1
        with:
          server-url: ${{ secrets.PROSCAN_URL }}
          api-token: ${{ secrets.PROSCAN_API_TOKEN }}
          scan-type: secrets
          target: .
```

### SARIF Upload to GitHub Code Scanning

Upload scan results directly to GitHub's Security tab.

```yaml
- name: Run Proscan
  uses: Proscan-hub/action@v1
  with:
    server-url: ${{ secrets.PROSCAN_URL }}
    api-token: ${{ secrets.PROSCAN_API_TOKEN }}
    scan-type: sast
    target: .
    sarif-upload: true

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: proscan-results.sarif
```

### Scheduled Nightly Scan

```yaml
name: Nightly Security Scan

on:
  schedule:
    - cron: '0 2 * * *'

jobs:
  full-scan:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Full Scan
        uses: Proscan-hub/action@v1
        with:
          server-url: ${{ secrets.PROSCAN_URL }}
          api-token: ${{ secrets.PROSCAN_API_TOKEN }}
          scan-type: sast
          target: .
          timeout: 60
```

## Setup

### 1. Store Credentials

Add these as secrets in your repository (Settings > Secrets and variables > Actions):

- `PROSCAN_URL` — your Proscan instance URL (e.g., `http://localhost:18080`)
- `PROSCAN_API_TOKEN` — an API token generated from Proscan (Settings > API Tokens)

### 2. Self-Hosted Runner

Since Proscan runs on your infrastructure, the GitHub Actions runner needs network access to your Proscan instance. Use a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners) on the same network.

### 3. Add the Workflow

Create a `.github/workflows/proscan.yml` file in your repository with one of the examples above.

## Quality Gates

When `quality-gate` is enabled, the action checks the scan results against the configured thresholds in your Proscan project. If findings exceed the threshold, the step exits with a non-zero code and the workflow fails.

Quality gates are configured in the Proscan web interface under your project settings. The action enforces whatever policy you've defined there.

## Support

- Documentation: [Proscan-hub/docs](https://github.com/Proscan-hub/docs)
- Issues: [Report an issue](https://github.com/Proscan-hub/action/issues)
- Contact: [contact@proscan.one](mailto:contact@proscan.one)
