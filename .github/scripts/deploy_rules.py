#!/usr/bin/env python3
"""Deploy firestore.rules ke Firebase via Rules REST API.

Alternatif `firebase deploy --only firestore:rules` yang TIDAK butuh role
Editor / serviceusage di service account (firebase-tools gagal 403 di situ,
lihat run 12:08-12:15). Cukup izin firebaserules bawaan SA firebase-adminsdk.

Env:  GCP_SA_KEY = isi JSON service account (secret FIREBASE_SERVICE_ACCOUNT)
Pakai: python3 deploy_rules.py <path rules> <project id>
"""
import json
import os
import sys
import urllib.request

from google.auth.transport.requests import Request
from google.oauth2 import service_account


def main() -> None:
    rules_path, project = sys.argv[1], sys.argv[2]
    sa_json = os.environ.get("GCP_SA_KEY", "").strip()
    if not sa_json:
        sys.exit("::error::Secret FIREBASE_SERVICE_ACCOUNT kosong.")

    cred = service_account.Credentials.from_service_account_info(
        json.loads(sa_json),
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    cred.refresh(Request())
    headers = {"Authorization": f"Bearer {cred.token}", "Content-Type": "application/json"}
    base = f"https://firebaserules.googleapis.com/v1/projects/{project}"

    def call(method: str, url: str, body: dict | None = None) -> dict:
        req = urllib.request.Request(
            url,
            method=method,
            headers=headers,
            data=json.dumps(body).encode() if body is not None else None,
        )
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())

    content = open(rules_path, encoding="utf-8").read()

    # 1) Buat ruleset baru
    ruleset = call("POST", f"{base}/rulesets", {
        "source": {"files": [{"name": "firestore.rules", "content": content}]},
    })
    print("Ruleset dibuat:", ruleset["name"])

    # 2) Jadikan live. CATATAN: body HARUS dibungkus {"release": {...}}
    #    (kalau tidak, API-nya balas 400 "Unknown name rulesetName").
    call("PATCH", f"{base}/releases/cloud.firestore", {
        "release": {
            "name": f"projects/{project}/releases/cloud.firestore",
            "rulesetName": ruleset["name"],
        },
    })

    # 3) Verifikasi
    live = call("GET", f"{base}/releases/cloud.firestore")
    if live.get("rulesetName") != ruleset["name"]:
        sys.exit("::error::Release tidak berpindah ke ruleset baru!")
    print("OK: rules live ->", live["rulesetName"])


if __name__ == "__main__":
    main()
