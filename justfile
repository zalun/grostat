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
    rm -rf .build GrostatBar/.build GrostatBar/GrostatBar.app

# Show binary size
size: release
    @ls -lh .build/release/grostat | awk '{print $5}'

# Create release tarball for Homebrew
tarball VERSION: release
    cd .build/release && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat
    @shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz

# Build GrostatBar.app
build-app:
    cd GrostatBar && swift build -c release && bash bundle.sh .build/release/GrostatBar

# Create GrostatBar.app zip for release
tarball-app VERSION: build-app
    cd GrostatBar && zip -r /tmp/GrostatBar-{{VERSION}}-arm64-macos.zip GrostatBar.app
    @shasum -a 256 /tmp/GrostatBar-{{VERSION}}-arm64-macos.zip

homebrew_repo := justfile_directory() / "../homebrew-grostat"

# Full release: tag, push, gh release, upload binaries, update homebrew
publish VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Tagging v{{VERSION}}"
    git tag v{{VERSION}}
    git push origin v{{VERSION}}
    echo "==> Creating GitHub release"
    gh release create v{{VERSION}} --title "v{{VERSION}}" --generate-notes
    echo "==> Building CLI release binary"
    swift build -c release
    echo "==> Creating CLI tarball"
    cd .build/release && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat
    echo "==> Building GrostatBar.app"
    cd GrostatBar && swift build -c release && bash bundle.sh .build/release/GrostatBar
    cd GrostatBar && zip -r /tmp/GrostatBar-{{VERSION}}-arm64-macos.zip GrostatBar.app
    echo "==> Uploading to release"
    gh release upload v{{VERSION}} /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz /tmp/GrostatBar-{{VERSION}}-arm64-macos.zip
    CLI_SHA=$(shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz | awk '{print $1}')
    APP_SHA=$(shasum -a 256 /tmp/GrostatBar-{{VERSION}}-arm64-macos.zip | awk '{print $1}')
    echo "==> CLI SHA: $CLI_SHA"
    echo "==> App SHA: $APP_SHA"
    echo "==> Updating homebrew formula"
    cd {{homebrew_repo}}
    sed -i '' "s|url \".*\"|url \"https://github.com/zalun/grostat/releases/download/v{{VERSION}}/grostat-{{VERSION}}-arm64-macos.tar.gz\"|" Formula/grostat.rb
    sed -i '' "s|sha256 \".*\"|sha256 \"$CLI_SHA\"|" Formula/grostat.rb
    sed -i '' "s|version \".*\"|version \"{{VERSION}}\"|" Formula/grostat.rb
    git add Formula/grostat.rb
    git commit -m "Update formula to v{{VERSION}}"
    git push origin main
    echo "==> Done! CLI: 'brew update && brew upgrade grostat'"
    echo "==> App: download GrostatBar-{{VERSION}}-arm64-macos.zip from releases"
