source "${HOMEBREW_LIBRARY}/utils/lock.sh"

# Replaces the function in Library/Homebrew/brew.sh to cache the Curl/Git executable to
# provide speedup when using Curl/Git repeatedly (as update.sh does).
curl() {
  if [[ -z "${CURL_EXECUTABLE}" ]]
  then
    CURL_EXECUTABLE="$("${HOMEBREW_SHIMS_PATH}/shared/curl" --homebrew=print-path)"
    if [[ -z "${CURL_EXECUTABLE}" ]]
    then
      odie "Can't find a working Curl!"
    fi
  fi
  "${CURL_EXECUTABLE}" "$@"
}

git() {
  if [[ -z "${GIT_EXECUTABLE}" ]]
  then
    GIT_EXECUTABLE="$("${HOMEBREW_SHIMS_PATH}/shared/git" --homebrew=print-path)"
    if [[ -z "${GIT_EXECUTABLE}" ]]
    then
      odie "Can't find a working Git!"
    fi
  fi
  "${GIT_EXECUTABLE}" "$@"
}

git_init_if_necessary() {
  safe_cd "${HOMEBREW_REPOSITORY}"
  if [[ ! -d ".git" ]]
  then
    set -e
    trap '{ rm -rf .git; exit 1; }' EXIT
    git init
    git config --bool core.autocrlf false
    git config --bool core.symlinks true
    if [[ "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}" != "${HOMEBREW_BREW_GIT_REMOTE}" ]]
    then
      echo "HOMEBREW_BREW_GIT_REMOTE set: using ${HOMEBREW_BREW_GIT_REMOTE} as the Homebrew/brew Git remote."
    fi
  fi
}

brew-update() {
  local option
  local DIR
  local UPSTREAM_BRANCH

  for option in "$@"
  do
    case "${option}" in
      -\? | -h | --help | --usage)
        brew help update
        exit $?
        ;;
      --verbose) HOMEBREW_VERBOSE=1 ;;
      --debug) HOMEBREW_DEBUG=1 ;;
      --quiet) HOMEBREW_QUIET=1 ;;
      --merge)
        shift
        HOMEBREW_MERGE=1
        ;;
      --force) HOMEBREW_UPDATE_FORCE=1 ;;
      --simulate-from-current-branch)
        shift
        HOMEBREW_SIMULATE_FROM_CURRENT_BRANCH=1
        ;;
      --auto-update) export HOMEBREW_UPDATE_AUTO=1 ;;
      --*) ;;
      -*)
        [[ "${option}" == *v* ]] && HOMEBREW_VERBOSE=1
        [[ "${option}" == *q* ]] && HOMEBREW_QUIET=1
        [[ "${option}" == *d* ]] && HOMEBREW_DEBUG=1
        [[ "${option}" == *f* ]] && HOMEBREW_UPDATE_FORCE=1
        ;;
      *)
        odie <<EOS
This command updates brew itself, and does not take formula names.
Use \`brew upgrade $@\` instead.
EOS
        ;;
    esac
  done

  if [[ -n "${HOMEBREW_DEBUG}" ]]
  then
    set -x
  fi

  if [[ -z "${HOMEBREW_UPDATE_CLEANUP}" && -z "${HOMEBREW_UPDATE_TO_TAG}" ]]
  then
    if [[ -n "${HOMEBREW_DEVELOPER}" || -n "${HOMEBREW_DEV_CMD_RUN}" ]]
    then
      export HOMEBREW_NO_UPDATE_CLEANUP="1"
    else
      export HOMEBREW_UPDATE_TO_TAG="1"
    fi
  fi

  # check permissions
  if [[ -e "${HOMEBREW_CELLAR}" && ! -w "${HOMEBREW_CELLAR}" ]]
  then
    odie <<EOS
${HOMEBREW_CELLAR} is not writable. You should change the
ownership and permissions of ${HOMEBREW_CELLAR} back to your
user account:
  sudo chown -R ${USER-\$(whoami)} ${HOMEBREW_CELLAR}
EOS
  fi

  if [[ -d "${HOMEBREW_CORE_REPOSITORY}" ]] ||
     [[ -z "${HOMEBREW_NO_INSTALL_FROM_API}" ]]
  then
    HOMEBREW_CORE_AVAILABLE="1"
  fi

  if [[ ! -w "${HOMEBREW_REPOSITORY}" ]]
  then
    odie <<EOS
${HOMEBREW_REPOSITORY} is not writable. You should change the
ownership and permissions of ${HOMEBREW_REPOSITORY} back to your
user account:
  sudo chown -R ${USER-\$(whoami)} ${HOMEBREW_REPOSITORY}
EOS
  fi

  # we may want to use Homebrew CA certificates
  if [[ -n "${HOMEBREW_FORCE_BREWED_CA_CERTIFICATES}" && ! -f "${HOMEBREW_PREFIX}/etc/ca-certificates/cert.pem" ]]
  then
    # we cannot install Homebrew CA certificates if homebrew/core is unavailable.
    if [[ -n "${HOMEBREW_CORE_AVAILABLE}" ]]
    then
      brew install ca-certificates
      setup_ca_certificates
    fi
  fi

  # we may want to use a Homebrew curl
  if [[ -n "${HOMEBREW_FORCE_BREWED_CURL}" && ! -x "${HOMEBREW_PREFIX}/opt/curl/bin/curl" ]]
  then
    # we cannot install a Homebrew cURL if homebrew/core is unavailable.
    if [[ -z "${HOMEBREW_CORE_AVAILABLE}" ]] || ! brew install curl
    then
      odie "'curl' must be installed and in your PATH!"
    fi

    setup_curl
  fi

  if ! git --version &>/dev/null ||
     [[ -n "${HOMEBREW_FORCE_BREWED_GIT}" && ! -x "${HOMEBREW_PREFIX}/opt/git/bin/git" ]]
  then
    # we cannot install a Homebrew Git if homebrew/core is unavailable.
    if [[ -z "${HOMEBREW_CORE_AVAILABLE}" ]] || ! brew install git
    then
      odie "'git' must be installed and in your PATH!"
    fi

    setup_git
  fi

  [[ -f "${HOMEBREW_CORE_REPOSITORY}/.git/shallow" ]] && HOMEBREW_CORE_SHALLOW=1
  [[ -f "${HOMEBREW_CASK_REPOSITORY}/.git/shallow" ]] && HOMEBREW_CASK_SHALLOW=1
  if [[ -n "${HOMEBREW_CORE_SHALLOW}" && -n "${HOMEBREW_CASK_SHALLOW}" ]]
  then
    SHALLOW_COMMAND_PHRASE="These commands"
    SHALLOW_REPO_PHRASE="repositories"
  else
    SHALLOW_COMMAND_PHRASE="This command"
    SHALLOW_REPO_PHRASE="repository"
  fi

  if [[ -n "${HOMEBREW_CORE_SHALLOW}" || -n "${HOMEBREW_CASK_SHALLOW}" ]]
  then
    odie <<EOS
${HOMEBREW_CORE_SHALLOW:+
  homebrew-core is a shallow clone.}${HOMEBREW_CASK_SHALLOW:+
  homebrew-cask is a shallow clone.}
To \`brew update\`, first run:${HOMEBREW_CORE_SHALLOW:+
  git -C "${HOMEBREW_CORE_REPOSITORY}" fetch --unshallow}${HOMEBREW_CASK_SHALLOW:+
  git -C "${HOMEBREW_CASK_REPOSITORY}" fetch --unshallow}
${SHALLOW_COMMAND_PHRASE} may take a few minutes to run due to the large size of the ${SHALLOW_REPO_PHRASE}.
This restriction has been made on GitHub's request because updating shallow
clones is an extremely expensive operation due to the tree layout and traffic of
Homebrew/homebrew-core and Homebrew/homebrew-cask. We don't do this for you
automatically to avoid repeatedly performing an expensive unshallow operation in
CI systems (which should instead be fixed to not use shallow clones). Sorry for
the inconvenience!
EOS
  fi

  export GIT_TERMINAL_PROMPT="0"
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -oBatchMode=yes"

  if [[ -n "${HOMEBREW_GIT_NAME}" ]]
  then
    export GIT_AUTHOR_NAME="${HOMEBREW_GIT_NAME}"
    export GIT_COMMITTER_NAME="${HOMEBREW_GIT_NAME}"
  fi

  if [[ -n "${HOMEBREW_GIT_EMAIL}" ]]
  then
    export GIT_AUTHOR_EMAIL="${HOMEBREW_GIT_EMAIL}"
    export GIT_COMMITTER_EMAIL="${HOMEBREW_GIT_EMAIL}"
  fi

  if [[ -z "${HOMEBREW_VERBOSE}" ]]
  then
    export GIT_ADVICE="false"
    QUIET_ARGS=(-q)
  else
    QUIET_ARGS=()
  fi

  # HOMEBREW_CURLRC is optionally defined in the user environment.
  # shellcheck disable=SC2153
  if [[ -z "${HOMEBREW_CURLRC}" ]]
  then
    CURL_DISABLE_CURLRC_ARGS=(-q)
  else
    CURL_DISABLE_CURLRC_ARGS=()
  fi

  # only allow one instance of brew update
  lock update

  git_init_if_necessary
}
