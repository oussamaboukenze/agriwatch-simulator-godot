"""Opt-in public broker test: only synthetic data on a random topic."""
import json
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
import paho.mqtt.client as mqtt

topic = "agriwatch/test-" + uuid.uuid4().hex + "/telemetry"
received = threading.Event()
subscribed = threading.Event()
subscriber = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
subscriber.on_connect = lambda c, u, f, r, p: c.subscribe(topic)
subscriber.on_subscribe = lambda *args: subscribed.set()
subscriber.on_message = lambda c, u, m: received.set() if json.loads(m.payload).get("simulated") is True else None

def post(path, data):
    req = urllib.request.Request("http://127.0.0.1:8765" + path, json.dumps(data).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=3))

process = subprocess.Popen([sys.executable, "bridge/bridge.py"], stdout=subprocess.DEVNULL)
try:
    time.sleep(1)
    subscriber.connect("broker.hivemq.com", 1883, 30)
    subscriber.loop_start()
    assert subscribed.wait(12), "Subscription timeout"
    post("/configure", {"host": "broker.hivemq.com", "port": 1883, "client_id": "agriwatch-test-" + uuid.uuid4().hex})
    for _ in range(24):
        if post("/status", {}).get("connected"):
            break
        time.sleep(0.5)
    else:
        raise AssertionError("Bridge connection timeout")
    response = post("/publish", {"messages": [{"topic": topic, "payload": {"simulated": True, "value": 35.2}}]})
    assert response["accepted"] == 1
    assert received.wait(12), "No message received"
    post("/disconnect", {})
    assert post("/publish", {"messages": [{"topic": topic, "payload": {}}]})["accepted"] == 0
    print("PASS: bridge HTTP -> HiveMQ TCP -> independent subscriber; offline messages dropped")
finally:
    subscriber.disconnect()
    subscriber.loop_stop()
    process.terminate()
    process.wait(timeout=5)
