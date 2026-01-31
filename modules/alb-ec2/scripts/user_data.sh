#!/bin/bash
set -euo pipefail
dnf -y update
dnf -y install nginx amazon-ssm-agent python3 python3-pip gcc make python3-devel
python3 -m pip install --no-cache-dir uwsgi
systemctl enable nginx
systemctl enable amazon-ssm-agent

install -d -m 0755 /opt/genlogs
token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
instance_id="unknown"
if [ -n "$token" ]; then
  instance_id=$(curl -s -H "X-aws-ec2-metadata-token: $token" "http://169.254.169.254/latest/meta-data/instance-id" || true)
fi
echo "$instance_id" > /opt/genlogs/instance_id.txt
cat > /opt/genlogs/app.py <<'PY'
def application(environ, start_response):
    instance_id = "unknown"
    try:
        with open("/opt/genlogs/instance_id.txt", "r", encoding="utf-8") as handle:
            instance_id = handle.read().strip() or "unknown"
    except OSError:
        pass

    body = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>GenLogs</title>
  <style>
    body { font-family: Arial, sans-serif; background: #0f172a; color: #e2e8f0; margin: 0; }
    header { padding: 40px 20px; text-align: center; background: #111827; }
    h1 { margin: 0; font-size: 2.4rem; }
    main { max-width: 900px; margin: 0 auto; padding: 24px; }
    .card { background: #1f2937; border-radius: 12px; padding: 20px; margin: 16px 0; }
    .pill { display: inline-block; padding: 6px 12px; border-radius: 999px; background: #22c55e; color: #0f172a; font-weight: bold; }
    .banner { margin-top: 12px; font-size: 0.95rem; color: #93c5fd; }
    button { background: #38bdf8; border: none; padding: 10px 14px; border-radius: 8px; font-weight: 600; cursor: pointer; }
    .counter { font-size: 2rem; margin: 12px 0; }
  </style>
</head>
<body>
  <header>
    <h1>GenLogs</h1>
    <p>POC landing page served by Nginx + uWSGI</p>
    <span class="pill">ALB + EC2</span>
    <div class="banner">Served by uWSGI · Instance: __INSTANCE_ID__</div>
  </header>
  <main>
    <div class="card">
      <h2>Traffic Pulse</h2>
      <p>Click to simulate log volume.</p>
      <div class="counter" id="counter">0</div>
      <button onclick="increment()">Generate Logs</button>
    </div>
    <div class="card">
      <h2>Status</h2>
      <p id="status">Ready to ingest events.</p>
    </div>
  </main>
  <script>
    let count = 0;
    function increment() {
      count += Math.floor(Math.random() * 7) + 1;
      document.getElementById("counter").textContent = count;
      document.getElementById("status").textContent = "Ingesting " + count + " events...";
    }
  </script>
</body>
</html>"""
    body = body.replace("__INSTANCE_ID__", instance_id)
    body_bytes = body.encode("utf-8")
    start_response("200 OK", [("Content-Type", "text/html"), ("Content-Length", str(len(body_bytes)))])
    return [body_bytes]
PY

install -d -m 0755 /etc/uwsgi
cat > /etc/uwsgi/genlogs.ini <<'INI'
[uwsgi]
chdir = /opt/genlogs
module = app:application
master = true
processes = 2
threads = 2
socket = /run/uwsgi/genlogs.sock
chown-socket = nginx:nginx
chmod-socket = 660
vacuum = true
die-on-term = true
INI

cat > /etc/systemd/system/uwsgi-genlogs.service <<'UNIT'
[Unit]
Description=uWSGI for GenLogs
After=network.target

[Service]
ExecStart=/usr/local/bin/uwsgi --ini /etc/uwsgi/genlogs.ini
User=nginx
Group=nginx
Restart=always
RuntimeDirectory=uwsgi
RuntimeDirectoryMode=0775

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/nginx/conf.d/genlogs.conf <<'CONF'
server {
  listen 80;
  server_name _;

  location / {
    include uwsgi_params;
    uwsgi_pass unix:/run/uwsgi/genlogs.sock;
  }
}
CONF

systemctl daemon-reload
systemctl start amazon-ssm-agent
systemctl enable uwsgi-genlogs
systemctl start uwsgi-genlogs
systemctl start nginx
