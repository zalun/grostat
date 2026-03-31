# Release Process

## 1. Tag a new version

```bash
# Update version in src/grostat/__init__.py and pyproject.toml
git tag v0.1.0
git push origin v0.1.0
```

## 2. Create GitHub release

```bash
gh release create v0.1.0 --generate-notes
```

## 3. Update Homebrew formula

```bash
# Get the SHA256 of the release tarball
curl -sL https://github.com/zalun/grostat/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256

# Update homebrew-grostat repo:
# 1. Change `url` to point to new tag
# 2. Update `sha256` with the new hash
# 3. Commit and push to zalun/homebrew-grostat
```

## 4. Verify

```bash
brew update
brew upgrade grostat
grostat --help
```

## Homebrew tap setup (first time only)

Create repo `zalun/homebrew-grostat` on GitHub with:

```
Formula/
  grostat.rb    # copy from homebrew/grostat.rb with correct SHA
```

Users install with:

```bash
brew tap zalun/grostat
brew install grostat
```
