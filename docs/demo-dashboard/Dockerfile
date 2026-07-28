# Grafana with the Builder Plaza dashboard baked in.
#
# Fargate has no host volumes to mount provisioning into, so the datasource and
# dashboard definitions are copied into the image instead. Database credentials
# are NOT baked in — they arrive as task-definition environment variables, the
# same way the backend gets its secrets (see docs/DEPLOYMENT.md).
FROM grafana/grafana:11.6.0

COPY provisioning /etc/grafana/provisioning
COPY dashboards /var/lib/grafana/dashboards

# Served behind the shared ALB at /grafana, so Grafana has to know its own
# public root or every asset and redirect it emits points at the wrong path.
ENV GF_SERVER_ROOT_URL=http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com/grafana \
    GF_SERVER_SERVE_FROM_SUB_PATH=true \
    GF_AUTH_ANONYMOUS_ENABLED=true \
    GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
    GF_AUTH_DISABLE_LOGIN_FORM=true \
    GF_USERS_DEFAULT_THEME=dark \
    GF_DASHBOARDS_MIN_REFRESH_INTERVAL=2s \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false
