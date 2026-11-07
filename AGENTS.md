# AGENTS.md: Building a Glitch Attack/Defense Service

## Mission

This repository is a template for a **FAUST-style attack/defense service**. The same service is deployed for every team. A checker plants unique flags per team/round through the service's normal API, and attackers exploit other teams' instances to steal those flags. Defenders patch their own copy without breaking legitimate functionality.

Your job is to replace the example template with **one realistic service that is genuinely useful, vulnerable in a non-obvious way, and defensible with a focused patch**. Do not build a toy or a CTF challenge with intentional "flag" concepts.

## Non-Negotiable Requirements

1. **Working exploit**: at least one exploit must recover the flag using only the target host/IP and the flag ID as arguments. No private checker data, local files, source access, or out-of-band knowledge.
2. **Every exploit is patchable**: each exploit has a corresponding patch in `patches/` that closes the vulnerability while preserving the service's legitimate behavior.
3. **Checker exercises the full service**: `check`, `put`, and `get` must use the service's real workflow (accounts/auth, create/read/update/list/search/etc.), not a trivial key-value shim.
4. **Not trivially patchable or replaceable**: the vulnerable behavior must be woven into core functionality so it cannot be fixed by deleting one endpoint, and the service must be substantive enough that rewriting it defensively in another language is not a shortcut.
5. **Legitimate disguise**: the service must have a plausible real-world purpose and must never mention flags, flag IDs, the checker, CTF, vulnerabilities, exploits, or intentional insecurity in code, comments, UI, logs, errors, or filenames.
6. **Attackers can only steal flags**: no exploit may allow data deletion, arbitrary writes, RCE, service crashes, resource exhaustion, or SLA failure. Prefer read-only information disclosure.
7. **Deployable as-is**: everything under `service/` is distributed to teams and started automatically. It must build and run from a clean checkout with no manual setup.

## Repository Contract

| Path | Purpose |
| --- | --- |
| `service/` | Complete runnable service. Must include `docker-compose.yaml`. This is the only directory distributed to teams. |
| `service.yaml` | Service name and all exposed ports/protocols. Used by the platform and network monitoring. |
| `checker/checker.py` | Defines `check(host)`, `put(host, flag, flag_id)`, `get(host, flag, flag_id, private)`. |
| `checker/.template` | Platform marker. **Keep it exactly as-is.** |
| `exploits/<name>/exploit.py` | Black-box exploit taking `argv[1]` = target host/IP, `argv[2]` = flag ID. |
| `exploits/<name>/README.md` | Vulnerability, exploit mechanics, and patch guidance for that exploit. |
| `exploits/<name>/requirements.txt` | Optional; only needed packages. Exploit runs in `python:latest` and installs this file. |
| `patches/<name>.patch` | Patch for the exploit in `exploits/<name>/`; generated with `git diff`. |
| `test.sh` | End-to-end harness. Preserve its structure; only small, necessary changes. |
| `README.md` | Top-level service documentation for organizers/agents. |

### Remove all template remnants

Delete and replace the example service, exploit, and patch. Specifically remove:

- `service/main.py`, `service/requirements.txt`, and the example Dockerfile/compose contents (replace with the real deployment).
- `exploits/default_value/` and any empty or unused exploit directories (e.g., `exploits/tag_search_sqli/`).
- `patches/default_value.patch`.
- Any example data, comments, or endpoints that are not part of the new service.

Give the new service its own entrypoint and dependency files (for example `app.py` plus `pyproject.toml`, or a package directory). Do not reuse template names such as `main.py`/`requirements.txt` merely because they existed. Keep only files required by the platform.

## Choosing the Service and Port

- Pick a realistic category and purpose: web app, API, paste/wiki, notes, messaging, issue tracker, shop, booking, media manager, game backend, protocol daemon, etc.
- Choose **one random 4-digit port**, e.g. `4783`. Avoid common ports (`80`, `443`, `3000`, `5000`, `8000`, `8080`, `8888`, `9000`, `1234`, `1337`, etc.).
- Use the same port consistently in `service.yaml`, `docker-compose.yaml`, the Dockerfile/entrypoint, `checker/checker.py`, every exploit, README files, and any client code.
- If the service exposes multiple ports, list every public port and its protocol (`http`, `https`, or `tcp`) in `service.yaml`. The primary service port must be the random 4-digit port.
- Set the service name in `service.yaml` to the real service name, not `example`.

## Designing the Service

Aim for a service that:

- Has a coherent domain model and multiple legitimate features (authentication, ownership, CRUD, listing/search, updates, uploads, sharing, etc.).
- Stores flag content as ordinary user data, such as a note body, paste, message, profile field, filename, or document. The flag ID should map to a natural identifier (username, slug, document ID, email, room code), never a field literally named `flag_id`.
- Uses per-user authentication and ownership checks on all **write/delete** paths. The checker's account and secrets must be unguessable and must not be exposed by the vulnerability.
- Handles malformed input, large input, missing fields, and unexpected methods gracefully. No unhandled exceptions, no stack traces to clients, no debug endpoints, no test/backdoor routes.
- Keeps resource usage bounded. No unbounded queues, expensive unauthenticated operations, or global locks that an attacker can exhaust.
- Has enough inherent complexity that a patch requires understanding how components interact. Good sources of depth: layered auth, custom data formats, search/filter pipelines, background processing, protocol framing, migrations, templating, or multi-step workflows.

Avoid:

- Flags in source, environment variables, filenames, comments, logs, or default data.
- Words like `flag`, `flag_id`, `checker`, `exploit`, `vulnerable`, `insecure`, `CTF`, or "intentionally" anywhere in `service/`.
- One-line fixes where deleting a route or feature removes the vulnerability.
- Toy implementations that can be rewritten in another language in a few minutes.

## Vulnerability and Exploit Design

The intended exploitation path must satisfy all of these:

- **Black-box**: the exploit knows only target host/IP and flag ID.
- **Read-only**: stealing the flag must not require modifying or deleting server state. Writes, if unavoidable, may only affect the attacker's own account/data.
- **Low-impact**: no RCE, arbitrary file write/deletion, DB destruction, denial of service, or global state corruption. Prefer IDOR, auth bypass for reads, read-only injection, cache/key confusion, path traversal for reads, or similar information disclosure.
- **Rate-limit friendly**: the network allows **max 10 streams/connections per minute and 100 KB per stream**. Each exploit should use only a handful of requests and small payloads, ideally under a few KB and within 1–3 connections. No scanning, brute force, large downloads, or long-running sessions.
- **Deterministic enough**: the exploit should reliably recover the flag during `test.sh` and real rounds without depending on timing luck or external state.
- **Patchable**: the patch must close the bypass while keeping the legitimate workflow intact. It must apply cleanly to the service snapshot and must not simply disable a core feature.

If a vulnerability class inherently permits destructive actions (for example SQL injection that could `DROP` data), constrain it so only the read path is injectable, or choose a different vuln. The checker must still be able to plant and retrieve flags after any attacker interaction.

## Checker Contract

`checker/checker.py` must implement:

```python
def check(host: str):
    # Returns (public, private, success)

def put(host: str, flag: str, flag_id: str):
    # Returns (public, private, success)
    # May return (public, private, success, flag_id) to override flag_id

def get(host: str, flag: str, flag_id: str, private: str):
    # Returns (public, private, success)
```

Rules:

- `public` is scoreboard/debug text. Keep it empty for passing checks; use short, non-sensitive failure reasons.
- `private` is secret data passed from `put` to `get` (session token, password, object ID, etc.). It must be sufficient to retrieve the flag legitimately and must never be leaked by the intended exploit.
- `flag_id` is provided by the platform. Use it as the natural object identifier (username, slug, document ID, etc.), or return a custom one as a fourth value from `put`. Whatever `put` returns must be usable by `get` and by exploits.
- `check` must verify real uptime and basic functionality without mutating or deleting existing data.
- `put` must plant the flag through the same public workflow a real user would use, exercising multiple components where practical (e.g., register/login, create account, create document, set metadata).
- `get` must retrieve the flag through the legitimate authenticated path and verify exact equality.
- Exercise enough functionality that a broken core feature fails the checker: auth, create, read, list/search, update, ownership, etc. Do not build the checker around a hidden or special-purpose endpoint.
- Catch exceptions and return a failing tuple rather than crashing. Use network timeouts.
- Do not place flags, credentials, or privileged logic in the service; the checker supplies them at runtime.
- Keep the checker compatible with `test.sh` output parsing. Do not change the expected tuple structure.

## Deployment and `test.sh`

- `service/docker-compose.yaml` must start the full service with `docker compose up --build -d` from `./service`.
- Keep startup fast. If the service needs a database or warm-up, add healthchecks/`depends_on` and adjust the wait in `test.sh` (small changes only).
- Use a self-contained build. Avoid runtime dependencies on external networks or manual steps.
- Prefer ephemeral storage or add cleanup so repeated test runs start from a clean state. `docker compose down` is run at the end; if you use named volumes, ensure stale data cannot break the checker.
- `test.sh` must continue to:
  1. Build and start the service.
  2. Run the checker image (`glitchrange/checkertest`) and capture flag data.
  3. Print service logs.
  4. Run every `exploits/*/exploit.py` with `host.docker.internal` and the flag ID.
  5. Confirm the flag appears in exploit output.
  6. Stop the service with `docker compose down`.
- Do not weaken or bypass these checks. Only adjust details such as the wait time, cleanup, port references, or log handling if necessary.
- Exploits run inside `python:latest` with only their own directory mounted. They may install only what is in their `requirements.txt`, and they must use `host.docker.internal` for the target.

## Documentation Updates

### Top-level `README.md`

Replace the template README with:

- Service name and one-line purpose.
- Category (`web`, `pwn`, `crypto`, `misc`, etc.).
- Estimated difficulty for attackers and for defenders.
- Exposed port(s) and protocol(s).
- How to build, run, and test (`bash test.sh`).
- Brief overview of each vulnerability and its corresponding exploit/patch.
- Any deployment notes relevant to organizers.

### Per-exploit `exploits/<name>/README.md`

Include:

- **Vulnerability**: root cause, affected component/endpoint, and why it exists.
- **Exploit**: exact steps, requests/payloads, prerequisites, and why only host + flag ID are needed. Note request/byte counts relative to the rate limits.
- **Patch**: what to change, why it closes the issue, and why legitimate functionality still works. Reference `patches/<name>.patch`.

Keep each exploit directory self-contained. The directory name must match the patch filename base.

## Patches

- Generate each patch with `git diff` from the repository root against the clean service state.
- Name it `patches/<same-name-as-exploit-directory>.patch`.
- Include only the changes needed to fix that vulnerability. Do not bundle unrelated edits or template cleanup.
- Verify it applies cleanly: `git apply --check patches/<name>.patch`.
- The patch must not remove or disable a legitimate feature, and must not introduce new vulnerabilities.
- Confirm that after applying all patches, `test.sh` still passes the checker and legitimate flag storage/retrieval continues to work while exploits fail.

## Workflow

1. Inspect the existing template and confirm the platform contract.
2. Choose the service category, purpose, data model, port, and intended read-only vulnerability.
3. Replace `service/` entirely with the real implementation and deployment files.
4. Implement the checker around the legitimate user workflow.
5. Write the exploit(s) using only host + flag ID, within the stream/byte limits.
6. Write the corresponding patch(es) and verify they apply.
7. Write `exploits/<name>/README.md` for each exploit and update the top-level `README.md`.
8. Update `service.yaml` with the real name and random 4-digit port.
9. Run `bash test.sh` from a clean state and iterate until:
   - the checker can plant, retrieve, and validate flags,
   - the service stays healthy,
   - every exploit recovers the flag,
   - the service shuts down cleanly.
10. Audit before finishing.

## Final Audit Checklist

- [ ] `service/` contains no template remnants, placeholder endpoints, example data, or unused files.
- [ ] Random 4-digit port is consistent everywhere and listed in `service.yaml` with protocol.
- [ ] Service has a plausible real-world purpose and no references to flags, flag IDs, checker, CTF, vulnerabilities, or exploits.
- [ ] Checker exercises real functionality and correctly plants/retrieves flags.
- [ ] Every exploit works with only host + flag ID, stays within 10 streams/min and 100 KB/stream, and is read-only.
- [ ] No exploit can delete data, crash the service, exhaust resources, or fail SLA.
- [ ] Every exploit has a matching patch and a README with vulnerability, exploit, and patch details.
- [ ] All patches apply cleanly and preserve legitimate functionality.
- [ ] Top-level README documents service, category, difficulty, ports, and vulnerabilities.
- [ ] `bash test.sh` passes end-to-end from a clean checkout.
- [ ] `checker/.template` is unchanged.
- [ ] No secrets, credentials, or debug output are committed.
