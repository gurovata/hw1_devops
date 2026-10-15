variable "docker_host" {
  description = "Адрес Docker Engine"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "nginx_port" {
  description = "Нестандартный порт nginx на хосте"
  type        = number
  default     = 8081
}
