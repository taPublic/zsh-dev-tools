function _get_ide_name {
  echo "${PWD##*/}"
}

function _get_ide_host {
  echo "$1.ide.dev.torinasakura.name"
}

function _get_ide_container_name {
  echo "$1-ide"
}

function _create_metadata_volume {
  local name="c9metadata"
  local created

  created=$(docker volume inspect --format="{{.CreatedAt}}" $name 2> /dev/null)

  if [ -z "$created" ]; then
    echo "Creating c9 metadata volume"
    docker volume create $name
  fi
}

function _create_dev_network {
  local created
  
  created=$(docker network inspect --format="{{.Id}}" dev 2> /dev/null)

  if [ -z "$created" ]; then
    echo "Creating dev network"
    docker network create dev
  fi
}

function _start_traefik {
  local container="traefik"
  local running
  
  running=$(docker inspect --format="{{.State.Running}}" "$container" 2> /dev/null)

  if [ "$running" != "true" ]; then
    docker run -d --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v ~/workspace/torinasakura/traefik/traefik.toml:/traefik.toml \
      -v ~/workspace/torinasakura/traefik/certs:/certs \
      --name "$container" \
      --network dev \
      -p 80:80 -p 8080:8080 -p 443:443 \
      traefik:1.7-alpine \
      --web --docker --docker.domain=docker.localhost
  fi
}

function _stop_traefik {
  local container="traefik"

  running=$(docker inspect --format="{{.State.Running}}" "$container" 2> /dev/null)

  if [ "$running" == "true" ]; then
    docker stop "$container"
  fi
}

function _start_ide {
  _create_metadata_volume
  _create_dev_network
  _start_traefik

  local name
  local host
  local running
  local container

  name=$(_get_ide_name)
  host=$(_get_ide_host "$name")
  container=$(_get_ide_container_name "$name")
  running=$(docker inspect --format="{{.State.Running}}" "$container" 2> /dev/null)

  if [ "$running" != "true" ]; then
    docker run -d --rm \
      -v "$PWD":/workspace \
      -v c9metadata:/workspace/.c9 \
      --name "$container" \
      --network dev \
      --label "traefik.frontend.rule=Host:$host" \
      --label "traefik.port=80" \
      torinasakura/cloud9
  fi

  open "https://$host"
}

function _stop_ide {
  local name
  local host
  local container
  local running

  name=$(_get_ide_name)
  host=$(_get_ide_host "$name")
  container=$(_get_ide_container_name "$name")
  running=$(docker inspect --format="{{.State.Running}}" "$container" 2> /dev/null)

  if [ "$running" == "true" ]; then
    docker stop "$container"
  fi
}

function ide {
  local cmd=$1

  case "$cmd" in
    start)
        _start_ide
        ;;
    stop)
        _stop_ide
        ;;
    *)
        echo "Usage: ide {start|stop}"
        ;;
esac
}

function traefik {
  local cmd=$1

  case "$cmd" in
    start)
        _start_traefik
        ;;
    stop)
        _stop_traefik
        ;;
    *)
        echo "Usage: traefik {start|stop}"
        ;;
esac
}
