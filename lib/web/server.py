from flask import Flask, request, send_file
import re

app = Flask(__name__)


@app.route("/map")
def index():
    return send_file("RainTracker.html")


@app.route("/save-map", methods=["POST"])  # GET is default
def save():
    data = (
        request.get_json()
    )  # parses the JSON body of the incomung request from map.html
    name = re.sub(
        r"[^a-zA-Z0-9_-]", "_", data["name"]
    )  # sanitizes the filename stripping the potential path
    with open(f"../../config/{name}.csv", "w") as f:
        f.write(data["points"])
    return "ok"


app.run(host="0.0.0.0", port=8080)
