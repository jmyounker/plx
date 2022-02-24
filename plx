#!/bin/bash -e

DEFAULT_SUBCMD=default

plx_main() {
  case $( run_mode "$0" ) in
    "plx")
      plx_mode "$@"
      ;;
    "plx-sh")
      # shellcheck disable=SC1090
      source "$1"
      echo "the plx $0 should call plx_run as it's last option or exit" >&2
      exit 126
      ;;
    "plx-ln")
      plx_run "$0" "$@"
      ;;
    "plx-test")
      # Test mode does nothing, just exits
      ;;
    *)
      echo "unknown mode RUN_MODE" >&2
      exit 126
      ;;
  esac
}

run_mode() {
  if [ $(basename "$1") == "plx-sh" ]; then
    echo -n "plx-sh"
  elif [ $(basename "$1") == "plx" ]; then
    echo -n "plx"
  elif [ $(basename "$1") == "bats-exec-file" ]; then
    echo -n "plx-test"
  elif [ $(basename "$1") == "bats-exec-test" ]; then
    echo -n "plx-test"
  else
    echo -n "plx-ln"
  fi
}

plx_mode() {
  case "$1" in
  "commands")
    plx_usage
    exit 0
    ;;
  "choices")
    # plx choices ROOT-COMMAND
    # outputs 'SUBCOMMAND " " PATH' pairs
    shift
    plx_choices "$@"
    exit $?
    ;;
  "run")
    # plx run ROOT-COMMAND ...
    # runs ROOT-COMMAND-$1 $[2:] or ROOT-COMMAND $@
    shift
    plx_run "$@"
    ;;
  "exists")
    # plx exists ROOT-COMMAND
    # return code 0 if ROOT-COMMAND exists or 1 if it does not
    shift
    plx_exists "$@"
    exit $?
    ;;
  "sh")
    # plx sh SHELL_SOURCE ...
    # sources SHELL_SOURCE with current argv
    shift
    vertex_shell_mode "$@"
    exit $?
    ;;
  "ln")
    # plx link ROOT_COMMAND ...
    # runs as if ROOT_COMMAND was executed with arguments ...
    shift
    plx_run "$@"
    exit $?
    ;;
  "test")
    # plx test
    # does nothing
    exit 0
    ;;
  *)
    plx_usage >&2
    exit 127
    ;;
  esac
}

plx_usage() {
    cat <<EO_HELP >&2
usage: $0 SUBCOMMAND [OPTIONS]

commands:
 commands - list commands (this!)
 choices ROOT_COMMAND - list subcommand - path pairs one per line
 run ROOT_COMMAND ... - run the command specified by ROOT_COMMAND ...
 exists ROOT_COMMAND - exit with 0 if ROOT_COMMAND exists and 1 otherwise
 sh ROOT_COMMAND ... - execute ROOT_COMMAND by including it with and passing ... as args
 ln ROOT_COMMAND ... - execute as if ROOT_COMMAND had been called with arguments ...
 test - does nothing
EO_HELP
}

plx_run() {
  [ $# -lt 1 ] && die 2 'error: programmer f*cked up'
  self=${1}
  root_command=$(basename ${self})
  shift

  td=$(mktemp -d)
  [ -n "$n" ] && die "error: could not create temp directory"
  # shellcheck disable=SC2064
  trap "rm -rf '$td'" EXIT

  subcommands_available="$td/subcommands.json"
  cache_subcommands "$root_command" "$PATH" "$subcommands_available"

  if [ $# -eq 0 ] && has_default "$subcommands_available"; then
    debug "No arguments: run_default"
    run_default "$subcommands_available"
  elif option_starts_with_dash "$1" && has_default "$subcommands_available"; then
    debug "First argument is option: run_default"
    run_default "$subcommands_available" "$@"
  elif has_subcommand "$subcommands_available" "$1"; then
    debug "First option exists as subcommand: run_subcommand"
    run_subcommand "$subcommands_available" "$@"
  elif [ "$1" == "help" ]; then
    debug "First option is help: run_help"
    run_help "$self" "$root_command" "$subcommands_available" "$@"
    exit 0
  elif [ "$1" == "commands" ]; then
    debug "First option is subcommands: list_commands"
    list_commands "$self" "$root_command" "$subcommands_available"
    exit 0
  elif has_default "$subcommands_available"; then
    debug "Unknown command but we have a default: run_default"
    run_default "$subcommands_available" "$@"
  else
    debug "No other actions left: list_commands"
    # TODO(jmyounker): print "unknown subcommand" error message
    list_commands "$self" "$root_command" "$subcommands_available"
    exit 127
  fi
}

die() {
  exit_code=1
  if [ $# == 2 ]; then
    exit_code=$1
    shift
  fi
  echo $1 >&2
  exit $exit_code
}

debug() {
  if [ -n "$PLX_TRACE" ]; then
    echo $1 >& 2
  fi
}

plx_cmd_help() {
  cat <<EOHELP
usage: $0 COMMAND *

COMMANDS:
  subcommands COMMAND_BASE -- subcommands of command base as JSON
  subcommand-selected COMMAND_BASE [ARGUMENT] * -- the selected subcommand as JSON
  subcommand-run COMMAND_BASE [ARGUMENT] * -- run the selected command
  subcommand-summary COMMAND_PATH -- prints the command's summary string
  subcommand-details COMMAND_PATH -- prints the command's detailed help

EOHELP
}

plx_choices() {
  root_command="$1"
  [ -z "$root_command" ] && die 127 "root command required"
  td="$(mktemp -d)"
  trap "rm -rf '$td'" RETURN
  cache_file="$td/cache.txt"
  cache_subcommands "$root_command" "$PATH" "$cache_file"
  cat "$cache_file"
}


plx_exists() {
  root_command="$1"
  [ -z "$root_command" ] && die 127 "root command required"
  type -f "$root_command" >/dev/null 2>&1
}

# Search the path for matching subcommands. Record them in a file.
cache_subcommands() {
  local root_command search_path output_file
  root_command="$1"
  search_path="$2"
  output_file="$3"
  _select_first <(_subcommands "$root_command" "$search_path") > "$output_file"
}

_subcommands() {
  local root_command output_file p
  root_command="$1"
  search_path="$2"
  printf '%s:\0' "$search_path" | while IFS=: read -d: -r p; do
      _record_hyphen_subcommands ${root_command} ${p}
  done
}

_record_hyphen_subcommands() {
  local root_command directory output_file p
  root_command="$1"
  directory="$2"
  [ ! -d ${directory} ] && return
  prog=$(cat << 'EO_LIST_SUBCOMMANDS_AND_PATHS'
{
  root_part=substr($0, 1, length(root_command));
  if ( root_part != root_command ) {
    next;
  }
  sep=substr($0, length(root_command) + 1, 1);
  if ( sep != "-" ) {
    next;
  }
  rest=substr($0, length(root_command) + 2);
  split(rest, rest_parts, "-");
  if ( rest_parts[1] == "" || rest_parts[2] != "" ) {
    next;
  }
  print rest_parts[1] " " directory "/" $0;
}
EO_LIST_SUBCOMMANDS_AND_PATHS
)
  ls ${directory} | awk -v "root_command=$root_command" -v "directory=$directory" -f <(echo $prog)
}


_select_first() {
  local src prog
  src="$1"
  prog=$(cat << 'EO_SELECT_FIRST_PROG'
{
  first_space_at=index($0, " ");
  if ( first_space_at == 0 ) {
    next;
  }
  sc=substr($0, 0, first_space_at-1);
  if ( sc in seen ) {
    next;
  }
  seen[sc] = 1;
  print $0
}
EO_SELECT_FIRST_PROG
)
  cat "$src" | awk -f <(echo $prog)
}


_available_subcommands() {
  local cache_file
  cache_file="$1"
  shift
  awk_subcommands=$(cat << 'EO_AWK_SUBCOMMANDS'
{
  first_space_at=index($0, " ");
  if ( first_space_at == 0 ) {
    next;
  }
  sc=substr($0, 0, first_space_at-1);
  sc_path=substr($0, first_space_at + 1);
  if ( sc in paths_by_subcommand ) {
    next;
  }
  paths_by_subcommand[sc] = sc_path
}
END {
  for ( sc in paths_by_subcommand ) {
    print sc " " paths_by_subcommand[sc]
  }
}
EO_AWK_SUBCOMMANDS
)
  cat ${cache_file} | awk -f <(echo $awk_subcommands)
}

has_default() {
  local cache_file
  cache_file=${1}
  shift
  if has_subcommand ${cache_file} ${DEFAULT_SUBCMD}; then
    return 0
  elif [[ "$(type -t plx_default_func)" == 'function' ]]; then
    return 0
  else
    return 1
  fi
}

option_starts_with_dash() {
  local option
  option=${1}
  echo $option | head -1 | grep -q -E '^-'
}

run_default() {
  local cache_file
  cache_file=${1}
  shift
  if has_subcommand ${cache_file} ${DEFAULT_SUBCMD}; then
    subcommand_path=$(first_match_path ${cache_file} ${DEFAULT_SUBCMD})
    exec ${subcommand_path} "$@"
  elif [[ "$(type -t plx_default_func)" == 'function' ]]; then
    plx_default_func
    exit $?
  else
    return 1
  fi
}

has_subcommand() {
  subcommand_path=$(first_match_path "$@")
  [ -n "$subcommand_path" ]
}

first_match_path() {
  local cache_file subcommand awk_subcommands
  cache_file=${1}
  subcommand=${2}
  awk_subcommands=$(cat << 'EO_AWK_SUBCOMMANDS'
{
  first_space_at=index($0, " ");
  if ( first_space_at == 0 ) {
    next;
  }
  sc=substr($0, 0, first_space_at-1);
  sc_path=substr($0, first_space_at + 1);
  if ( sc == subcommand ) {
    print sc_path;
  }
}
EO_AWK_SUBCOMMANDS
)
  cat ${cache_file} | awk -v "subcommand=${subcommand}" -f <(echo $awk_subcommands)
}

run_subcommand() {
  local cache_file
  cache_file=${1}
  shift
  subcommand_path=$(first_match_path ${cache_file} ${1})
  shift
  exec ${subcommand_path} "$@"
}

run_help() {
  local self root_command cache_file short_name
  self=${1}
  root_command=${2}
  cache_file=${3}
  short_name=$(echo $(basename $self) | tr - " ")
  if [ "$(type -t plx_list_commands)" == "function" ]; then
    plx_list_commands
    exit $?
  fi
  if [ -n "$summary" ]; then
    echo "${short_name}: $summary"
  else
    echo "${short_name}"
  fi

  echo ""

  if [ -n "$details" ]; then
    echo "$details"
    echo ""
  fi

  echo "commands:"
  cat "$cache_file" | awk '{print $1}' | awk '!/default/{ print "  " $1}'
}

list_commands() {
  local self root_command cache_file
  self=${1}
  root_command=${2}
  cache_file=${3}
  short_name=$(echo $(basename "$self") | tr - " ")
  echo "commands:"
  cat "$cache_file" | awk '{print $1}' | awk '!/default/{ print "  " $1}'
}

plx_main "$@"
