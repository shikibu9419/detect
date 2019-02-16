detect() {
  bash $DETECTOR_REPO_DIR/detect.bash $@
}

dir=$(realpath "$0")
export DETECTOR_REPO_DIR=${dir%/*}
