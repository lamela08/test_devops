# syntax=docker/dockerfile:1
FROM docker.io/library/nginx:latest
ARG root_dir=/html

RUN --mount=type=bind,source=ssl,dst=/tmp/ssl_mount <<-EOF
	#Create necessary files
	mkdir -p -m 755 ${root_dir}
	cp /tmp/ssl_mount/cert.pem /etc/ssl/certs/
	cp /tmp/ssl_mount/key.pem /etc/ssl/private/
	chmod 644 /etc/ssl/certs/cert.pem /etc/ssl/private/key.pem
	
	#Create Nginx config
	cat > /etc/nginx/conf.d/default.conf <<-EOF2
		server {
    		listen 0.0.0.0:80;
    		server_name _;

    		return 301 https://\$host\$request_uri;

		}
		server {
    		listen 0.0.0.0:443 default_server ssl;
    		root ${root_dir};
    		index index.html;
    		server_name _;

    		ssl_certificate /etc/ssl/certs/cert.pem;
    		ssl_certificate_key /etc/ssl/private/key.pem;
    		ssl_protocols TLSv1.2 TLSv1.3;
    		ssl_session_timeout 5m;

    		access_log /var/log/nginx/access.log;
    		error_log /var/log/nginx/error.log info;

		}
	EOF2
EOF

EXPOSE 80/tcp
EXPOSE 443/tcp
