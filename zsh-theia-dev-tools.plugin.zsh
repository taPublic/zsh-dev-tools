function _get_ide_port {
  local container
  local running

  container=$(_get_ide_container)
  running=$(_check_container_running "$container")

  if [ "$running" = "true" ]; then
    echo "$(docker inspect --format='{{(index (index .NetworkSettings.Ports "3000/tcp") 0).HostPort}}' "$container")"
  else
    echo "$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')"
  fi
}

function _get_ide_name {
  echo "${PWD##*/}"
}

function _get_ide_host {
  echo "localhost:$1"
}

function _get_ide_container_name {
  echo "$1-ide"
}

function _get_ide_container {
  local name

  name=$(_get_ide_name)
  
  echo $(_get_ide_container_name "$name")
}

function _check_container_running {
  echo $(docker inspect --format="{{.State.Running}}" "$1" 2> /dev/null)
}

function _check_container_started {
  content=$(curl -s http://localhost:$1/)

  if echo "$content" | grep -q "html"; then
    echo "true"
  else
    echo "false"
  fi
}

function _start_ide {
  local port
  local host
  local running
  local container

  port=$(_get_ide_port)
  host=$(_get_ide_host "$port")
  container=$(_get_ide_container)
  running=$(_check_container_running "$container")

  if [ "$running" != "true" ]; then
    docker run -d --rm \
      -v "$(pwd):/home/project:cached" \
      --name "$container" \
      -p "$port:3000" \
      theiaide/theia-full:next
  fi

  while [ "$(_check_container_started "$port")" != "true" ]
  do
    echo "."
    sleep 1
  done

  open "http://$host"
}

function _stop_ide {
  local container
  local running

  container=$(_get_ide_container)
  running=$(docker inspect --format="{{.State.Running}}" "$container" 2> /dev/null)

  if [ "$running" = "true" ]; then
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
