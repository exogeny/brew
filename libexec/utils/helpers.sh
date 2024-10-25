# These variables are set from the user environment.
# shellcheck disable=SC2154
ohai() {
  # Check whether stdout is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 1 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -e "\\033[34m==>\\033[0m \\033[1m$*\\033[0m" # blue arrow and bold text
  else
    echo "==> $*"
  fi
}

opoo() {
  # Check whether stderr is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 2 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -ne "\\033[4;33mWarning\\033[0m: " >&2 # highlight Warning with underline and yellow color
  else
    echo -n "Warning: " >&2
  fi
  if [[ $# -eq 0 ]]
  then
    cat >&2
  else
    echo "$*" >&2
  fi
}

bold() {
  # Check whether stderr is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 2 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -e "\\033[1m""$*""\\033[0m"
  else
    echo "$*"
  fi
}

onoe() {
  # Check whether stderr is a tty.
  if [[ -n "${HOMEBREW_COLOR}" || (-t 2 && -z "${HOMEBREW_NO_COLOR}") ]]
  then
    echo -ne "\\033[4;31mError\\033[0m: " >&2 # highlight Error with underline and red color
  else
    echo -n "Error: " >&2
  fi
  if [[ $# -eq 0 ]]
  then
    cat >&2
  else
    echo "$*" >&2
  fi
}

odie() {
  onoe "$@"
  exit 1
}

safe_cd() {
  cd "$@" >/dev/null || odie "Failed to cd to $*!"
}

brew() {
  # This variable is set by bin/brew
  # shellcheck disable=SC2154
  "${HOMEBREW_BREW_FILE}" "$@"
}

curl() {
  "${HOMEBREW_SHIMS_PATH}/shared/curl" "$@"
}

git() {
  "${HOMEBREW_SHIMS_PATH}/shared/git" "$@"
}

# Search given executable in PATH (remove dependency for `which` command)
which() {
  # Alias to Bash built-in command `type -P`
  type -P "$@"
}

numeric() {
  local -a version_array
  IFS=".rc" read -r -a version_array <<<"${1}"
  printf "%01d%02d%02d%03d" "${version_array[@]}" 2>/dev/null
}

columns() {
  if [[ -n "${COLUMNS}" ]]
  then
    echo "${COLUMNS}"
    return
  fi

  local columns
  read -r _ columns < <(stty size 2>/dev/null)

  if [[ -z "${columns}" ]] && tput cols >/dev/null 2>&1
  then
    columns="$(tput cols)"
  fi

  echo "${columns:-80}"
}

# NOTE: The members of the array in the second arg must not have spaces!
check-array-membership() {
  local item=$1
  shift

  if [[ " ${*} " == *" ${item} "* ]]
  then
    return 0
  else
    return 1
  fi
}

check-prefix-is-not-tmpdir() {
  [[ -z "${HOMEBREW_MACOS}" ]] && return

  if [[ "${HOMEBREW_PREFIX}" == "${HOMEBREW_TEMP}"* ]]
  then
    odie <<EOS
Your HOMEBREW_PREFIX is in the Homebrew temporary directory, which Homebrew
uses to store downloads and builds. You can resolve this by installing Homebrew
to either the standard prefix for your platform or to a non-standard prefix that
is not in the Homebrew temporary directory.
EOS
  fi
}