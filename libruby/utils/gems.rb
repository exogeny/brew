# typed: true  # rubocop:disable Sorbet/StrictSigil
# frozen_string_literal: true

# Never `require` anything in this file (except English). It needs to be able to
# work as the first item in `brew.rb` so we can load gems with Bundler when
# needed before anything else is loaded (e.g. `json`).

require "English"

module Homebrew
  # Keep in sync with the `Gemfile.lock`'s BUNDLED WITH.
  # After updating this, run `brew vendor-gems --update=--bundler`.
  HOMEBREW_BUNDLER_VERSION = "2.5.20"

  # Bump this whenever a committed vendored gem is later added to or exclusion removed from gitignore.
  # This will trigger it to reinstall properly if `brew install-bundler-gems` needs it.
  VENDOR_VERSION = 7
  private_constant :VENDOR_VERSION

  RUBY_BUNDLE_VENDOR_DIRECTORY = (HOMEBREW_LIBRARY_PATH/"vendor/bundle/ruby").freeze
  private_constant :RUBY_BUNDLE_VENDOR_DIRECTORY

  # This is tracked across Ruby versions.
  GEM_GROUPS_FILE = (RUBY_BUNDLE_VENDOR_DIRECTORY/".homebrew_gem_groups").freeze
  private_constant :GEM_GROUPS_FILE

  # This is tracked per Ruby version.
  VENDOR_VERSION_FILE = (
    RUBY_BUNDLE_VENDOR_DIRECTORY/"#{RbConfig::CONFIG["ruby_version"]}/.homebrew_vendor_version"
  ).freeze
  private_constant :VENDOR_VERSION_FILE

  def self.gemfile
    File.join(ENV.fetch("HOMEBREW_LIBRARY"), "Homebrew", "Gemfile")
  end
  private_class_method :gemfile

  def self.bundler_definition
    @bundler_definition ||= Bundler::Definition.build(Bundler.default_gemfile, Bundler.default_lockfile, false)
  end
  private_class_method :bundler_definition

  def self.valid_gen_groups
    install_bundler!
    require "bundler"

    Bundler.with_unbundled_env do
      ENV["BUNDLE_GEMFILE"] = gemfile
      groups = bundler_definition.groups
      groups.delete(:default)
      groups.map(&:to_s)
    end
  end

  def self.ruby_bindir
    "#{RbConfig::CONFIG["prefix"]}/bin"
  end

  def self.ohai_if_defined(message)
    if defined?(ohai)
      $stderr.ohai message
    else
      $stderr.puts "==> #{message}"
    end
  end

  def self.opoo_if_defined(message)
    if defined?(opoo)
      $stderr.opoo message
    else
      $stderr.puts "Warning: #{message}"
    end
  end

  def self.odie_if_defined(message)
    if defined?(odie)
      odie message
    else
      $stderr.puts "Error: #{message}"
      exit 1
    end
  end

  def self.setup_gem_environment!(setup_path: true)
    require "rubygems"
    raise "RubyGems too old!" if Gem::Version.new(Gem::VERSION) < Gem::Version.new("2.2.0")
  end
end
