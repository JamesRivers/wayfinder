#!/usr/bin/env python3
"""Bootstrap AWX objects for the Alloy bundle.

This script is idempotent: it ensures the AWX organization, project,
inventory, and job template exist, then optionally triggers a project sync.

Defaults are tuned for the observability host in this repo.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

DEFAULT_AWX_URL = os.environ.get("AWX_URL", "http://172.16.47.163:30080")
DEFAULT_AWX_ADMIN_USER = os.environ.get("AWX_ADMIN_USER", "admin")
DEFAULT_AWX_ADMIN_PASSWORD_SECRET = os.environ.get(
    "AWX_ADMIN_PASSWORD_SECRET", "observability-awx-admin-password"
)
DEFAULT_AWX_NAMESPACE = os.environ.get("AWX_NAMESPACE", "awx")
DEFAULT_ORG = os.environ.get("AWX_ORG_NAME", "imagine")
DEFAULT_PROJECT = os.environ.get("AWX_PROJECT_NAME", "mon")
DEFAULT_INVENTORY = os.environ.get("AWX_INVENTORY_NAME", "alloy-inventory")
DEFAULT_TEMPLATE = os.environ.get("AWX_TEMPLATE_NAME", "alloy-template")
DEFAULT_BRANCH = os.environ.get("AWX_BRANCH", "main")
DEFAULT_REPO = os.environ.get(
    "AWX_REPO_URL", "git://172.16.47.163:9418/alloy-template-bundle.git"
)
DEFAULT_PLAYBOOK = os.environ.get("AWX_PLAYBOOK", "playbooks/alloy-deploy.yml")
DEFAULT_SYNC = os.environ.get("AWX_SYNC_PROJECT", "true").lower() in {"1", "true", "yes", "on"}
DEFAULT_TIMEOUT = int(os.environ.get("AWX_SYNC_TIMEOUT", "600"))


def eprint(*args: Any) -> None:
    print(*args, file=sys.stderr)


def get_awx_admin_password(secret_name: str, namespace: str) -> str:
    cmd = [
        "kubectl",
        "get",
        "secret",
        "-n",
        namespace,
        secret_name,
        "-o",
        "jsonpath={.data.password}",
    ]
    raw = subprocess.check_output(cmd, text=True).strip()
    if not raw:
        raise RuntimeError(f"secret {namespace}/{secret_name} has no password data")
    return base64.b64decode(raw).decode()


class AWXClient:
    def __init__(self, base_url: str, username: str, password: str):
        self.base_url = base_url.rstrip("/")
        token = base64.b64encode(f"{username}:{password}".encode()).decode()
        self.headers = {
            "Authorization": f"Basic {token}",
            "Content-Type": "application/json",
        }

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        url = self.base_url + path
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(url, data=data, headers=self.headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = resp.read().decode()
                return json.loads(payload) if payload else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            raise RuntimeError(f"{method} {path} failed with HTTP {e.code}: {detail}") from e

    def get_list(self, path: str, name: str) -> list[dict[str, Any]]:
        qp = urllib.parse.urlencode({"name": name})
        data = self.request("GET", f"{path}?{qp}")
        return data.get("results", []) if isinstance(data, dict) else []

    def ensure_object(self, path: str, name: str, payload: dict[str, Any], update_fields: list[str] | None = None) -> tuple[dict[str, Any], bool]:
        existing = self.get_list(path, name)
        if existing:
            obj = existing[0]
            if update_fields:
                changed = False
                patch = {}
                for field in update_fields:
                    if obj.get(field) != payload.get(field):
                        patch[field] = payload.get(field)
                        changed = True
                if changed:
                    obj = self.request("PATCH", f"{path}{obj['id']}/", patch)
                    return obj, True
            return obj, False
        obj = self.request("POST", path, payload)
        return obj, True


def wait_for_project_sync(client: AWXClient, project_id: int, timeout_s: int) -> dict[str, Any]:
    started = client.request("POST", f"/api/v2/projects/{project_id}/update/")
    if not isinstance(started, dict) or "id" not in started:
        raise RuntimeError(f"unexpected project sync response: {started!r}")
    job_id = started["id"]
    deadline = time.time() + timeout_s
    status = None
    while time.time() < deadline:
        job = client.request("GET", f"/api/v2/project_updates/{job_id}/")
        status = job.get("status")
        if status in {"successful", "failed", "error", "canceled"}:
            if status != "successful":
                raise RuntimeError(f"project sync ended with status {status}: {job}")
            return job
        time.sleep(5)
    raise TimeoutError(f"timed out waiting for project sync {job_id}; last status={status!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--awx-url", default=DEFAULT_AWX_URL)
    parser.add_argument("--admin-user", default=DEFAULT_AWX_ADMIN_USER)
    parser.add_argument("--admin-password-secret", default=DEFAULT_AWX_ADMIN_PASSWORD_SECRET)
    parser.add_argument("--namespace", default=DEFAULT_AWX_NAMESPACE)
    parser.add_argument("--org", default=DEFAULT_ORG)
    parser.add_argument("--project", default=DEFAULT_PROJECT)
    parser.add_argument("--inventory", default=DEFAULT_INVENTORY)
    parser.add_argument("--template", default=DEFAULT_TEMPLATE)
    parser.add_argument("--branch", default=DEFAULT_BRANCH)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--playbook", default=DEFAULT_PLAYBOOK)
    parser.add_argument("--sync-project", action=argparse.BooleanOptionalAction, default=DEFAULT_SYNC)
    parser.add_argument("--sync-timeout", type=int, default=DEFAULT_TIMEOUT)
    args = parser.parse_args()

    password = get_awx_admin_password(args.admin_password_secret, args.namespace)
    client = AWXClient(args.awx_url, args.admin_user, password)

    org, created_org = client.ensure_object(
        "/api/v2/organizations/",
        args.org,
        {"name": args.org},
    )
    project, created_project = client.ensure_object(
        "/api/v2/projects/",
        args.project,
        {
            "name": args.project,
            "organization": org["id"],
            "scm_type": "git",
            "scm_url": args.repo,
            "scm_branch": args.branch,
            "scm_update_on_launch": True,
            "scm_clean": True,
            "scm_delete_on_update": True,
        },
        update_fields=["organization", "scm_type", "scm_url", "scm_branch", "scm_update_on_launch", "scm_clean", "scm_delete_on_update"],
    )
    inventory, created_inventory = client.ensure_object(
        "/api/v2/inventories/",
        args.inventory,
        {
            "name": args.inventory,
            "organization": org["id"],
        },
        update_fields=["organization"],
    )
    template, created_template = client.ensure_object(
        "/api/v2/job_templates/",
        args.template,
        {
            "name": args.template,
            "job_type": "run",
            "inventory": inventory["id"],
            "project": project["id"],
            "playbook": args.playbook,
            "verbosity": 1,
            "ask_inventory_on_launch": True,
            "ask_credential_on_launch": True,
            "ask_variables_on_launch": True,
            "ask_limit_on_launch": True,
        },
        update_fields=["inventory", "project", "playbook", "verbosity", "ask_inventory_on_launch", "ask_credential_on_launch", "ask_variables_on_launch", "ask_limit_on_launch"],
    )

    summary = {
        "organization": {"id": org["id"], "name": org["name"], "created_or_updated": created_org},
        "project": {"id": project["id"], "name": project["name"], "created_or_updated": created_project},
        "inventory": {"id": inventory["id"], "name": inventory["name"], "created_or_updated": created_inventory},
        "job_template": {"id": template["id"], "name": template["name"], "created_or_updated": created_template},
    }

    if args.sync_project:
        eprint(f"Syncing project {project['name']} ({project['id']}) ...")
        sync = wait_for_project_sync(client, project["id"], args.sync_timeout)
        summary["project_sync"] = {
            "id": sync["id"],
            "status": sync.get("status"),
            "elapsed": sync.get("elapsed"),
            "finished": sync.get("finished"),
            "scm_revision": sync.get("scm_revision"),
        }

    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
