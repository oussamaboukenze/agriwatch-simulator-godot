"""Local HTTP -> MQTT bridge. No telemetry queue while disconnected."""
import json
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import paho.mqtt.client as mqtt


class Bridge:
    def __init__(self):
        self.client = None
        self.connected = False
        self.status = "Passerelle prête, broker non configuré"
        self.acked = 0
        self.lock = threading.RLock()

    def stop(self):
        old, self.client = self.client, None
        self.connected = False
        if old:
            old.disconnect()
            old.loop_stop()

    def configure(self, cfg):
        host = str(cfg.get("host", "localhost")).strip()
        port = int(cfg.get("port", 1883))
        if not host or not 1 <= port <= 65535:
            raise ValueError("Hôte ou port invalide")
        self.stop()
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                             client_id=str(cfg.get("client_id", "agriwatch")),
                             protocol=mqtt.MQTTv311)
        client.max_queued_messages_set(32)
        client.reconnect_delay_set(1, 30)
        if cfg.get("username"):
            client.username_pw_set(cfg["username"], cfg.get("password", ""))
        if cfg.get("tls"):
            client.tls_set_context(ssl.create_default_context())

        def connected(c, _u, _f, reason, _p):
            if c is self.client:
                self.connected = not reason.is_failure
                self.status = "Broker connecté" if self.connected else "Connexion refusée : " + str(reason)

        def disconnected(c, _u, _f, _reason, _p):
            if c is self.client:
                self.connected = False
                self.status = "Broker déconnecté · reconnexion automatique 1–30 s"
                # Prevent stale telemetry from being replayed after a sensor failure.
                # QoS 0 has no offline queue in Paho.

        def published(c, _u, _mid, _reason, _p):
            if c is self.client:
                self.acked += 1

        def failed(c, _u):
            if c is self.client:
                self.connected = False
                self.status = "Échec réseau/TLS · vérifier hôte, port, certificats ; nouvel essai automatique"

        client.on_connect = connected
        client.on_disconnect = disconnected
        client.on_publish = published
        client.on_connect_fail = failed
        self.client = client
        self.status = "Connexion au broker en cours"
        client.connect_async(host, port, keepalive=30)
        client.loop_start()

    def snapshot(self):
        return {"connected": self.connected, "status": self.status, "acked": self.acked}


bridge = Bridge()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass  # Never log requests, credentials or payloads.

    def do_POST(self):
        response = {}
        code = 200
        try:
            # Reject browser-origin requests and keep the bridge loopback-only.
            if self.headers.get("Origin"):
                raise ValueError("Origine navigateur interdite")
            size = int(self.headers.get("Content-Length", 0))
            if not 0 <= size <= 65536:
                raise ValueError("Requête trop grande")
            data = json.loads(self.rfile.read(size) or b"{}")
            with bridge.lock:
                if self.path == "/configure":
                    bridge.configure(data)
                elif self.path == "/disconnect":
                    bridge.stop()
                    bridge.status = "MQTT déconnecté volontairement"
                elif self.path == "/publish":
                    accepted = 0
                    for msg in data.get("messages", [])[:128]:
                        if bridge.connected and bridge.client:
                            topic = msg["topic"]
                            if not topic.startswith("agriwatch/") or "+" in topic or "#" in topic:
                                raise ValueError("Topic invalide")
                            info = bridge.client.publish(topic, json.dumps(msg["payload"], ensure_ascii=False), qos=0, retain=False)
                            accepted += info.rc == mqtt.MQTT_ERR_SUCCESS
                    response["accepted"] = accepted
                elif self.path != "/status":
                    raise ValueError("Route inconnue")
                response.update(bridge.snapshot())
        except Exception:
            code = 400
            response = {"connected": bridge.connected, "status": "Configuration ou requête invalide (détails masqués pour protéger les secrets)"}
        body = json.dumps(response).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    print("AgriWatch : passerelle sur http://127.0.0.1:8765 ; Ctrl+C pour arrêter")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        bridge.stop()
        server.server_close()
