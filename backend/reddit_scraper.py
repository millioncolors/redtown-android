import os
import sys
import json
import time
import html
import requests
import subprocess
from urllib.parse import urlparse
from datetime import datetime, timezone

HEADERS = {
    "User-Agent": "RedTownScraper/2.0"
}

BASE_DIR = "/storage/emulated/0/Download/RedTown/media"
MIN_FILE_SIZE = 10 * 1024  # 10 KB
TIMEOUT = 20


def now():
    return datetime.now(timezone.utc).isoformat()


def valid_response(resp, expected):
    ct = resp.headers.get("Content-Type", "")
    cl = int(resp.headers.get("Content-Length", "0") or 0)
    return expected in ct and cl >= MIN_FILE_SIZE


def download_file(url, out_path, expected_type):
    try:
        with requests.get(url, headers=HEADERS, stream=True, timeout=TIMEOUT) as r:
            if not valid_response(r, expected_type):
                return False

            with open(out_path, "wb") as f:
                for chunk in r.iter_content(8192):
                    f.write(chunk)

        if os.path.getsize(out_path) < MIN_FILE_SIZE:
            os.remove(out_path)
            return False

        return True
    except:
        if os.path.exists(out_path):
            os.remove(out_path)
        return False


def scrape(subreddit, job_id):
    job_root = os.path.join(BASE_DIR, job_id)
    img_dir = os.path.join(job_root, "images")
    gif_dir = os.path.join(job_root, "gifs")
    vid_dir = os.path.join(job_root, "videos")

    os.makedirs(img_dir, exist_ok=True)
    os.makedirs(gif_dir, exist_ok=True)
    os.makedirs(vid_dir, exist_ok=True)

    stats = {
        "images": 0,
        "gifs": 0,
        "videos": 0,
        "files_downloaded": 0,
        "started_at": now(),
    }

    after = None
    empty_pages = 0

    while empty_pages < 3:
        url = f"https://www.reddit.com/{subreddit}/new.json"
        params = {"limit": 100}
        if after:
            params["after"] = after

        r = requests.get(url, headers=HEADERS, params=params, timeout=TIMEOUT)
        if r.status_code != 200:
            break

        posts = r.json()["data"]["children"]
        if not posts:
            empty_pages += 1
            continue

        empty_pages = 0

        for post in posts:
            d = post["data"]

            # VIDEO
            if d.get("is_video") and "v.redd.it" in d.get("url", ""):
                try:
                    subprocess.run(
                        [
                            "yt-dlp",
                            "-f", "bv*+ba/b",
                            "-o", os.path.join(vid_dir, "%(id)s.%(ext)s"),
                            d["url"],
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=300,
                    )
                    stats["videos"] += 1
                    stats["files_downloaded"] += 1
                except:
                    pass
                continue

            # GALLERY / IMAGES
            media = d.get("media_metadata", {})
            for item in media.values():
                src = item.get("s", {}).get("u")
                if not src:
                    continue
                clean = html.unescape(src.split("?")[0])
                ext = os.path.splitext(clean)[1].lower()
                out = os.path.join(img_dir, os.path.basename(clean))

                if ext in (".jpg", ".jpeg", ".png"):
                    if download_file(clean, out, "image"):
                        stats["images"] += 1
                        stats["files_downloaded"] += 1

            # DIRECT GIF
            url2 = d.get("url_overridden_by_dest", "")
            if url2.endswith(".gif"):
                out = os.path.join(gif_dir, os.path.basename(url2))
                if download_file(url2, out, "image"):
                    stats["gifs"] += 1
                    stats["files_downloaded"] += 1

        after = r.json()["data"].get("after")
        if not after:
            break

        time.sleep(0.5)

    stats["ended_at"] = now()

    if stats["files_downloaded"] == 0:
        return False, stats

    stats_path = f"/storage/emulated/0/Download/RedTown/status/{job_id}_stats.json"
    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=2)

    return True, stats


if __name__ == "__main__":
    ok, stats = scrape(sys.argv[1], sys.argv[2])
    sys.exit(0 if ok else 1)
