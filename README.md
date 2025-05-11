# 1
cd ./1

ansible-galaxy install -v -r roles/requirements.yml -p roles/

ansible-playbook [options] play.yaml

# 2
cd ./2

docker build -t custom_nginx:latest .

docker compose up -d
