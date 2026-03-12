class Alertmanager < Formula
  desc "Handle and route alerts created by Prometheus"
  homepage "https://github.com/prometheus/alertmanager"
  license "Apache-2.0"
  version "0.31.1"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/prometheus/alertmanager/releases/download/v#{version}/alertmanager-#{version}.darwin-arm64.tar.gz"
      sha256 "d568f4b79d81f221d5510fe3942b2395392eff286918a11f25e81166ed9d3496"
    else
      url "https://github.com/prometheus/alertmanager/releases/download/v#{version}/alertmanager-#{version}.darwin-amd64.tar.gz"
      sha256 "e27d8a72ba5c094ce37300ef0ef769ebeaa210cf463a0412ddb32b4a071e6ea3"
    end
  end

  def install
    bin.install "alertmanager", "amtool"
    pkgshare.install "alertmanager.yml"
  end

  service do
    run [
      "/bin/sh",
      "-lc",
      "exec #{opt_bin}/alertmanager $(tr '\\n' ' ' < #{etc}/alertmanager.args)"
    ]
    keep_alive true
    working_dir var
    log_path var/"log/alertmanager.log"
    error_log_path var/"log/alertmanager.log"
  end

  def caveats
    <<~EOS
      When run from `brew services`, `alertmanager` uses flags from:
        #{etc}/alertmanager.args
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/alertmanager --version")
  end
end
