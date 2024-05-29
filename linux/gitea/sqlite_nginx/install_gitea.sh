#!/usr/bin/sh
sudo apt update
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
sudo apt install -y git sqlite3 wget

# Create Gitea user
sudo adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   git

# Download and Install Gitea
GITEA_VERS="1.22"
GITEA_ARCH="$(dpkg --print-architecture)"
sudo wget -O /tmp/gitea https://dl.gitea.io/gitea/${GITEA_VERS}/gitea-${GITEA_VERS}-linux-${GITEA_ARCH}
sudo mv /tmp/gitea /usr/local/bin
sudo chmod +x /usr/local/bin/gitea

# Create Gitea Directory Structure
sudo mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}

sudo chown -R git:git /var/lib/gitea/
sudo chown -R git:git /var/lib/gitea/
sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea

sudo wget https://raw.githubusercontent.com/go-gitea/gitea/main/contrib/systemd/gitea.service \
  -P /etc/systemd/system/

sudo vi /etc/systemd/system/gitea.service

sudo systemctl daemon-reload
sudo systemctl enable --now gitea

sudo systemctl status gitea
sudo ufw allow 3000/tcp

