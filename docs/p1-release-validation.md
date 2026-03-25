# P1 Release Validation

Use this targeted matrix when shipping the `P1` through `P1-3` fixes.

## Automated Gate

- Run `./scripts/build.sh`
- Run `./scripts/test.sh`

## Manual Smoke Matrix

1. Exact duplicate detection on a real device
   Confirm a library containing at least one exact duplicate pair shows a non-zero duplicate-group count and exposes duplicate-backed delete candidates on the dashboard.
2. Limited Photos access
   Grant Limited Access, run a scan, and confirm the dashboard completes with the limited-access status copy and no crash.
3. Permission denied and empty library paths
   Verify denied access shows the expected permission error and an empty library shows the empty-library copy.
4. Offline breach check
   Check `compromised@example.com` and confirm it matches the bundled local index; check `clean@example.com` and confirm it does not match.
5. Cleanup review integrity
   Open the cleanup review and confirm only delete-safe candidates appear, with reclaimable bytes matching the dashboard summary.
