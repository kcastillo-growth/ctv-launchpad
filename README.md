# CTV Launchpad

Self-serve tool for Tubi Growth paid CTV campaigns. Build a campaign once; produce partner IO sheets and AM emails (Fire TV, Roku, Samsung, and more).

- **Prod:** https://ctv-launchpad.tf.int.tubi.io/
- **Staging:** https://ctv-launchpad-staging.tf.int.tubi.io/

Static-only Flask app on Teflon. State lives in the browser (`localStorage`). No Databricks secrets.

## Layout

```
README.md
ctv-launchpad/
  app.py              # serves index.html + /healthz
  Dockerfile
  requirements.txt    # flask, gunicorn
  teflon.toml         # name = "ctv-launchpad", port = 8080
  deploy.sh           # --staging / --keep-secret
  static/index.html   # the Launchpad UI
```

## Local run

```sh
cd ctv-launchpad
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python app.py
# open http://127.0.0.1:8080/
```

## Deploy (Teflon)

From `ctv-launchpad/`:

```sh
./deploy.sh --staging --keep-secret   # staging preview
./deploy.sh --keep-secret             # production
```

`--keep-secret` is a no-op for secrets (there are none) but still deploys. Staging sets `CTV_LAUNCHPAD_ENV=staging` and restores `teflon.toml` to the prod app name afterward.

Check: `curl -s https://ctv-launchpad.tf.int.tubi.io/healthz`
