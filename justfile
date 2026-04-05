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

# Build GrostatBar.app
build-app:
    cd GrostatBar && swift build -c release && bash bundle.sh .build/release/GrostatBar

# Build CLI + app and install locally
install: release build-app
    cp .build/release/grostat ~/.local/bin/grostat
    -pkill -x GrostatBar 2>/dev/null; sleep 1
    rm -rf /Applications/GrostatBar.app
    cp -r GrostatBar/GrostatBar.app /Applications/GrostatBar.app
    open /Applications/GrostatBar.app
    @echo "Installed grostat to ~/.local/bin/ and GrostatBar.app to /Applications/"

# Restart GrostatBar client
restart-client:
    -pkill -x GrostatBar 2>/dev/null; sleep 1
    open /Applications/GrostatBar.app

# Build everything and create release tarball (CLI + app)
tarball VERSION: release build-app
    #!/usr/bin/env bash
    set -euo pipefail
    STAGING=$(mktemp -d)
    cp .build/release/grostat "$STAGING/"
    cp -r GrostatBar/GrostatBar.app "$STAGING/"
    cd "$STAGING" && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat GrostatBar.app
    rm -rf "$STAGING"
    shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz

homebrew_repo := justfile_directory() / "../homebrew-grostat"

# Full release: tag, push, gh release, upload binary+app, update homebrew
publish VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Tagging v{{VERSION}}"
    git tag v{{VERSION}}
    git push origin v{{VERSION}}
    echo "==> Creating GitHub release"
    gh release create v{{VERSION}} --title "v{{VERSION}}" --generate-notes
    ROOT="$(pwd)"
    echo "==> Building CLI"
    swift build -c release
    echo "==> Building GrostatBar.app"
    (cd GrostatBar && swift build -c release && bash bundle.sh .build/release/GrostatBar)
    echo "==> Creating tarball (CLI + app)"
    STAGING=$(mktemp -d)
    cp "$ROOT/.build/release/grostat" "$STAGING/"
    cp -r "$ROOT/GrostatBar/GrostatBar.app" "$STAGING/"
    (cd "$STAGING" && tar czf /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz grostat GrostatBar.app)
    rm -rf "$STAGING"
    echo "==> Uploading to release"
    gh release upload v{{VERSION}} /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz
    SHA=$(shasum -a 256 /tmp/grostat-{{VERSION}}-arm64-macos.tar.gz | awk '{print $1}')
    echo "==> Updating homebrew formula (SHA: $SHA)"
    BREW="{{homebrew_repo}}"
    sed -i '' "s|url \".*\"|url \"https://github.com/zalun/grostat/releases/download/v{{VERSION}}/grostat-{{VERSION}}-arm64-macos.tar.gz\"|" "$BREW/Formula/grostat.rb"
    sed -i '' "s|sha256 \".*\"|sha256 \"$SHA\"|" "$BREW/Formula/grostat.rb"
    sed -i '' "s|version \".*\"|version \"{{VERSION}}\"|" "$BREW/Formula/grostat.rb"
    (cd "$BREW" && git add Formula/grostat.rb && git commit -m "Update formula to v{{VERSION}}" && git push origin main)
    echo "==> Done! Run 'brew update && brew upgrade grostat' to install."
