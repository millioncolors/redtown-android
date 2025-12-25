import os
import sys
import json
import time
import html
import requests
import subprocess
from datetime import datetime, timezone

HEADERS = {
    "User-Agent": "RedTownScraper/3.0"
}

BASE_DIR = "/storage/emulated/0/Download/RedTown/media"
MIN_FILE_SIZE = 8 * 1024
TIMEOUT = 20


def now():
    return datetime.now(timezone.utc).isoformat()


def is_valid_media(resp, expected_prefix):
    ct = resp.headers.get("Content-Type", "")
    cl = int(resp.headers.get("Content-Length", "0") or 0)
    return ct.startswith(expected_prefix) and cl >= MIN_FILE_SIZE


def download_binary(url, out, expected_prefix):
    try:
        with requests.get(url, headers=HEADERS, stream=True, timeout=TIMEOUT) as r:
            if not is_valid_media(r, expected_prefix):
                return False
            with open(out, "wb") as f:
                for c in r.iter_content(8192):
                    f.write(c)
        return os.path.getsize(out) >= MIN_FILE_SIZE
    except:
        if os.path.exists(out):
            os.remove(out)
        return False


def scrape(subreddit, job_id):
    root = os.path.join(BASE_DIR, job_id)
    img_dir = os.path.join(root, "images")
    gif_dir = os.path.join(root, "gifs")
    vid_dir = os.path.join(root, "videos")

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
    empty = 0

    while empty < 3:
        url = f"https://www.reddit.com/{subreddit}/new.json"
        params = {"limit": 100}
        if after:
            params["after"] = after

        r = requests.get(url, headers=HEADERS, params=params, timeout=TIMEOUT)
        if r.status_code != 200:
            break

        posts = r.json()["data"]["children"]
        if not posts:
            empty += 1
            continue

        empty = 0

        for post in posts:
            d = post["data"]

            # ---------- VIDEO ----------
            video_url = None
            if d.get("is_video") and d.get("media", {}).get("reddit_video"):
                video_url = d["media"]["reddit_video"]["fallback_url"]
            elif any(h in d.get("url", "") for h in ["redgifs.com", "streamable.com", "imgur.com"]):
                video_url = d.get("url")

            if video_url:
                try:
                    subprocess.run(
                        [
                            "yt-dlp",
                            "-f", "bv*+ba/b",
                            "-o", os.path.join(vid_dir, "%(id)s.%(ext)s"),
                            video_url,
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=300,
                    )
                    stats["videos"] += 1
                    stats["files_downloaded"] += 1
                except:
                    pass

            # ---------- GALLERY ----------
            for item in d.get("media_metadata", {}).values():
                src = item.get("s", {}).get("u")
                if not src:
                    continue
                clean = html.unescape(src.split("?")[0])
                out = os.path.join(img_dir, os.path.basename(clean))
                if download_binary(clean, out, "image/"):
                    stats["images"] += 1
                    stats["files_downloaded"] += 1

            # ---------- SINGLE IMAGE ----------
            url2 = d.get("url_overridden_by_dest", "")
            if url2.lower().endswith((".jpg", ".jpeg", ".png")):
                out = os.path.join(img_dir, os.path.basename(url2))
                if download_binary(url2, out, "image/"):
                    stats["images"] += 1
                    stats["files_downloaded"] += 1

            # ---------- GIF ----------
            if url2.lower().endswith(".gif"):
                out = os.path.join(gif_dir, os.path.basename(url2))
                if download_binary(url2, out, "image/"):
                    stats["gifs"] += 1
                    stats["files_downloaded"] += 1

        after = r.json()["data"].get("after")
        if not after:
            break

        time.sleep(0.4)

    stats["ended_at"] = now()

    stats_path = f"/storage/emulated/0/Download/RedTown/status/{job_id}_stats.json"
    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=2)

    # SUCCESS if ANY media downloaded
    success = stats["files_downloaded"] > 0
    return success, stats


if __name__ == "__main__":
    ok, _ = scrape(sys.argv[1], sys.argv[2])
    sys.exit(0 if ok else 1)
