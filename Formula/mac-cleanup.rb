class MacCleanup < Formula
  desc "Nettoyage automatique hebdomadaire pour macOS (caches, node_modules, build artifacts)"
  homepage "https://github.com/Bxota/mac-cleanup"
  url "https://github.com/Bxota/mac-cleanup/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  version "1.0.0"
  license "MIT"

  def install
    bin.install "mac-cleanup.sh" => "mac-cleanup"
  end

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>

        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/mac-cleanup</string>
        </array>

        <key>StartCalendarInterval</key>
        <dict>
          <key>Weekday</key>
          <integer>6</integer>
          <key>Hour</key>
          <integer>10</integer>
          <key>Minute</key>
          <integer>0</integer>
        </dict>

        <key>StandardOutPath</key>
        <string>~/.local/share/mac-cleanup/launchd.log</string>

        <key>StandardErrorPath</key>
        <string>~/.local/share/mac-cleanup/launchd.log</string>

        <key>ProcessType</key>
        <string>Background</string>
      </dict>
      </plist>
    EOS
  end

  test do
    system "#{bin}/mac-cleanup", "--dry-run"
  end
end
