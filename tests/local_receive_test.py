"""Verify live simulation delivery through local Mosquitto (no synthetic publish)."""
import json
import threading
import paho.mqtt.client as mqtt

received = {}
complete = threading.Event()
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

def on_connect(c, _u, _f, reason, _p):
    if not reason.is_failure:
        c.subscribe("agriwatch/farm-001/+/sensors/+/telemetry")

def on_message(c, _u, message):
    p = json.loads(message.payload)
    if "station_id" not in p:
        return
    received[p["sensor_id"]] = p
    if len(received) >= 54:
        complete.set()

client.on_connect = on_connect
client.on_message = on_message
try:
    client.connect("127.0.0.1", 1883, 30)
    client.loop_start()
    assert complete.wait(25), f"Only {len(received)}/54 sensors received"
    parcels = {p["parcel_id"] for p in received.values()}
    stations = {p["station_id"] for p in received.values()}
    assert len(parcels) == 6 and len(stations) == 18
    assert all(p["simulated"] is True for p in received.values())
    assert {p["land_use"] for p in received.values()} == {"bare", "planted"}
    assert all(sum(p["parcel_id"] == parcel for p in received.values()) == 9 for parcel in parcels)
    print("PASS: live Godot -> bridge -> Mosquitto -> subscriber: 54 sensors, 18 stations, 6 parcels, bare + planted")
finally:
    client.disconnect()
    client.loop_stop()
