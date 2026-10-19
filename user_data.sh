#!/bin/bash
# Se ejecuta UNA vez, como root, en el primer arranque de la VM.
# Log completo en: /var/log/user-data.log
set -euxo pipefail
exec > /var/log/user-data.log 2>&1

# 1) Swap de 4 GB: las instancias gratuitas tienen ~1 GB de RAM y el build
#    del frontend de Frappe se queda sin memoria sin esto.
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 2) Docker + plugin de compose
apt-get update -y
apt-get install -y ca-certificates curl
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable --now docker

# 3) Frappe CRM
mkdir -p /opt/frappe-crm
cd /opt/frappe-crm

# init.sh del repo oficial (crea el bench, el sitio e instala el CRM)
curl -fsSL -o init.sh https://raw.githubusercontent.com/frappe/crm/develop/docker/init.sh
chmod +x init.sh

# FIX SSL: la imagen frappe/bench:latest trae un cliente de MariaDB reciente que
# exige SSL, pero mariadb:10.8 no lo ofrece, y "bench new-site" falla con
# "SSL is required, but the server does not support it". Se desactiva SSL solo en
# el cliente; la conexion es interna entre contenedores de la misma maquina.
printf '[client]\nskip-ssl\n' > client.cnf

# docker-compose.yml: igual al del repo oficial, mas el montaje de client.cnf
cat > docker-compose.yml <<'EOF'
name: crm
services:
  mariadb:
    image: mariadb:10.8
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
      - --skip-innodb-read-only-compressed
    environment:
      MYSQL_ROOT_PASSWORD: 123
    volumes:
      - mariadb-data:/var/lib/mysql

  redis:
    image: redis:alpine

  frappe:
    image: frappe/bench:latest
    command: bash /workspace/init.sh
    environment:
      - SHELL=/bin/bash
    working_dir: /home/frappe
    volumes:
      - .:/workspace
      - ./client.cnf:/home/frappe/.my.cnf:ro
    ports:
      - 8000:8000
      - 9000:9000

volumes:
  mariadb-data:
EOF

docker compose up -d

# 4) Esperar a que el CRM responda de verdad (hasta ~45 min) y dejarlo en el log.
#    Un 500 significa que el sitio no se instalo bien, asi que no cuenta como listo.
for i in $(seq 1 270); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/crm || true)
  echo "intento $i: HTTP $code"
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    echo "CRM LISTO en http://<IP-PUBLICA>:8000/crm"
    exit 0
  fi
  sleep 10
done

echo "El CRM no respondio correctamente tras 45 min. Revisa: cd /opt/frappe-crm && docker compose logs"
exit 1