

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run as root (use sudo).${NC}"
  exit 1
fi

add_users() {
  file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}Error: File '$file' not found.${NC}"
    exit 1
  fi

  echo -e "${BLUE}Adding users from file: $file${NC}"
  while IFS= read -r username; do
    [ -z "$username" ] && continue
    if id "$username" &>/dev/null; then
      echo -e "${YELLOW}User '$username' already exists.${NC}"
    else
      useradd -m "$username"
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}User '$username' created successfully.${NC}"
      else
        echo -e "${RED}Failed to create user '$username'.${NC}"
      fi
    fi
  done < "$file"
}

setup_projects() {
  username="$1"
  num="$2"

  if [ -z "$username" ] || [ -z "$num" ]; then
    echo -e "${RED}Usage: ./sys_manager.sh setup_projects <username> <num_projects>${NC}"
    exit 1
  fi

  if ! id "$username" &>/dev/null; then
    echo -e "${RED}User '$username' does not exist.${NC}"
    exit 1
  fi

  base_dir="/home/$username/projects"
  mkdir -p "$base_dir"

  for ((i=1; i<=num; i++)); do
    proj="$base_dir/project$i"
    mkdir -p "$proj"
    echo "Project $i created on $(date) by $username" > "$proj/README.txt"
    chown -R "$username":"$username" "$proj"
    chmod 755 "$proj"
    chmod 640 "$proj/README.txt"
  done

  echo -e "${GREEN}$num project folders created successfully under $base_dir.${NC}"
}

sys_report() {
  output="$1"
  if [ -z "$output" ]; then
    echo -e "${RED}Usage: ./sys_manager.sh sys_report <output_file>${NC}"
    exit 1
  fi

  {
    echo "===== SYSTEM REPORT ====="
    echo "Disk Usage:"
    df -h
    echo
    echo "Memory Info:"
    free -h
    echo
    echo "CPU Info:"
    lscpu | head -n 10
    echo
    echo "Top 5 Memory-Consuming Processes:"
    ps -eo pid,comm,%mem --sort=-%mem | head -6
    echo
    echo "Top 5 CPU-Consuming Processes:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -6
  } > "$output"

  echo -e "${GREEN}System report saved to '$output'.${NC}"
}

process_manage() {
  username="$1"
  action="$2"

  if [ -z "$username" ] || [ -z "$action" ]; then
    echo -e "${RED}Usage: ./sys_manager.sh process_manage <username> <action>${NC}"
    exit 1
  fi

  case $action in
    list_zombies)
      echo -e "${BLUE}Listing zombie processes for user '$username':${NC}"
      ps -u "$username" -o pid,stat,comm | awk '$2 ~ /Z/ {print}'
      ;;
    list_stopped)
      echo -e "${BLUE}Listing stopped processes for user '$username':${NC}"
      ps -u "$username" -o pid,stat,comm | awk '$2 ~ /T/ {print}'
      ;;
    kill_zombies)
      echo -e "${YELLOW}Warning: Zombie processes cannot be killed directly.${NC}"
      ;;
    kill_stopped)
      echo -e "${BLUE}Killing stopped processes for user '$username'...${NC}"
      pids=$(ps -u "$username" -o pid,stat | awk '$2 ~ /T/ {print $1}')
      if [ -z "$pids" ]; then
        echo -e "${YELLOW}No stopped processes found.${NC}"
      else
        kill -9 $pids
        echo -e "${GREEN}Stopped processes terminated.${NC}"
      fi
      ;;
    *)
      echo -e "${RED}Invalid action. Use list_zombies, list_stopped, kill_zombies, or kill_stopped.${NC}"
      exit 1
      ;;
  esac
}

perm_owner() {
  username="$1"
  path="$2"
  perms="$3"
  owner="$4"
  group="$5"

  if [ $# -ne 5 ]; then
    echo -e "${RED}Usage: ./sys_manager.sh perm_owner <username> <path> <permissions> <owner> <group>${NC}"
    exit 1
  fi

  if [ ! -e "$path" ]; then
    echo -e "${RED}Error: Path '$path' does not exist.${NC}"
    exit 1
  fi

  chmod -R "$perms" "$path"
  chown -R "$owner":"$group" "$path"

  echo -e "${GREEN}Permissions and ownership updated for $path${NC}"
  ls -ld "$path"
}

help_menu() {
  echo -e "${YELLOW}========== SYS MANAGER HELP MENU ==========${NC}"
  echo -e "${GREEN}Usage:${NC} ./sys_manager.sh <mode> [arguments]"
  echo -e "\n${BLUE}Modes Available:${NC}"
  echo "  add_users <file>                    - Add multiple users from a file"
  echo "  setup_projects <user> <n>           - Create project folders"
  echo "  sys_report <output_file>            - Generate system report"
  echo "  process_manage <user> <action>      - Manage processes (list_zombies, kill_stopped)"
  echo "  perm_owner <user> <path> <perm> <owner> <group> - Change permissions & ownership"
  echo "  help                                - Show this menu"
  echo -e "\n${BLUE}Examples:${NC}"
  echo "./sys_manager.sh add_users users.txt"
  echo "./sys_manager.sh setup_projects alice 5"
  echo "./sys_manager.sh sys_report sysinfo.txt"
  echo "./sys_manager.sh process_manage bob list_zombies"
  echo "./sys_manager.sh perm_owner alice /home/alice/projects 755 alice alice"
  exit 0
}

mode="$1"
shift || true

case $mode in
  add_users) add_users "$@" ;;
  setup_projects) setup_projects "$@" ;;
  sys_report) sys_report "$@" ;;
  process_manage) process_manage "$@" ;;
  perm_owner) perm_owner "$@" ;;
  help|--help|-h|"") help_menu ;;
  *)
    echo -e "${RED}Invalid mode. Use ./sys_manager.sh help for usage.${NC}"
    exit 1
    ;;
esac

exit 0
