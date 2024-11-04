#!/bin/bash

# >>> TUI >>>
logit() {
  case "$1" in
  error) echo -e "\033[91;1m✘ $2\033[0m" >&2 ;;
  success) echo -e "\033[92;1m✔ $2\033[0m" >&2 ;;
  info) echo -e "\033[94;1mℹ $2\033[0m" >&2 ;;
  esac
}

confirm() {
  echo -en "\033[1m\033[33m$1\033[0m" >&2

  local result=""

  while true; do
    stty -echo
    read -r -n1 result
    stty echo

    case "$result" in
    y | Y)
      echo -n 1
      break
      ;;
    n | N)
      echo -n 0
      break
      ;;
    *) ;;
    esac
  done

  echo "" >&2
}

list() {
  echo -en "\033[1m${1}\033[0m " >&2
  local opts=("${@:2}")
  local opts_count=${#opts[@]}
  for ((i = 0; i < opts_count; i++)); do echo "" >&2; done
  local lastrow=$(_get_cursor_row)
  local startrow=$((lastrow - opts_count + 1))
  trap "_cursor_blink_on; stty echo; exit" INT
  _cursor_blink_off
  local selected=0

  while true; do
    for ((idx = 0; idx < opts_count; idx++)); do
      _cursor_to $((startrow + idx))
      if ((idx == selected)); then
        printf "\033[36m❯ %s\033[0m" "${opts[idx]}" >&2
      else
        printf "  %s" "${opts[idx]}" >&2
      fi
    done

    case $(_key_input) in
    enter) break ;;
    up) selected=$(_decrement_selected "$selected" "$opts_count") ;;
    down) selected=$(_increment_selected "$selected" "$opts_count") ;;
    esac
  done

  echo -en "\n" >&2
  _cursor_to "$lastrow"
  _cursor_blink_on
  echo "$selected"
}
# <<< TUI <<<
# >>> UTILS >>>
_read_stdin() {
  read $@ </dev/tty
}

_get_cursor_row() {
  local IFS=';'
  _read_stdin -sdR -p $'\E[6n' ROW COL
  echo "${ROW#*[}"
}
_cursor_blink_on() { echo -en "\033[?25h" >&2; }
_cursor_blink_off() { echo -en "\033[?25l" >&2; }
_cursor_to() { echo -en "\033[$1;$2H" >&2; }

_key_input() {
  local ESC=$'\033'
  local IFS=''

  _read_stdin -rsn1 a
  if [[ "$ESC" == "$a" ]]; then
    _read_stdin -rsn2 b
  fi

  local input="${a}${b}"
  case "$input" in
  "$ESC[A" | "k") echo up ;;
  "$ESC[B" | "j") echo down ;;
  "$ESC[C" | "l") echo right ;;
  "$ESC[D" | "h") echo left ;;
  '') echo enter ;;
  ' ') echo space ;;
  esac
}

_new_line_foreach_item() {
  for ((i = 0; i < $1; i++)); do
    echo "" >&2
  done
}

_prompt_text() {
  echo -en "\033[32m?\033[0m\033[1m ${1}\033[0m " >&2
}

_decrement_selected() {
  local selected=$1
  ((selected--))
  if [ "${selected}" -lt 0 ]; then
    selected=$(($2 - 1))
  fi
  echo -n $selected
}

_increment_selected() {
  local selected=$1
  ((selected++))
  if [ "${selected}" -ge "${opts_count}" ]; then
    selected=0
  fi
  echo -n $selected
}
# <<< UTILS <<<
# >>> Main >>>
if ! command -v nmcli &>/dev/null; then
  logit "error" "'nmcli' is not installed. Please install it before running this script."
  exit 1
fi

if nmcli c show --active | grep -q vpn; then
  kill_connection=$(confirm "You are already connected to a VPN. Kill VPN connection? (y/N)")

  if [[ "$kill_connection" -eq 0 ]]; then
    exit 0
  fi

  connection=$(nmcli c show --active | grep vpn | awk '{print $1}')
  if ! nmcli c down "$connection" &>/dev/null; then
    logit "error" "Failed to disconnect from the VPN."
    exit 1
  else
    logit "info" "Disconnected VPN successfully."
  fi
fi

mapfile -t connections < <(nmcli c show | grep vpn | awk '{print $1}')

option=$(list "Select a VPN connection to connect to:" "${connections[@]}")

if ! nmcli c up ${connections[option]} &>/dev/null; then
  logit "error" "Failed to connect to the VPN."
  exit 1
else
  logit "success" "Connected to the VPN successfully."
  exit 0
fi
# <<< MAIN <<<
