#!/usr/bin/env ruby
# Used by `.kamal/secrets` (Dotenv format). Kamal does not run that file as a shell script.
# Reads one KEY from the project root `.env` (gitignored). Optional ENV fallback for deploy tokens.
key = ARGV[0] or abort("usage: ruby .kamal/fetch_env_secret.rb KEY")

path = File.expand_path("../.env", __dir__)
h = {}
if File.exist?(path)
  File.foreach(path, chomp: true) do |line|
    stripped = line.strip
    next if stripped.empty? || stripped.start_with?("#")

    k, v = stripped.split("=", 2)
    next if v.nil?

    v = v.strip
    # Strip matching outer quotes (MAILER_FROM='Name <a@b.com>')
    if v.length >= 2 && ((v.start_with?("'") && v.end_with?("'")) || (v.start_with?('"') && v.end_with?('"')))
      v = v[1..-2]
    end
    h[k.strip] = v
  end
end

val = h[key].to_s
# Registry token is often only exported in the deploy shell, not committed to `.env`.
val = ENV.fetch(key, "").to_s if val.empty? && key == "KAMAL_REGISTRY_PASSWORD"

print val
