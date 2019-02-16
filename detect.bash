readonly BLACK='\033[30m'
readonly RED='\033[31m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly MAGENTA='\033[35m'
readonly CYAN='\033[36m'
readonly WHITE='\033[37m'
readonly BOLD='\033[1m'
readonly DEFAULT='\033[m'

readonly HIGHLIGHT='highlight --force -O ansi'
readonly BACK_LABEL="${BLUE}${BOLD}<-- back${DEFAULT}"
readonly DEF_LABEL="${MAGENTA}${BOLD}def${DEFAULT}"
readonly REF_LABEL="${GREEN}${BOLD}ref${DEFAULT}"

has() {
  return $(type "$1" > /dev/null 2>&1)
}

error() {
  echo $1 1>&2
  exit 1
}

confirm() {
  read -n1 -p "$1 (y/N)": yn
  [[ $yn =~ [yY] ]] && return 0 || return 1
}

detect::main() {
  detect::check

  if [ $1 = '-c' ]; then
    confirm 'Do you really want to clear GTAGS files?' \
      && rm $(git rev-parse --show-cdup){GPATH,GTAGS,GRTAGS} \
      && echo 'Cleared.'
  elif [ $1 = '-g' ]; then
    detect::grep $@
  elif [ -d $1 ]; then
    detect::search_file $@
  elif [ -f $1 ]; then
    detect::search_def $@
  else
    detect::detect $@
  fi
}

detect::check() {
  $(git rev-parse > /dev/null 2>&1) || error 'fatal: not a git repository.'
  has 'fzf'    || error "fatal: fzf is not installed."
  has 'global' || error "fatal: global is not installed."

  if ! $(global -u); then
    confirm 'Do you want to generate GTAGS files?' \
      && gtags -v $(git rev-parse --show-cdup) \
      || error 'detect: detection aborted.'
    echo
  fi
}

detect::search_file() {
  filelist=$(git ls-files $1)

  [[ -z $filelist ]] && error "detect: there is no file in $1."

  while true; do
    file=$(echo -e "$filelist" | fzf --ansi --prompt="$1> " --preview="$HIGHLIGHT {}" | awk '{ print $1 }')

    [[ -z $file ]] && exit 0

    detect::search_def "$file"
  done
}

detect::search_def() {
  deflist=$(global -fx $1 | awk '{ print $1 " - " $2 }')

  [[ -z $deflist ]] && detect::detect_error

  while true; do
    defs=$(echo -e "$deflist\n$BACK_LABEL" | fzf -m --ansi --prompt="$content> " \
      --preview="set {}; \
        line=\$(cont=\${1}; $HIGHLIGHT $1 | sed -n \${3}p | grep --color=always \${cont/\?/\\\\?}); \
        $HIGHLIGHT $1 |
        sed -E '{3}'\"s/.*/\$line/\"" |
      awk '{ print $1 }' | sort | uniq |
      tr '\n' '|' | sed -e 's/|$//')

    [[ -z $defs ]] && exit 0
    echo $defs | grep -q '<--' && return 0

    detect::detect "($defs)"
  done
}

detect::detect() {
  content=$1

  defs=$(global -dx $content | awk "{ print \"${DEF_LABEL}${YELLOW} \" \$1 \" ${DEFAULT}: \" \$3 \" - \" \$2 }")
  refs=$(global -rx $content | awk "{ print \"${REF_LABEL}${YELLOW} \" \$1 \" ${DEFAULT}: \" \$3 \" - \" \$2 }")
  defrefs=$(echo -e "$defs\n$refs\n$BACK_LABEL" | sed '/^$/d')

  [[ -z $defrefs ]] && detect::detect_error

  while true; do
    files=$(echo "$defrefs" | fzf -m --ansi --prompt="$content> " \
      --preview="set {}; \
        line=\$(cont={2}; $HIGHLIGHT \${4} | sed -n \${6}p | grep --color=always \${cont/\?/\\\\?}); \
        $HIGHLIGHT \${4} |
        sed -E '{6}'\"s/.*/\$line/\"" |
      awk '{ if($4 == "") print $1; else print $4 }' | sort | uniq)

    [[ -z $files ]] && exit 0
    echo $files | grep -q '<--' && return 0

    echo $files | xargs nvim -p
  done
}

detect::grep() {
  content=$2

  greps=$(global -gx $content | awk "{ print \$3 \" - \" \$2 }" | sed '/^$/d')

  [[ -z $greps ]] && detect::detect_error

  while true; do
    files=$(echo "$greps" | fzf -m --ansi --prompt="$content> " \
      --preview="set {}; \
        line=\$(cont=$content; $HIGHLIGHT \${1} | sed -n \${3}p | grep --color=always \${cont/\?/\\\\?}); \
        $HIGHLIGHT \${1} |
        sed -E '{3}'\"s/.*/\$line/\"" |
      awk '{ print $1 }' | sort | uniq)

    [[ -z $files ]] && exit 0
    echo $files | xargs nvim -p
  done
}

detect::detect_error() {
  error "detect: nothing is detected."
}

detect::main "$@"
