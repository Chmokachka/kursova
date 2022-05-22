#!/bin/bash
sudo apt update -y
sudo apt upgrade -y
sudo apt install python3-pip -y
sudo apt install python3-venv -y
git clone https://github.com/Chmokachka/kursova.git
chmod +x kursova/MM_13/start
sudo mv kursova/MM_13/page.service /usr/lib/systemd/system/
sudo mv kursova /home/ubuntu
sudo systemctl daemon-reload
sudo systemctl start page.service
