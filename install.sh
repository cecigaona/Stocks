#!/bin/bash
set -e

echo "Verificando dependencias..."

if ! command -v docker &> /dev/null; then
  echo "Docker no esta instalado."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
      echo "Instalando Docker Desktop con Homebrew..."
      brew install --cask docker
      echo "Abre Docker Desktop manualmente y vuelve a ejecutar este script."
      exit 1
    else
      echo "Instala Homebrew (https://brew.sh) o Docker Desktop manualmente y vuelve a intentar."
      exit 1
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Instalando Docker con el script oficial..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh
    sudo usermod -aG docker "$USER"
    echo "Cierra sesion y vuelve a iniciarla para usar Docker sin sudo, luego ejecuta este script de nuevo."
    exit 1
  else
    echo "Sistema operativo no soportado automaticamente. Instala Docker manualmente."
    exit 1
  fi
else
  echo "Docker encontrado."
fi

if ! docker compose version &> /dev/null; then
  echo "Docker Compose no esta disponible como plugin de Docker."
  echo "Actualiza Docker Desktop o instala el plugin docker-compose-plugin."
  exit 1
else
  echo "Docker Compose encontrado."
fi

echo "Levantando el proyecto con Docker Compose..."
docker compose up --build -d

echo ""
echo "Proyecto levantado correctamente."
echo "Frontend disponible en:              http://localhost:3000"
echo "API a traves del load balancer en:   http://localhost:8080/api"
