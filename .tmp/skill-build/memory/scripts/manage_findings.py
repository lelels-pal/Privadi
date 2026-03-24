#!/usr/bin/env python3
import argparse
import fcntl
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def resolve_state_paths(project_root: str, db_path_arg: str | None) -> tuple[Path, Path]:
    if db_path_arg:
        db_path = Path(db_path_arg).expanduser().resolve()
    else:
        db_path = Path(project_root).expanduser().resolve() / ".codex-memory" / "findings.json"
    lock_path = db_path.with_suffix(".lock")
    return db_path, lock_path


def ensure_db(db_path: Path) -> dict[str, Any]:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if not db_path.exists():
        data = {"version": 1, "projects": {}}
        db_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        return data
    return json.loads(db_path.read_text(encoding="utf-8"))


def save_db(data: dict[str, Any], db_path: Path) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = db_path.with_suffix(".json.tmp")
    temp_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(temp_path, db_path)


def with_locked_db(project_root: str, db_path_arg: str | None, mutator):
    db_path, lock_path = resolve_state_paths(project_root, db_path_arg)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w", encoding="utf-8") as lock_handle:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX)
        data = ensure_db(db_path)
        result = mutator(data)
        if result is not None:
            save_db(data, db_path)
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_UN)
        return result


def project_root_from_arg(value: str | None) -> str:
    root = Path(value or Path.cwd()).expanduser().resolve()
    return str(root)


def default_project_label(project_root: str) -> str:
    path = Path(project_root)
    return path.name or project_root


def get_project(data: dict[str, Any], project_root: str, project_label: str | None = None) -> dict[str, Any]:
    projects = data.setdefault("projects", {})
    project = projects.get(project_root)
    if project is None:
        timestamp = now_iso()
        project = {
            "project_root": project_root,
            "project_label": project_label or default_project_label(project_root),
            "created_at": timestamp,
            "updated_at": timestamp,
            "findings": [],
        }
        projects[project_root] = project
    elif project_label:
        project["project_label"] = project_label
    return project


def finding_sort_key(finding: dict[str, Any]) -> tuple[int, Any]:
    value = str(finding["id"])
    if value.isdigit():
        return (0, int(value))
    return (1, value)


def find_finding(project: dict[str, Any], finding_id: str) -> dict[str, Any] | None:
    for finding in project["findings"]:
        if str(finding["id"]) == str(finding_id):
            return finding
    return None


def print_summary(project: dict[str, Any]) -> None:
    findings = sorted(project["findings"], key=finding_sort_key)
    counts = {"open": 0, "resolved": 0, "accepted": 0, "blocked": 0}
    for finding in findings:
        counts[finding["status"]] = counts.get(finding["status"], 0) + 1

    print(f"# {project['project_label']} Findings")
    print()
    print(f"Project root: {project['project_root']}")
    print(
        "Open: {open} | Resolved: {resolved} | Accepted: {accepted} | Blocked: {blocked}".format(
            **counts
        )
    )
    print()
    if not findings:
        print("No stored findings.")
        return

    for finding in findings:
        print(
            f"- [{finding['status']}][{finding['severity']}] {finding['id']} {finding['title']}"
        )
        if finding.get("resolution_note") and finding["status"] == "resolved":
            print(f"  Resolution: {finding['resolution_note']}")


def append_history(finding: dict[str, Any], action: str, note: str | None = None) -> None:
    finding.setdefault("history", []).append(
        {
            "at": now_iso(),
            "action": action,
            "note": note,
        }
    )


def cmd_summary(args: argparse.Namespace) -> int:
    project_root = project_root_from_arg(args.project_root)

    def action(data: dict[str, Any]) -> int:
        project = data.get("projects", {}).get(project_root)
        if project is None:
            print(f"# {default_project_label(project_root)} Findings")
            print()
            print(f"Project root: {project_root}")
            print("Open: 0 | Resolved: 0 | Accepted: 0 | Blocked: 0")
            print()
            print("No stored findings.")
            return None

        print_summary(project)
        return None

    with_locked_db(project_root, args.db_path, action)
    return 0


def normalize_status(status: str) -> str:
    allowed = {"open", "resolved", "accepted", "blocked"}
    if status not in allowed:
        raise SystemExit(f"Unsupported status: {status}")
    return status


def cmd_upsert(args: argparse.Namespace) -> int:
    project_root = project_root_from_arg(args.project_root)

    def action(data: dict[str, Any]) -> int:
        project = get_project(data, project_root, args.project_label)
        timestamp = now_iso()
        finding = find_finding(project, args.id)

        if finding is None:
            finding = {
                "id": args.id,
                "severity": args.severity,
                "title": args.title,
                "details": args.details,
                "status": normalize_status(args.status),
                "refs": args.ref or [],
                "source": args.source,
                "created_at": timestamp,
                "updated_at": timestamp,
                "resolved_at": timestamp if args.status == "resolved" else None,
                "resolution_note": args.note if args.status == "resolved" else None,
                "history": [],
            }
            append_history(finding, "created", args.note)
            project["findings"].append(finding)
        else:
            finding["severity"] = args.severity or finding["severity"]
            finding["title"] = args.title or finding["title"]
            finding["details"] = args.details or finding["details"]
            finding["status"] = normalize_status(args.status)
            finding["refs"] = args.ref if args.ref else finding.get("refs", [])
            finding["source"] = args.source or finding.get("source")
            finding["updated_at"] = timestamp
            if args.status == "resolved":
                finding["resolved_at"] = timestamp
                if args.note:
                    finding["resolution_note"] = args.note
            append_history(finding, "updated", args.note)

        project["updated_at"] = timestamp
        project["findings"] = sorted(project["findings"], key=finding_sort_key)
        print(f"Stored finding {args.id} for {project['project_label']}.")
        return True

    with_locked_db(project_root, args.db_path, action)
    return 0


def update_status(args: argparse.Namespace, target_status: str, history_action: str) -> int:
    project_root = project_root_from_arg(args.project_root)

    def action(data: dict[str, Any]) -> int:
        project = data.get("projects", {}).get(project_root)
        if project is None:
            raise SystemExit(f"No findings stored for project root: {project_root}")

        finding = find_finding(project, args.id)
        if finding is None:
            raise SystemExit(f"Finding {args.id} not found for {project_root}")

        timestamp = now_iso()
        finding["status"] = target_status
        finding["updated_at"] = timestamp
        if target_status == "resolved":
            finding["resolved_at"] = timestamp
            finding["resolution_note"] = args.note
        else:
            finding["resolved_at"] = None
        append_history(finding, history_action, args.note)
        project["updated_at"] = timestamp
        print(f"{target_status.capitalize()} finding {args.id} for {project['project_label']}.")
        return True

    with_locked_db(project_root, args.db_path, action)
    return 0


def cmd_resolve(args: argparse.Namespace) -> int:
    return update_status(args, "resolved", "resolved")


def cmd_reopen(args: argparse.Namespace) -> int:
    return update_status(args, "open", "reopened")


def cmd_show(args: argparse.Namespace) -> int:
    project_root = project_root_from_arg(args.project_root)

    def action(data: dict[str, Any]) -> int:
        project = data.get("projects", {}).get(project_root)
        if project is None:
            raise SystemExit(f"No findings stored for project root: {project_root}")
        finding = find_finding(project, args.id)
        if finding is None:
            raise SystemExit(f"Finding {args.id} not found for {project_root}")
        print(json.dumps(finding, indent=2))
        return None

    with_locked_db(project_root, args.db_path, action)
    return 0


def cmd_import_json(args: argparse.Namespace) -> int:
    payload = json.loads(Path(args.from_file).read_text(encoding="utf-8"))
    findings = payload["findings"] if isinstance(payload, dict) else payload
    project_root = project_root_from_arg(args.project_root)

    def action(data: dict[str, Any]) -> int:
        project = get_project(data, project_root, args.project_label)
        timestamp = now_iso()

        for item in findings:
            existing = find_finding(project, str(item["id"]))
            record = {
                "id": str(item["id"]),
                "severity": item["severity"],
                "title": item["title"],
                "details": item["details"],
                "status": normalize_status(item.get("status", "open")),
                "refs": item.get("refs", []),
                "source": item.get("source"),
                "created_at": timestamp if existing is None else existing["created_at"],
                "updated_at": timestamp,
                "resolved_at": timestamp if item.get("status") == "resolved" else None,
                "resolution_note": item.get("resolution_note"),
                "history": existing.get("history", []) if existing else [],
            }
            append_history(record, "imported", item.get("resolution_note"))
            if existing is None:
                project["findings"].append(record)
            else:
                existing.update(record)

        project["updated_at"] = timestamp
        project["findings"] = sorted(project["findings"], key=finding_sort_key)
        print(f"Imported {len(findings)} findings into {project['project_label']}.")
        return True

    with_locked_db(project_root, args.db_path, action)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage persistent cross-thread findings.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    summary = subparsers.add_parser("summary", help="Print a markdown summary for the current project.")
    summary.add_argument("--project-root", default=None)
    summary.add_argument("--db-path", default=None)
    summary.set_defaults(func=cmd_summary)

    upsert = subparsers.add_parser("upsert", help="Create or update a finding.")
    upsert.add_argument("--project-root", default=None)
    upsert.add_argument("--db-path", default=None)
    upsert.add_argument("--project-label", default=None)
    upsert.add_argument("--id", required=True)
    upsert.add_argument("--severity", required=True)
    upsert.add_argument("--title", required=True)
    upsert.add_argument("--details", required=True)
    upsert.add_argument("--status", default="open")
    upsert.add_argument("--ref", action="append", default=[])
    upsert.add_argument("--source", default=None)
    upsert.add_argument("--note", default=None)
    upsert.set_defaults(func=cmd_upsert)

    resolve = subparsers.add_parser("resolve", help="Mark a finding resolved.")
    resolve.add_argument("--project-root", default=None)
    resolve.add_argument("--db-path", default=None)
    resolve.add_argument("--id", required=True)
    resolve.add_argument("--note", required=True)
    resolve.set_defaults(func=cmd_resolve)

    reopen = subparsers.add_parser("reopen", help="Reopen a finding.")
    reopen.add_argument("--project-root", default=None)
    reopen.add_argument("--db-path", default=None)
    reopen.add_argument("--id", required=True)
    reopen.add_argument("--note", required=True)
    reopen.set_defaults(func=cmd_reopen)

    show = subparsers.add_parser("show", help="Print one finding as JSON.")
    show.add_argument("--project-root", default=None)
    show.add_argument("--db-path", default=None)
    show.add_argument("--id", required=True)
    show.set_defaults(func=cmd_show)

    import_json = subparsers.add_parser("import-json", help="Import findings from a JSON file.")
    import_json.add_argument("--project-root", default=None)
    import_json.add_argument("--db-path", default=None)
    import_json.add_argument("--project-label", default=None)
    import_json.add_argument("--from-file", required=True)
    import_json.set_defaults(func=cmd_import_json)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
