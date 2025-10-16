# Deploy Mattermost in Docker on Ubuntu

## Download and run the script
```bash
curl -O https://raw.githubusercontent.com/roberson-io/mattermost-ubuntu-docker/main/install-mattermost.sh
chmod +x install-mattermost.sh
./install-mattermost.sh
```

This will clone the Mattermost Docker repo into a directory named `mattermost-docker` rather than `docker`.

It will remove any unofficial or unsupported Docker packages then install Docker Engine and Docker Compose according to the [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) documentation.

You will receive a few prompts after Docker is installed:

`Add current user ([your-username]) to docker group to run without sudo? (y/n):`

If you select `y`, you will have to start a new terminal session to run `docker compose` commands without `sudo`.

`Enter your domain name (e.g., mattermost.example.com):`

Enter the IP address for your VM or your domain when you have DNS set up.

Choose from
```
Deployment options:
1. Without NGINX (access via http://<domain>:8065)
2. With NGINX (access via https://<domain>)
```

Do "without NGINX" until you're ready to set up TLS.

Go to http://[your-ip-address]:8065.