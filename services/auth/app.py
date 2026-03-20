import os

import requests
from flask import Flask, jsonify

app = Flask(__name__)

CART_URL = os.getenv("CART_URL", "http://cart")


@app.route("/")
def home():
    try:
        cart_response = requests.get(CART_URL, timeout=2)
        cart_response.raise_for_status()
        cart_payload = cart_response.json()
    except Exception as exc:  # pragma: no cover
        cart_payload = {"status": "unavailable", "error": str(exc)}

    return jsonify({"service": "auth", "status": "ok", "cart": cart_payload})


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
