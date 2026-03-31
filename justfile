# grostat — Growatt inverter data collector

_default:
    @just --list

# Build debug binary
build:
    swift build

# Build release binary
release:
    swift build -c release

# Run grostat (debug build)
run *ARGS:
    swift run grostat {{ARGS}}

# Run all checks (build + lint)
check: build lint

# Lint with swiftlint (if installed)
lint:
    @if command -v swiftlint >/dev/null; then swiftlint lint Sources/; else echo "swiftlint not installed, skipping"; fi

# Format with swift-format (if installed)
fmt:
    @if command -v swift-format >/dev/null; then swift-format format -i -r Sources/; else echo "swift-format not installed, skipping"; fi

# Clean build artifacts
clean:
    swift package clean
    rm -rf .build

# Show binary size
size: release
    @ls -lh .build/release/grostat | awk '{print $5}'

# Create release tarball for Homebrew
tarball VERSION: release
    cd .build/release && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat
    @shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz

homebrew_repo := "../homebrew-grostat"

# Full release: tag, push, gh release, upload binary, update homebrew formula
publish VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Tagging v{{VERSION}}"
    git tag v{{VERSION}}
    git push origin v{{VERSION}}
    echo "==> Creating GitHub release"
    gh release create v{{VERSION}} --title "v{{VERSION}}" --generate-notes
    echo "==> Building release binary"
    swift build -c release
    echo "==> Creating tarball"
    cd .build/release && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat
    echo "==> Uploading to release"
    gh release upload v{{VERSION}} /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz
    SHA=$(shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz | awk '{print $1}')
    echo "==> Updating homebrew formula (SHA: $SHA)"
    cd {{homebrew_repo}}
    sed -i '' "s|url \".*\"|url \"https://github.com/zalun/grostat/releases/download/v{{VERSION}}/grostat-{{VERSION}}-arm64-macos.tar.gz\"|" Formula/grostat.rb
    sed -i '' "s|sha256 \".*\"|sha256 \"$SHA\"|" Formula/grostat.rb
    sed -i '' "s|version \".*\"|version \"{{VERSION}}\"|" Formula/grostat.rb
    git add Formula/grostat.rb
    git commit -m "Update formula to v{{VERSION}}"
    git push origin main
    echo "==> Done! Run 'brew update && brew upgrade grostat' to install."
