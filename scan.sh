#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROSCAN_URL:-}" ] || [ -z "${PROSCAN_TOKEN:-}" ]; then
  echo "Error: PROSCAN_URL and PROSCAN_TOKEN must be set."
  exit 1
fi

API_BASE="${PROSCAN_URL}/api/v2"
AUTH_HEADER="Authorization: Bearer ${PROSCAN_TOKEN}"
TIMEOUT_SECONDS=$((SCAN_TIMEOUT * 60))

echo "Starting ${SCAN_TYPE} scan..."

SCAN_RESPONSE=$(curl -sf -X POST "${API_BASE}/scans" \
  -H "${AUTH_HEADER}" \
  -H "Content-Type: application/json" \
  -d "{\"type\": \"${SCAN_TYPE}\", \"target\": \"${TARGET}\"}")

SCAN_ID=$(echo "${SCAN_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || true)

if [ -z "${SCAN_ID}" ]; then
  echo "Error: Failed to start scan. Check your server URL and API token."
  exit 1
fi

echo "Scan started: ${SCAN_ID}"
echo "View results: ${PROSCAN_URL}/scans/${SCAN_ID}"

ELAPSED=0
POLL_INTERVAL=10
STATUS="running"

while [ "${STATUS}" = "running" ] || [ "${STATUS}" = "queued" ]; do
  if [ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "Error: Scan timed out after ${SCAN_TIMEOUT} minutes."
    exit 1
  fi

  sleep ${POLL_INTERVAL}
  ELAPSED=$((ELAPSED + POLL_INTERVAL))

  STATUS_RESPONSE=$(curl -sf "${API_BASE}/scans/${SCAN_ID}" \
    -H "${AUTH_HEADER}" 2>/dev/null || echo '{}')

  STATUS=$(echo "${STATUS_RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")

  echo "Status: ${STATUS} (${ELAPSED}s elapsed)"
done

if [ "${STATUS}" != "completed" ]; then
  echo "Error: Scan ended with status '${STATUS}'."
  exit 1
fi

RESULTS=$(curl -sf "${API_BASE}/scans/${SCAN_ID}/results" \
  -H "${AUTH_HEADER}" 2>/dev/null || echo '{}')

TOTAL=$(echo "${RESULTS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "0")
CRITICAL=$(echo "${RESULTS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('critical',0))" 2>/dev/null || echo "0")
HIGH=$(echo "${RESULTS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('high',0))" 2>/dev/null || echo "0")
MEDIUM=$(echo "${RESULTS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('medium',0))" 2>/dev/null || echo "0")

echo ""
echo "=== Scan Results ==="
echo "Total findings: ${TOTAL}"
echo "Critical: ${CRITICAL}"
echo "High: ${HIGH}"
echo "Medium: ${MEDIUM}"
echo "Results: ${PROSCAN_URL}/scans/${SCAN_ID}"
echo "===================="

echo "findings-count=${TOTAL}" >> "${GITHUB_OUTPUT}"
echo "critical-count=${CRITICAL}" >> "${GITHUB_OUTPUT}"
echo "high-count=${HIGH}" >> "${GITHUB_OUTPUT}"
echo "scan-url=${PROSCAN_URL}/scans/${SCAN_ID}" >> "${GITHUB_OUTPUT}"

if [ "${SARIF_UPLOAD}" = "true" ]; then
  echo "Downloading SARIF report..."
  curl -sf "${API_BASE}/scans/${SCAN_ID}/export/sarif" \
    -H "${AUTH_HEADER}" \
    -o proscan-results.sarif 2>/dev/null || echo "Warning: Could not download SARIF report."
fi

if [ "${QUALITY_GATE}" = "true" ]; then
  FAILED=false

  case "${SEVERITY_THRESHOLD}" in
    critical)
      [ "${CRITICAL}" -gt 0 ] && FAILED=true
      ;;
    high)
      [ "${CRITICAL}" -gt 0 ] || [ "${HIGH}" -gt 0 ] && FAILED=true
      ;;
    medium)
      [ "${CRITICAL}" -gt 0 ] || [ "${HIGH}" -gt 0 ] || [ "${MEDIUM}" -gt 0 ] && FAILED=true
      ;;
    low)
      [ "${TOTAL}" -gt 0 ] && FAILED=true
      ;;
  esac

  if [ "${FAILED}" = "true" ]; then
    echo ""
    echo "Quality gate FAILED — findings exceed the ${SEVERITY_THRESHOLD} severity threshold."
    echo "status=failed" >> "${GITHUB_OUTPUT}"
    exit 1
  else
    echo ""
    echo "Quality gate passed."
    echo "status=passed" >> "${GITHUB_OUTPUT}"
  fi
else
  echo "status=passed" >> "${GITHUB_OUTPUT}"
fi
