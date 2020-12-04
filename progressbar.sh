#!/usr/bin/env bash
### Created by Peter Forret ( pforret ) on 2020-12-01
script_version="0.0.0"  # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_creation="2020-12-01"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

list_options() {
echo -n "
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation (always yes)
option|l|log_dir|folder for log files |log
option|t|tmp_dir|folder for temp files|/tmp/$script_prefix
#option|i|infile|file with source data (to calculate MB/s)|
#option|o|outfile|file with generated data (to calculate MB/s)|
option|b|bar|format of bar: normal/half/long/short|normal
option|c|char|character to use a filler|#
param|1|action|lines/seconds/clear/check
param|1|input|input number or operation identifier
" | grep -v '^#'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
    log "Program: $script_basename $script_version"
    log "Created: $script_creation"
    log "Updated: $prog_modified"
    log "Run as : $USER@$HOSTNAME"
    # add programs that need to be installed, like: tar, wget, ffmpeg, rsync, convert, curl ...
    require_binaries tput uname gawk

    if [[ ${piped:-0} -gt 0 ]] ; then
      eol="\n"
    else
      eol="\r"
    fi
    action=$(lower_case "$action")
     # shellcheck disable=SC2154
     if is_number "$input" ; then
      # $1 is # lines/seconds expected
      cache_file=""
    else
      # $1 is process identifier
      # shellcheck disable=SC2154
      cache_file="$tmp_dir/$(echo "$input" | hash 12).result.txt"
      log "Cache file = [$cache_file]"
    fi
   case $action in
    lines )
#TIP: use «progressbar lines <nb_lines>» to show the progress bar when you can estimate the number of lines that will be sent to stdin
#TIP:> progressbar lines 14550
#TIP: use «progressbar lines <process_identifier>» to show the progress bar based on the number of lines it generated before
#TIP:> progressbar lines export-of-all-dbs
        # shellcheck disable=SC2154
        progress_lines "$input"
        ;;

    seconds|time )
#TIP: use «progressbar seconds <nb_secs>» to show the progress bar when you can estimate the number of seconds it will typically take
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi
#TIP: use «progressbar seconds <process_identifier>» to show the progress bar based on the number of seconds it took before
#TIP:> progressbar seconds export-of-all-dbs
        progress_seconds "$input"
        ;;

    clear|erase )
#TIP: use «progressbar clear <process_identifier>» to clear the cached results of a process
#TIP:> progressbar clear export-of-all-dbs
     if is_number "$input" ; then
       alert "[$script_basename $action] only makes sense if [$input] is not a numeric parameter"
     else
       if [[ -f "$cache_file" ]] ; then
         log "clear cache file [$cache_file]"
         rm "$cache_file"
       fi
     fi
        ;;

    check|stats|show )
#TIP: use «progressbar check <process_identifier>» to show the cached results of a process
#TIP:> progressbar check export-of-all-dbs
     if is_number "$input" ; then
       alert "[$script_basename $action] only makes sense if [$input] is not a numeric parameter"
     else
       if [[ -f "$cache_file" ]] ; then
         out "The last time [$input] was measured the following stats were collected:"
         cat "$cache_file"
       else
         alert "No data cached for [$input]"
       fi
     fi
        ;;

    *)
        die "action [$action] not recognized"
    esac
}

#####################################################################
## Put your helper scripts here
#####################################################################

bar_format(){
  # shellcheck disable=SC2154
  case $bar in
  none)   echo "" ;;
  10|short)   echo "----------" ;;
  20|medium)   echo "--------------------" ;;
  50|half)    echo "0----1----2----3----4----5----6----7----8----9----!" ;;
  60|spaces)  echo "                                                            " ;;
  100|normal) echo "0---------1---------2---------3---------4---------5---------6---------7---------8---------9---------" ;;
  200|double) echo "0-------------------1-------------------2-------------------3-------------------4-------------------5-------------------6------------------7-------------------8-------------------9-------------------!" ;;
  *) echo "0----1----2----3----4----5----6----7----8----9----!"
  esac
}

progress_lines(){
  if is_number "$1" ; then
    # $1 is # lines input expected
    print_bar_lines "$1"
  else
    # $1 is process identifier
    # shellcheck disable=SC2154
    cache_file="$tmp_dir/$(echo "$1" | hash 12).result.txt"
    log "Cached: $cache_file"
    if [[ ! -f "$cache_file" ]] ; then
      # first time this runs, no idea about # lines
      showbar_unknown "$cache_file"
    else
      # take # lines of previous time
      lines=$(grep 'lines:' "$cache_file" | cut -d: -f2)
      log "Found in cache: $lines lines"
      [[ -z "$lines" ]] && lines=100
      print_bar_lines "$lines" "$cache_file"
    fi
  fi
}

progress_seconds(){
  if is_number "$1" ; then
    # $1 is # lines input expected
    print_bar_seconds "$1"
  else
    # $1 is process identifier
    cache_file="$tmp_dir/$(echo "$1" | hash 12).result.txt"
    log "Cached: $cache_file"
    if [[ ! -f "$cache_file" ]] ; then
      # first time this runs, no idea about # seconds
      showbar_unknown "$cache_file"
    else
      # take # seconds of previous time
      lines=$(grep 'seconds:' "$cache_file" | cut -d: -f2)
      log "Found in cache: $lines seconds"
      [[ -z "$lines" ]] && lines=100
      print_bar_seconds "$lines" "$cache_file"
    fi
  fi
}

print_bar(){
  lines="$1"
  cache=${2:-}
  update_every=${3:-1}
    # shellcheck disable=SC2154
  gawk \
    -v full100="$(bar_format)" \
    -v cache="$cache" \
    -v expected_lines="$lines" \
    -v eol="$eol" \
    -v char="$char" \
    -v quiet="$quiet" \
    -v update_every="$update_every" '
  function repeat(char,count) {
        var =""
        while (count-->0) var = var char;
        return var;
  }
  BEGIN {
    len100=length(full100);
    fin100=substr(repeat(char,len100),1,len100);
    started_at=systime();
    if(quiet < 1) printf("[%s] %d%% / %d secs … %s" , full100 , 0, 0, eol);
  }
  (NR % update_every) == 0 {
    percent=100*NR/expected_lines;
    width=int(len100*NR/expected_lines);
    if(width>len100){width=len100};
    if(width<1){width=1};
    keep=len100-width;
    seconds=systime()-started_at;
    partial=substr(fin100,1,width) substr(full100,width+1,keep) ;
    if(quiet < 1) printf("[%s] %d%% / %d secs … %s" , partial , percent, seconds, eol);
    fflush();
  }
  END {
    if(quiet < 1) printf("\n");
    seconds=systime()-started_at;
    if(length(cache)>3){
      print "lines:" , NR > cache
      print "seconds:" , seconds >> cache
    }
  }
  '
}

print_bar_lines(){
  lines="$1"
  cache=${2:-}
  update_every=$(( lines / 250))
  [[ $update_every -lt 1 ]] && update_every=1
  [[ $update_every -gt 1000 ]] && update_every=1000
  log "showbar lines: expect $lines line(s)"
  log "showbar lines: update every $update_every line(s)"
  print_bar "$lines" "$cache" "$update_every"
}

print_bar_seconds(){
  seconds="$1"
  cache=${2:-}
  log "showbar seconds: expect $seconds seconds"
  seq 1 "$seconds" \
  | gawk '{system("sleep 1"); print;}' \
  | print_bar "$seconds" "$cache" 1
}

showbar_unknown(){
  cache=${1:-}
  gawk \
    -v quiet="$quiet" \
    -v eol="$eol" \
    -v cache="$cache" '
  BEGIN {
    len100=length(full100);
    started_at=systime();
  }
  {
    seconds=systime()-started_at;
    if(quiet < 1) printf("%d lines / %d secs … %s" , NR, seconds,eol);
    fflush();
  }
  END {
    if(quiet < 1) printf("\n");
    if(length(cache)>3){
      print "lines:" , NR > cache
      print "seconds:" , systime()-started_at >> cache
    }
  }
  '
}
#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
# shellcheck disable=SC2120
hash(){
  length=${1:-6}
  # shellcheck disable=SC2230
  if [[ -n $(which md5sum) ]] ; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

prog_modified="??"
os_name=$(uname -s)
[[ "$os_name" = "Linux" ]]  && prog_modified=$(stat -c %y    "${BASH_SOURCE[0]}" 2>/dev/null | cut -c1-16) # generic linux
[[ "$os_name" = "Darwin" ]] && prog_modified=$(stat -f "%Sm" "${BASH_SOURCE[0]}" 2>/dev/null) # for MacOS

force=0
help=0

## ----------- TERMINAL OUTPUT STUFF

[[ -t 1 ]] && piped=0 || piped=1        # detect if out put is piped
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

[[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported


if [[ $piped -eq 0 ]] ; then
  col_reset="\033[0m" ; col_red="\033[1;31m" ; col_grn="\033[1;32m" ; col_ylw="\033[1;33m"
else
  col_reset="" ; col_red="" ; col_grn="" ; col_ylw=""
fi

if [[ $unicode -gt 0 ]] ; then
  char_succ="✔" ; char_fail="✖" ; char_alrt="➨" ; char_wait="…"
else
  char_succ="OK " ; char_fail="!! " ; char_alrt="?? " ; char_wait="..."
fi

readonly nbcols=$(tput cols 2>/dev/null || echo 80)
readonly wprogress=$((nbcols - 5))

out() { ((quiet)) || printf '%b\n' "$*";  }

progress() {
  ((quiet)) || (
    if is_set ${piped:-0} ; then
      out "$*"
    else
      printf "... %-${wprogress}b\r" "$*                                             ";
    fi
  )
}

die()     { tput bel 2>/dev/null ; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }
fail()    { tput bel 2>/dev/null ; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }
alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }                       # print error and continue
success() { out "${col_grn}${char_succ}${col_reset}  $*" ; }
announce(){ out "${col_grn}${char_wait}${col_reset}  $*"; sleep 1 ; }
log()   { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2 ; }
lower_case()   { echo "$*" | awk '{print tolower($0)}' ; }
upper_case()   { echo "$*" | awk '{print toupper($0)}' ; }
confirm() { is_set $force && return 0; read -r -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}
ask() {
  # $1 = variable name
  # $2 = question
  # $3 = default value
  # not using read -i because that doesn't work on MacOS
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]] ; then
    eval "$1=\"$3\""
  else
    eval "$1=\"$ANSWER\""
  fi
}

error_prefix="${col_red}>${col_reset}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  log "$script_basename finished after $SECONDS seconds"
  exit 0
}

is_set()       { [[ "$1" -gt 0 ]]; }
is_empty()     { [[ -z "$1" ]] ; }
is_not_empty() { [[ -n "$1" ]] ; }

is_file() { [[ -f "$1" ]] ; }
is_dir()  { [[ -d "$1" ]] ; }

is_number(){ local re='^[0-9]+$'; [[ "$1" =~ $re ]] ; }

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$prog_modified${col_reset}"

  echo -n "Usage: $script_basename"
   list_options \
  | awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     } else {
          fulltext = fulltext sprintf("\n    %-10s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

show_tips(){
  < "${BASH_SOURCE[0]}" grep -v "\$0" \
  | awk "
  /TIP: / {\$1=\"\"; gsub(/«/,\"$col_grn\"); gsub(/»/,\"$col_reset\"); print \"*\" \$0}
  /TIP:> / {\$1=\"\"; print \" $col_ylw\" \$0 \"$col_reset\"}
  "
}

init_options() {
	local init_command
    init_command=$(list_options \
    | awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    ')
    if [[ -n "$init_command" ]] ; then
        #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
        eval "$init_command"
   fi
}

require_binaries(){
  os_name=$(uname -s)
  os_version=$(uname -sprm)
  log "Running: on $os_name ($os_version)"
  list_programs=$(echo "$*" | sort -u |  tr "\n" " ")
  log "Verify : $list_programs"
  for prog in "$@" ; do
    # shellcheck disable=SC2230
    if [[ -z $(which "$prog") ]] ; then
      die "$script_basename needs [$prog] but this program cannot be found on this [$os_name] machine"
    fi
  done
}

folder_prep(){
  if [[ -n "$1" ]] ; then
      local folder="$1"
      local max_days=${2:-365}
      if [[ ! -d "$folder" ]] ; then
          log "Create folder : [$folder]"
          mkdir "$folder"
      else
          log "Cleanup folder: [$folder] - delete files older than $max_days day(s)"
          find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
      fi
  fi
}

expects_single_params(){
  list_options | grep 'param|1|' > /dev/null
  }
expects_optional_params(){
  list_options | grep 'param|?|' > /dev/null
  }
expects_multi_param(){
  list_options | grep 'param|n|' > /dev/null
  }

count_words(){
  wc -w \
  | awk '{ gsub(/ /,""); print}'
}

parse_options() {
    if [[ $# -eq 0 ]] ; then
       show_usage >&2 ; safe_exit
    fi

    ## first process all the -x --xxxx flags and options
    while true; do
      # flag <flag> is saved as $flag = 0/1
      # option <option> is saved as $option
      if [[ $# -eq 0 ]] ; then
        ## all parameters processed
        break
      fi
      if [[ ! $1 = -?* ]] ; then
        ## all flags/options processed
        break
      fi
	  local save_option
      save_option=$(list_options \
        | awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
        if [[ -n "$save_option" ]] ; then
          if echo "$save_option" | grep shift >> /dev/null ; then
            local save_var
            save_var=$(echo "$save_option" | cut -d= -f1)
            log "Found  : ${save_var}=$2"
          else
            log "Found  : $save_option"
          fi
          eval "$save_option"
        else
            die "cannot interpret option [$1]"
        fi
        shift
    done

    ((help)) && (
      echo "### USAGE"
      show_usage
      echo ""
      echo "### EXAMPLES"
      show_tips
      safe_exit
    )

    ## then run through the given parameters
  if expects_single_params ; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    log "Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params ; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]]  && die "need parameter [$param]"
      log "Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    log "No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_optional_params ; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    log "Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params ; do
      log "Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    log "No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param ; then
    #log "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    log "Expect : $multi_count multi parameter: $multi_param"
    (( multi_count > 1 )) && die "cannot have >1 'multi' parameter: [$multi_param]"
    (( multi_count > 0 )) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]] ; then
      log "Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

lookup_script_data(){
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  readonly execution_day=$(date "+%Y-%m-%d")

  # cf https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
  script_install_path="${BASH_SOURCE[0]}"
  script_install_folder=$(dirname "$script_install_path")
  while [ -h "$script_install_path" ]; do
    # resolve symbolic links
    script_install_folder="$( cd -P "$( dirname "$script_install_path" )" >/dev/null 2>&1 && pwd )"
    script_install_path="$(readlink "$script_install_path")"
    [[ "$script_install_path" != /* ]] && script_install_path="$script_install_folder/$script_install_path"
  done

  log "Executing : [$script_install_path]"
  log "In folder : [$script_install_folder]"

  # $script_install_folder  = [/Users/<username>/.basher/cellar/packages/pforret/<script>]
  # $script_install_path    = [/Users/<username>/.basher/cellar/packages/pforret/bashew/<script>]
  # $script_basename        = [<script>.sh]
  # $script_prefix          = [<script>]

  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
}

prep_log_and_temp_dir(){
  tmp_file=""
  log_file=""
  # shellcheck disable=SC2154
  if is_not_empty "$tmp_dir" ; then
    folder_prep "$tmp_dir" 30
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    log "tmp_file: $tmp_file"
    # you can use this temporary file in your program
    # it will be deleted automatically if the program ends without errors
  fi
  # shellcheck disable=SC2154
  if [[ -n "$log_dir" ]] ; then
    folder_prep "$log_dir" 30
    log_file=$log_dir/$script_prefix.$execution_day.log
    log "log_file: $log_file"
    # echo "$(date '+%H:%M:%S') | [$script_basename] $script_version started" >> "$log_file"
  fi
}

import_env_if_any(){
  if [[ -f "$script_install_folder/.env" ]] ; then
    log "Read config from [$script_install_folder/.env]"
    # shellcheck disable=SC1090
    source "$script_install_folder/.env"
  fi
}

[[ $run_as_root == 1  ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

lookup_script_data

# set default values for flags & options
init_options

# overwrite with .env if any
import_env_if_any

# overwrite with specified options if any
parse_options "$@"

# clean up log and temp folder
prep_log_and_temp_dir

# run main program
main

# exit and clean up
safe_exit
