readonly HIGHLIGHT='highlight --force -O ansi'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly MAGENTA='\033[35m'
readonly BOLD='\033[1m'
readonly DEFAULT='\033[m'

has() {
  return $(type "$1" > /dev/null 2>&1)
}

error() {
  echo $1 1>&2
  exit 1
}

confirm() {
  printf "$1 (y/N): "
  if read -q; then
    echo; return 0
  else
    echo; return 1
  fi
}

detect::main() {
  detect::check

  if [ $1 = '-c' ]; then
    confirm 'Do you really want to clear GTAGS files?' && rm $(git rev-parse --show-cdup){GPATH,GTAGS,GRTAGS}
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
  list=$(git ls-files $1)

  [[ -z $list ]] && error "detect: there is no file in $1."

  file=$(echo "$list" | fzf --ansi --prompt="$1> " --preview="$HIGHLIGHT {}" | awk '{ print $1 }')

  [[ -z $file ]] && detect::detect_error

  detect::search_def "$file"
}

detect::search_def() {
  list=$(global -fx $1 | awk '{ print $1 " - " $2 }')

  [[ -z $list ]] && detect::detect_error

  defs=$(echo "$list" | fzf -m --ansi --prompt="$content> " \
    --preview="set {}; \
      line=\$(cont=\${1}; $HIGHLIGHT $1 | sed -n \${3}p | grep --color=always \${cont/\?/\\\\?}); \
      $HIGHLIGHT $1 |
      sed -E '{3}'\"s/.*/\$line/\"" |
    awk '{ print $1 }' | sort | uniq |
    tr '\n' '|' | sed -e 's/|$//')

  [[ -z $defs ]] && detect::detect_error

  detect::detect "($defs)"
}

detect::detect() {
  DEF_LABEL="${MAGENTA}${BOLD}def${DEFAULT}"
  REF_LABEL="${BLUE}${BOLD}ref${DEFAULT}"

  content=$1

  defs=$(global -dx $content | awk "{ print \"${DEF_LABEL}${YELLOW} \" \$1 \" ${DEFAULT}: \" \$3 \" - \" \$2 }")
  refs=$(global -rx $content | awk "{ print \"${REF_LABEL}${YELLOW} \" \$1 \" ${DEFAULT}: \" \$3 \" - \" \$2 }")
  list=$(echo -e "$defs\n$refs" | sed '/^$/d')

  [[ -z $list ]] && detect::detect_error

  while true; do
    files=$(echo "$list" | fzf -m --ansi --prompt="$content> " \
      --preview="set {}; \
        line=\$(cont={2}; $HIGHLIGHT \${4} | sed -n \${6}p | grep --color=always \${cont/\?/\\\\?}); \
        $HIGHLIGHT \${4} |
        sed -E '{6}'\"s/.*/\$line/\"" |
      awk '{ print $4 }' | sort | uniq)

    [[ -z $files ]] && exit 0
    echo $files | xargs nvim -p
  done
}

detect::grep() {
  content=$2

  list=$(global -gx $content | awk "{ print \$3 \" - \" \$2 }" | sed '/^$/d')

  [[ -z $list ]] && detect::detect_error

  while true; do
    files=$(echo "$list" | fzf -m --ansi --prompt="$content> " \
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