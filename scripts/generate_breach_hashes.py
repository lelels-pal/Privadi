#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "Sources" / "PrivadiCore" / "Resources"
HASHES_PATH = RESOURCE_DIR / "breach_hashes.txt"
METADATA_PATH = RESOURCE_DIR / "breach_hashes_metadata.json"


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.strip().lower().encode("utf-8")).hexdigest()


def build_seed_emails() -> list[str]:
    emails = {
        "compromised@example.com",
        "breached@example.com",
        "exposed@example.com",
    }

    for prefix in ("compromised", "breached", "exposed", "pwned", "leaked"):
        for index in range(1, 4001):
            emails.add(f"{prefix}{index:04d}@example.com")

    for domain in ("gmail.com", "icloud.com", "yahoo.com", "outlook.com", "proton.me"):
        for index in range(1, 401):
            emails.add(f"user{index:04d}@{domain}")

    return sorted(emails)


def main() -> None:
    seed_emails = build_seed_emails()
    hashes = sorted({sha256_hex(email) for email in seed_emails})

    HASHES_PATH.write_text("\n".join(hashes) + "\n", encoding="utf-8")
    METADATA_PATH.write_text(
        json.dumps(
            {
                "version": "2026.03-offline-snapshot",
                "generatedAt": "2026-03-25",
                "entryCount": len(hashes),
                "sourceDescription": "Bundled offline SHA-256 snapshot generated from the repo seed list for deterministic local breach checks.",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
