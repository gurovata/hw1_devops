terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# Отдельная новая сеть для nginx
resource "docker_network" "nginx" {
  name = "hw1_terraform_network"
}

# Том для файлов сайта
resource "docker_volume" "nginx" {
  name = "hw1_nginx_data"
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name    = "hw1_terraform_nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.nginx.name
  }

  ports {
    internal = 80
    external = var.nginx_port
  }

  volumes {
    volume_name    = docker_volume.nginx.name
    container_path = "/usr/share/nginx/html"
  }
}
