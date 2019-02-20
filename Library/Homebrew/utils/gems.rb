# Never `require` anything in this file. It needs to be able to work as the
# first item in `brew.rb` so we can load gems with Bundler when needed before
# anything else is loaded (e.g. `json`).

module Homebrew
  module_function

  def setup_gem_environment!
    @setup_gem_environment ||= begin
      # Match where our bundler gems are.
      ruby_bindir = "#{RbConfig::CONFIG["prefix"]}/bin"
      ENV["GEM_HOME"] = "#{ENV["HOMEBREW_LIBRARY"]}/Homebrew/vendor/bundle/ruby/#{RbConfig::CONFIG["ruby_version"]}"
      ENV["GEM_PATH"] = ENV["GEM_HOME"]

      # Make RubyGems notice environment changes.
      Gem.clear_paths
      Gem::Specification.reset

      # Add necessary Ruby and Gem binary directories to PATH.
      paths = ENV["PATH"].split(":")
      paths.unshift(ruby_bindir) unless paths.include?(ruby_bindir)
      paths.unshift(Gem.bindir) unless paths.include?(Gem.bindir)
      ENV["PATH"] = paths.compact.join(":")

      puts "ruby_bindir: #{ruby_bindir}"
      puts "Gem.bindir: #{Gem.bindir}"
      puts "PATH: #{ENV["PATH"]}"
      puts "GEM_HOME: #{ENV["GEM_HOME"]}"
      puts "GEM_PATH: #{ENV["GEM_PATH"]}"

      true
    end
  end

  def install_gem!(name, version = nil)
    setup_gem_environment!
    return unless Gem::Specification.find_all_by_name(name, version).empty?

    # Shell out to `gem` to avoid RubyGems requires e.g. loading JSON.
    puts "==> Installing '#{name}' gem"
    install_args = %W[--no-document #{name}]
    install_args << "--version" << version if version
    return if system "gem", "install", *install_args

    puts `gem install #{install_args.join(" ")} 2>&1`

    $stderr.puts "Error: failed to install the '#{name}' gem."
    exit 1
  end

  def install_gem_setup_path!(name, executable: name)
    install_gem!(name)
    return if ENV["PATH"].split(":").any? do |path|
      File.executable?("#{path}/#{executable}")
    end

    $stderr.puts <<~EOS
      Error: the '#{name}' gem is installed but couldn't find '#{executable}' in the PATH:
      #{ENV["PATH"]}
    EOS
    exit 1
  end

  def install_bundler!
    install_gem_setup_path! "bundler", executable: "bundle"
  end

  def install_bundler_gems!
    @install_bundler_gems ||= begin
      install_bundler!
      ENV["BUNDLE_GEMFILE"] = "#{ENV["HOMEBREW_LIBRARY"]}/Homebrew/test/Gemfile"
      system "bundle", "install" unless system("bundle check &>/dev/null")
      setup_gem_environment!
      true
    end
  end
end
