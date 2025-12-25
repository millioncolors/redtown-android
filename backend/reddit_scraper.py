import sys
import requests
import os
import time
import json
import html
import subprocess

HEADERS = {
    "User-Agent": "RedTownScraper/1.0"
}

BASE_ROOT = "/storage/emulated/0/Download/RedTown/media"
MAX_EMPTY_PAGES = 3
MAX_IDLE_SECONDS = 60


def extract_media_urls(post):
    urls = []

    if post.get("is_video") and post.get("url"):
        urls.append(post["url"])

    direct = post.get("url_overridden_by_dest")
    if direct:
        urls.append(direct)

    preview = post.get("preview", {})
    for img in preview.get("images", []):
        src = img.get("source", {}).get("url")
        if src:
            urls.append(src)

    media_meta = post.get("media_metadata", {})
    for item in media_meta.values():
        if item.get("status") == "valid":
            p = item.get("s", {}).get("u")
            if p:
                urls.append(p)

    return list(set(urls))


def scrape(subreddit, job_id):
    start_time = time.time()
    last_download_time = time.time()

    images = gifs = videos = files_downloaded = 0
    after = None
    empty_pages = 0

    job_root = os.path.join(BASE_ROOT, job_id)
    img_dir = os.path.join(job_root, "images")
    vid_dir = os.path.join(job_root, "videos")
    gif_dir = os.path.join(job_root, "gifs")

    os.makedirs(img_dir, exist_ok=True)
    os.makedirs(vid_dir, exist_ok=True)
    os.makedirs(gif_dir, exist_ok=True)

    while True:
        if time.time() - last_download_time > MAX_IDLE_SECONDS:
            break

        url = f"https://www.reddit.com/{subreddit}/new.json"
        params = {"limit": 100}
        if after:
            params["after"] = after

        r = requests.get(url, headers=HEADERS, params=params, timeout=20)
        if r.status_code != 200:
            break

        data = r.json()
        posts = data["data"]["children"]

        if not posts:
            empty_pages += 1
        else:
            empty_pages = 0

        for post in posts:
            d = post["data"]
            media_urls = extract_media_urls(d)

            for media_url in media_urls:
                clean = html.unescape(media_url.split("?")[0])

                # VIDEO via yt-dlp
                if "v.redd.it" in clean or "redgifs.com" in clean:
                    try:
                        subprocess.run(
                            [
                                "yt-dlp",
                                "-o",
                                os.path.join(vid_dir, "%(id)s.%(ext)s"),
                                clean,
                            ],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        videos += 1
                        files_downloaded += 1
                        last_download_time = time.time()
                    except:
                        pass
                    continue

                # IMAGES / GIFS
                if clean.lower().endswith((".jpg", ".jpeg", ".png")):
                    out_dir = img_dir
                    images += 1
                elif clean.lower().endswith(".gif"):
                    out_dir = gif_dir
                    gifs += 1
                else:
                    continue

                fname = os.path.join(out_dir, os.path.basename(clean))
                if os.path.exists(fname):
                    continue

                try:
                    with requests.get(clean, stream=True, timeout=20) as resp:
                        with open(fname, "wb") as f:
                            for chunk in resp.iter_content(8192):
                                f.write(chunk)
                    files_downloaded += 1
                    last_download_time = time.time()
                except:
                    pass

        after = data["data"].get("after")
        if not after:
            empty_pages += 1

        if empty_pages >= MAX_EMPTY_PAGES:
            break

        time.sleep(0.5)

    stats = {
        "job_id": job_id,
        "subreddit": subreddit,
        "files_downloaded": files_downloaded,
        "images": images,
        "videos": videos,
        "gifs": gifs,
        "duration_seconds": int(time.time() - start_time),
    }

    stats_path = f"/storage/emulated/0/Download/RedTown/status/{job_id}_stats.json"
    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=2)

    sys.exit(0)


if __name__ == "__main__":
    scrape(sys.argv[1], sys.argv[2])
