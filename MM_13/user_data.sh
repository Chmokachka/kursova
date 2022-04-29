#!/bin/bash
apt update -y
apt upgrade -y
apt install git -y
apt install python3-pip -y
apt install python3-venv -y
git clone https://github.com/Chmokachka/kursova.git
chmod +x kursova/MM_13/start
sudo mv kursova/MM_13/page.service /usr/lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start page.service
