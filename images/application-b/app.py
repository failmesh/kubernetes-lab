import logging
import os
import sys

import requests
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("application-b")

C_HOST = os.environ.get("C_HOST", "")
C_PORT = os.environ.get("C_PORT", "8080")
PORT = int(os.environ.get("PORT", "8080"))
TIMEOUT = float(os.environ.get("UPSTREAM_TIMEOUT", "3"))

app = FastAPI()


@app.get("/relay")
def relay():
    log.info("received request from application-a")
    c_url = f"http://{C_HOST}:{C_PORT}/relay"

    try:
        resp = requests.get(c_url, timeout=TIMEOUT)
        if resp.status_code == 200:
            log.info("successfully forwarded to application-c and got a valid response")
            return JSONResponse(status_code=200, content={"status": "ok"})
        log.info("forwarded to application-c but got an unexpected status: %s", resp.status_code)
        return JSONResponse(status_code=502, content={"status": "error", "stage": "b-to-c"})
    except requests.exceptions.RequestException:
        log.info("unable to reach application-c")
        return JSONResponse(status_code=502, content={"status": "error", "stage": "b-to-c"})


if __name__ == "__main__":
    log.info("=" * 60)
    log.info("Can you check if application-c is scheduled or not?")
    log.info("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")
