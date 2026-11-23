"""CTV Launchpad — static Tubi Growth paid CTV IO builder on Teflon.

Serves static/index.html only. No Databricks credentials or API proxies.
Staging injects a banner when CTV_LAUNCHPAD_ENV=staging.
"""

import hashlib
import os
import sys

from flask import Flask, Response, jsonify, request, send_from_directory

HERE = os.path.dirname(os.path.abspath(__file__))
STATIC = os.path.join(HERE, "static")

app = Flask(__name__, static_folder=None)

APP_ENV = (os.environ.get("CTV_LAUNCHPAD_ENV") or "production").strip().lower()
if APP_ENV not in ("production", "staging"):
    APP_ENV = "production"


def page_build():
    """md5 and size for the index.html this container holds."""
    try:
        raw = open(os.path.join(STATIC, "index.html"), "rb").read()
    except OSError as exc:  # noqa: BLE001
        return {"error": str(exc)}
    return {
        "md5": hashlib.md5(raw).hexdigest(),
        "bytes": len(raw),
    }


PAGE = page_build()

_STAGING_BANNER = (
    b'<div id="stg_banner" style="position:sticky;top:0;z-index:9999;'
    b'background:#92400e;color:#fff;font:600 13px/1.3 system-ui,sans-serif;'
    b'padding:8px 14px;text-align:center;letter-spacing:.2px">'
    b'STAGING \xe2\x80\x94 preview only. Production is '
    b'ctv-launchpad.tf.int.tubi.io'
    b'</div>'
)


@app.after_request
def no_store(resp):
    """Never cache the page a deploy exists to replace."""
    if resp.mimetype == "text/html":
        resp.headers["Cache-Control"] = "no-store, must-revalidate"
        resp.headers["Pragma"] = "no-cache"
        resp.headers["X-Page-Build"] = PAGE.get("md5", "unknown")
    return resp


@app.route("/healthz")
def healthz():
    return jsonify(ok=True, env=APP_ENV, page=PAGE)


def _html_page(filename):
    path = os.path.join(STATIC, filename)
    with open(path, "rb") as fh:
        body = fh.read()
    if APP_ENV == "staging":
        low = body.lower()
        i = low.find(b"<body")
        if i >= 0:
            j = low.find(b">", i)
            if j >= 0:
                body = body[: j + 1] + _STAGING_BANNER + body[j + 1 :]
        body = body.replace(
            b"<title>CTV Launchpad</title>",
            b"<title>CTV Launchpad STAGING</title>",
            1,
        )
    resp = Response(body, mimetype="text/html; charset=utf-8")
    resp.headers["Content-Length"] = str(len(body))
    resp.headers["X-Ctv-Launchpad-Env"] = APP_ENV
    return resp


@app.route("/")
def index():
    return _html_page("index.html")


@app.route("/<path:name>")
def static_file(name):
    return send_from_directory(STATIC, name)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(
        "ctv-launchpad: env=%s page_md5=%s port=%s"
        % (APP_ENV, PAGE.get("md5", "?"), port),
        file=sys.stderr,
    )
    app.run(host="0.0.0.0", port=port)
