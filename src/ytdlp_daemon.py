# Servidor residente de yt-dlp para el reproductor (lo lanza src/resolver.rs).
#
# Lee peticiones JSON por stdin, una por línea: {"id": "<videoId>"}
# Responde por stdout, una por línea: {"id": ..., "url": ...} o {"id": ..., "error": ...}
#
# Mantener yt-dlp cargado ahorra el arranque de Python (~0,7 s) y reutiliza el código del
# reproductor de YouTube ya descargado entre peticiones. Atiende dos a la vez y se cierra
# solo tras IDLE_SECONDS sin peticiones para no ocupar memoria.

import json
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import yt_dlp

IDLE_SECONDS = 60
OPTIONS = json.loads(sys.argv[1])

local = threading.local()
write_lock = threading.Lock()
last_request = time.monotonic()


def downloader():
    # Una instancia por hilo: YoutubeDL no está pensado para usarse a la vez desde varios.
    if not hasattr(local, "ydl"):
        local.ydl = yt_dlp.YoutubeDL(OPTIONS)
    return local.ydl


def reply(message):
    with write_lock:
        sys.stdout.write(json.dumps(message) + "\n")
        sys.stdout.flush()


def resolve(video_id):
    try:
        info = downloader().extract_info("https://www.youtube.com/watch?v=" + video_id, download=False)
        url = info.get("url") or ""
        if not url:
            raise ValueError("yt-dlp no devolvió ninguna URL")
        reply({"id": video_id, "url": url})
    except Exception as error:  # noqa: BLE001 — cualquier fallo se devuelve como texto
        reply({"id": video_id, "error": str(error).splitlines()[0][:300]})


def watchdog():
    while True:
        time.sleep(5)
        if time.monotonic() - last_request > IDLE_SECONDS:
            sys.stdout.flush()
            # os._exit: no esperar a los hilos de trabajo ni guardar cookies.
            import os
            os._exit(0)


def main():
    global last_request
    threading.Thread(target=watchdog, daemon=True).start()
    reply({"ready": True})
    with ThreadPoolExecutor(max_workers=2) as pool:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            last_request = time.monotonic()
            try:
                video_id = json.loads(line)["id"]
            except (ValueError, KeyError):
                continue
            pool.submit(resolve, video_id)


main()
