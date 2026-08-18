import logging
import os
import sys

import requests
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("application-a")

B_HOST = os.environ.get("B_HOST", "")
B_PORT = os.environ.get("B_PORT", "8080")
PORT = int(os.environ.get("PORT", "8080"))
TIMEOUT = float(os.environ.get("UPSTREAM_TIMEOUT", "3"))

app = FastAPI()


@app.get("/sample-req")
def sample_req():
    """Static diagnostic endpoint - fixed response, no downstream calls.

    Meant to be hit manually (e.g. curl from inside application-c's pod) to confirm
    application-a is reachable at all, independent of the real /relay traffic.
    """
    log.info("diagnostic /sample-req hit")
    return JSONResponse(
        status_code=200,
        content={
            "status": "reachable",
            "hint": "application-a is reachable. Can you check the env vars for application-c? "
                     "Could be something wrong there.",
        },
    )


@app.get("/relay")
def relay():
    log.info("received request on /relay")
    b_url = f"http://{B_HOST}:{B_PORT}/relay"

    try:
        resp = requests.get(b_url, timeout=TIMEOUT)
        body = resp.json() if resp.content else {}
        if resp.status_code == 200 and body.get("status") == "ok":
            log.info("able to reach application-b and got a valid response")
            return JSONResponse(status_code=200, content={"status": "ok"})
        log.info(
            "able to reach application-b, but not getting the expected response - "
            "something wrong at application-b's end"
        )
        return JSONResponse(status_code=502, content={"status": "error", "stage": "a-to-b", "detail": body})
    except requests.exceptions.RequestException:
        log.info("received req from application-c but unable to send req to application-b")
        return JSONResponse(
            status_code=502,
            content={"status": "error", "stage": "a-to-b", "detail": "could not reach application-b"},
        )


if __name__ == "__main__":
    log.info("=" * 60)
    log.info("Can you check if application-b is scheduled or not?")
    log.info("(Also: announce in the meeting that the first flag has been captured!)")
    log.info("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")
