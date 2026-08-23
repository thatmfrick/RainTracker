from flask import Flask, request, send_file
import re

app = Flask(__name__)


@app.route("/")
def index():
    return send_file("map.html")


@app.route("/save", methods=["POST"])
def save():
    data = request.get_json()
    name = re.sub(r"[^a-zA-Z0-9_-]", "_", data["name"])
    with open(f"../../config/{name}.csv", "w") as f:
        f.write(data["points"])
    return "ok"


app.run(host="0.0.0.0", port=8080)
