detect() {
  zsh $DETECT_REPO_DIR/detect $@
}

dir=$(realpath "$0")
export DETECT_REPO_DIR=${dir%/*}
