brew-setup-ruby() {
  source "${HOMEBREW_LIBRARY}/utils/helpers.sh"
  source "${HOMEBREW_LIBRARY}/utils/ruby.sh"
  setup-ruby-path

  if [[ -z "${HOMEBREW_DEVELOPER}" ]]
  then
    return
  fi

  # Avoid running Bundler if the command doesn't need it.
  local command="$1"
  if [[ -n "${command}" ]]
  then
    source "${HOMEBREW_LIBRARY}/command_path.sh"

    command_path="$(homebrew-command-path "${command}")"
    if [[ -n "${command_path}" ]]
    then
      if [[ "${command_path}" != *"/dev-cmd/"* ]]
      then
        return
      elif ! grep -q "Homebrew.install_bundler_gems\!" "${command_path}"
      then
        return
      fi
    fi
  fi

  setup-gem-home-bundle-gemfile

  if ! bundle check &>/dev/null
  then
    "${HOMEBREW_BREW_FILE}" install-bundler-gems
  fi
}