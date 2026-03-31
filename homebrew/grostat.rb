class Grostat < Formula
  include Language::Python::Virtualenv

  desc "Growatt inverter data collector — full telemetry to SQLite"
  homepage "https://github.com/zalun/grostat"
  url "https://github.com/zalun/grostat/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "python@3.12"

  # Add Python package resources here.
  # Generate with: pip compile pyproject.toml | homebrew-pypi-poet
  # Or manually list each dependency.

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "grostat", shell_output("#{bin}/grostat --help")
  end
end
