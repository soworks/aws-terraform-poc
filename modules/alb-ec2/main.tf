data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      app         = var.app_name
      component   = "app"
      environment = var.environment
      managedby   = "terraform"
      owner       = "DevOps"
      project     = "${var.app_name}-poc"
    }
  )

  name_prefix = "${var.app_name}-${var.environment}"
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "ALB security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group_rule" "alb_http_in" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_http_cidrs
  description       = "Allow HTTP to ALB"
}

resource "aws_security_group_rule" "alb_all_out" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "App server security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name_prefix}-app-sg" })
}

resource "aws_security_group_rule" "app_http_in" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow HTTP from ALB"
}

resource "aws_security_group_rule" "app_all_out" {
  type              = "egress"
  security_group_id = aws_security_group.app.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

resource "aws_iam_role" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"
  role        = aws_iam_role.ec2.name
  tags        = local.common_tags
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(<<-EOF
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
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  tags = local.common_tags
}

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  idle_timeout       = 60
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    path                = "/"
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-asg"
  max_size            = 1
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-app"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
