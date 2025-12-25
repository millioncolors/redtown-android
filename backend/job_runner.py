import os
import json
import time
import subprocess
from datetime import datetime, timezone

BASE = "/storage/emulated/0/Download/RedTown"
STATUS = os.path.join(BASE, "status")
LOGS = os.path.join(BASE, "logs")
SCRAPER = os.path.join(os.path.dirname(__file__), "reddit_scraper.py")

os.makedirs(STATUS, exist_ok=True)
os.makedirs(LOGS, exist_ok=True)


def now():
    return datetime.now(timezone.utc).isoformat()


def write_status(job_id, state, stats=None, error=None):
    with open(os.path.join(STATUS, f"{job_id}.json"), "w") as f:
        json.dump({
            "job_id": job_id,
            "state": state,
            "updated_at": now(),
            "stats": stats or {},
            "error": error,
        }, f, indent=2)


def main():
    print("🚀 RedTown Job Runner started")

    while True:
        jobs = sorted(
            f for f in os.listdir(BASE)
            if f.startswith("job_") and f.endswith(".json")
        )

        for jf in jobs:
            job_id = jf.replace(".json", "")
            status_file = os.path.join(STATUS, f"{job_id}.json")

            if os.path.exists(status_file):
                with open(status_file) as f:
                    if json.load(f)["state"] in ("running", "completed", "failed"):
                        continue

            with open(os.path.join(BASE, jf)) as f:
                job = json.load(f)

            print(f"🆕 Processing job: {job_id}")
            write_status(job_id, "running")

            proc = subprocess.run(
                ["python", SCRAPER, job["target"], job_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

            stats_path = os.path.join(STATUS, f"{job_id}_stats.json")
            stats = {}

            if os.path.exists(stats_path):
                with open(stats_path) as f:
                    stats = json.load(f)

            if proc.returncode == 0 and stats.get("files_downloaded", 0) > 0:
                write_status(job_id, "completed", stats=stats)
                print(f"✅ Job finished: {job_id} (completed)")
            else:
                write_status(job_id, "failed", error="No valid media downloaded")
                print(f"❌ Job finished: {job_id} (failed)")

        time.sleep(2)


if __name__ == "__main__":
    main()
