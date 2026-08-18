import logging
import os
import sys
import threading
import time
from contextlib import asynccontextmanager

import requests
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("application-c")

A_HOST = os.environ.get("A_HOST", "")
A_PORT = os.environ.get("A_PORT", "8080")
PORT = int(os.environ.get("PORT", "8080"))
INTERVAL = float(os.environ.get("REQUEST_INTERVAL", "15"))
TIMEOUT = float(os.environ.get("UPSTREAM_TIMEOUT", "3"))


def request_loop():
    url = f"http://{A_HOST}:{A_PORT}/relay"
    while True:
        try:
            resp = requests.get(url, timeout=TIMEOUT)
            if resp.status_code == 200:
                log.info("request completed successfully end-to-end (C -> A -> B -> C)")
            else:
                log.info(
                    "req was sent successfully however did not receive an expected response "
                    "(status=%s). Maybe something wrong with application-a?", resp.status_code,
                )
        except requests.exceptions.RequestException as exc:
            log.info(
                "sending req to application-a but seems like something is wrong. "
                "Is %s working? (%s)", url, exc,
            )
        time.sleep(INTERVAL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting periodic requests to application-a every %ss...", INTERVAL)
    threading.Thread(target=request_loop, daemon=True).start()
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/relay")
def relay():
    log.info("received callback on /relay from application-b")
    return JSONResponse(status_code=200, content={"status": "ok", "from": "application-c"})


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")
