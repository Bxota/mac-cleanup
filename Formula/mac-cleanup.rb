class MacCleanup < Formula
  desc "Nettoyage automatique hebdomadaire pour macOS (caches, node_modules, build artifacts)"
  homepage "https://github.com/Bxota/mac-cleanup"
  url "https://github.com/Bxota/mac-cleanup/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "7fb9b4939f98d9587e8b5e02860fad92961f95b8a8f05b278d8b7d1b77898144"
  version "1.0.0"
  license "MIT"

  def install
    bin.install "mac-cleanup.sh" => "mac-cleanup"
  end

  service do
    run opt_bin/"mac-cleanup"
    keep_alive false
    cron "0 10 * * 6"
    log_path "#{Dir.home}/.local/share/mac-cleanup/launchd.log"
    error_log_path "#{Dir.home}/.local/share/mac-cleanup/launchd.log"
    process_type :background
  end

  test do
    system "#{bin}/mac-cleanup", "--dry-run"
  end
end
