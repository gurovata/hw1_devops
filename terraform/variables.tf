variable "docker_host" {
  type    = string
  default = "unix:///var/run/docker.sock"
}

variable "nginx_port" {
  type    = number
  default = 8081

  validation {
    condition     = var.nginx_port >= 1024 && var.nginx_port <= 65535 && floor(var.nginx_port) == var.nginx_port
    error_message = "Выберите целый номер порта от 1024 до 65535."
  }
}
