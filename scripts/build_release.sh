#!/usr/bin/env bash
# Build, sign, notarize, package, and optionally publish StayTab.
set -euo pipefail

TEAM_ID="${TEAM_ID:-GGR9HG6DB8}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: DongHyeon Kang (${TEAM_ID})}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-StayTabNotarization}"
RELEASE_REPO="${RELEASE_REPO:-kang1027/StayTab}"
SCHEME="BetterCmdTab"
APP_NAME="StayTab"
BUNDLE_ID="com.kdh.StayTab"

is_beta=0
skip_notarization=0
skip_build=0
clean_build=0
auto_release=0
notes_file=""
requested_build_number=""

usage() {
	cat <<'EOF'
Usage: scripts/build_release.sh [OPTIONS]

Options:
  --stable                 Build a stable release (default).
  --beta                   Build the next beta for the current version.
  --skip-notarization      Build an unnotarized local test package. Never publish it.
  --skip-build             Reuse the package recorded in build/release/latest.env.
  --build-number NUMBER    Override the timestamp build number.
  --clean                  Remove only build/release before building.
  --auto-release           Publish the verified package as a GitHub Release.
  --notes-file PATH        Markdown release notes for --auto-release.
  -h, --help               Show this help.

Environment:
  TEAM_ID                   Apple Developer team (default: GGR9HG6DB8).
  SIGNING_IDENTITY          Developer ID Application identity.
  NOTARYTOOL_PROFILE        notarytool Keychain profile.
  RELEASE_REPO              GitHub owner/repository (default: kang1027/StayTab).
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--stable) is_beta=0 ;;
	--beta) is_beta=1 ;;
	--skip-notarization) skip_notarization=1 ;;
	--skip-build) skip_build=1 ;;
	--clean) clean_build=1 ;;
	--auto-release) auto_release=1 ;;
	--notes-file)
		shift
		[[ $# -gt 0 ]] || { echo "--notes-file requires a path" >&2; exit 64; }
		notes_file="$1"
		;;
	--build-number)
		shift
		[[ $# -gt 0 ]] || { echo "--build-number requires a value" >&2; exit 64; }
		requested_build_number="$1"
		;;
	-h | --help) usage; exit 0 ;;
	*) echo "Unknown option: $1" >&2; usage; exit 64 ;;
	esac
	shift
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${REPO_ROOT}/BetterCmdTab.xcodeproj"
BUILD_DIR="${REPO_ROOT}/build/release"
ARCHIVE_PATH="${BUILD_DIR}/StayTab.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_STAGE_DIR="${BUILD_DIR}/dmg-stage"
METADATA_PATH="${BUILD_DIR}/latest.env"

step() {
	printf '\n==> %s\n' "$1"
}

setting() {
	xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -showBuildSettings 2>/dev/null |
		awk -v key="$1" '$1 == key { print $3; exit }'
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || { echo "Required command not found: $1" >&2; exit 1; }
}

metadata_value() {
	awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$METADATA_PATH"
}

require_command xcodebuild
require_command codesign
require_command ditto
require_command hdiutil
require_command shasum

VERSION="$(setting MARKETING_VERSION)"
[[ -n "$VERSION" ]] || { echo "Could not read MARKETING_VERSION" >&2; exit 1; }

if [[ $skip_build -eq 1 ]]; then
	[[ -f "$METADATA_PATH" ]] || { echo "No reusable package metadata at ${METADATA_PATH}" >&2; exit 1; }
	META_VERSION="$(metadata_value VERSION)"
	[[ "$META_VERSION" == "$VERSION" ]] || {
		echo "Reusable package is ${META_VERSION}, project is ${VERSION}" >&2
		exit 1
	}
	BUILD_NUMBER="$(metadata_value BUILD_NUMBER)"
	TAG="$(metadata_value TAG)"
	DMG_PATH="$(metadata_value DMG_PATH)"
	ZIP_PATH="$(metadata_value ZIP_PATH)"
	[[ -f "$DMG_PATH" && -f "$ZIP_PATH" ]] || { echo "Recorded release assets are missing" >&2; exit 1; }
	ARTIFACT_VERSION="$(metadata_value ARTIFACT_VERSION)"
else
	if [[ -n "$requested_build_number" ]]; then
		[[ "$requested_build_number" =~ ^[0-9]+$ ]] || { echo "Build number must be numeric" >&2; exit 64; }
		BUILD_NUMBER="$requested_build_number"
	else
		BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"
	fi

	if [[ $is_beta -eq 1 ]]; then
		require_command gh
		last_beta="$(gh release list --repo "$RELEASE_REPO" --limit 100 --json tagName --jq ".[].tagName | select(startswith(\"v${VERSION}-beta.\"))" 2>/dev/null | sort -V | tail -1 || true)"
		if [[ -z "$last_beta" ]]; then
			beta_number=1
		else
			beta_number="$(( ${last_beta##*.} + 1 ))"
		fi
		ARTIFACT_VERSION="${VERSION}-beta.${beta_number}"
		TAG="v${ARTIFACT_VERSION}"
	else
		ARTIFACT_VERSION="$VERSION"
		TAG="v${VERSION}"
	fi

	DMG_PATH="${BUILD_DIR}/StayTab-${ARTIFACT_VERSION}-${BUILD_NUMBER}.dmg"
	ZIP_PATH="${BUILD_DIR}/StayTab-${ARTIFACT_VERSION}-${BUILD_NUMBER}.zip"
fi

if [[ $auto_release -eq 1 && $skip_notarization -eq 1 ]]; then
	echo "Refusing to publish an unnotarized build" >&2
	exit 1
fi

if [[ -n "$notes_file" ]]; then
	notes_file="$(cd "$(dirname "$notes_file")" && pwd)/$(basename "$notes_file")"
	[[ -s "$notes_file" ]] || { echo "Release notes are missing or empty: $notes_file" >&2; exit 1; }
fi

if [[ $skip_build -eq 0 ]]; then
	if [[ $clean_build -eq 1 && -d "$BUILD_DIR" ]]; then
		step "Clean release workspace"
		find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
	fi
	mkdir -p "$BUILD_DIR"

	step "Release quality gate"
	gate_args=(--fail-on-high-risk-warnings --log-path "${BUILD_DIR}/quality-gate.log")
	[[ $clean_build -eq 1 ]] && gate_args+=(--clean)
	[[ $is_beta -eq 1 ]] && gate_args+=(--skip-i18n)
	"${REPO_ROOT}/scripts/release_quality_gate.sh" "${gate_args[@]}"

	step "Verify signing and notarization setup"
	security find-identity -v -p codesigning | grep -Fq "$SIGNING_IDENTITY" || {
		echo "Signing identity not found: ${SIGNING_IDENTITY}" >&2
		exit 1
	}
	if [[ $skip_notarization -eq 0 ]]; then
		xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" >/dev/null || {
			echo "notarytool profile is unavailable: ${NOTARYTOOL_PROFILE}" >&2
			exit 1
		}
	fi

	step "Archive StayTab ${ARTIFACT_VERSION} (${BUILD_NUMBER})"
	if [[ -d "$ARCHIVE_PATH" ]]; then
		find "$ARCHIVE_PATH" -mindepth 1 -delete
		rmdir "$ARCHIVE_PATH"
	fi
	xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "$SCHEME" \
		-configuration Release \
		-archivePath "$ARCHIVE_PATH" \
		-destination "generic/platform=macOS" \
		DEVELOPMENT_TEAM="$TEAM_ID" \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
		CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
		OTHER_CODE_SIGN_FLAGS="--timestamp" \
		archive

	ARCHIVED_APP="${ARCHIVE_PATH}/Products/Applications/StayTab.app"
	[[ -d "$ARCHIVED_APP" ]] || { echo "Archive does not contain StayTab.app" >&2; exit 1; }
	if [[ -d "$EXPORT_PATH" ]]; then
		find "$EXPORT_PATH" -mindepth 1 -delete
	else
		mkdir -p "$EXPORT_PATH"
	fi
	APP_PATH="${EXPORT_PATH}/StayTab.app"
	ditto "$ARCHIVED_APP" "$APP_PATH"

	step "Verify app signature and GPL resources"
	codesign --verify --deep --strict --verbose=2 "$APP_PATH"
	signature_info="$(codesign -dvv "$APP_PATH" 2>&1 || true)"
	grep -Fq "TeamIdentifier=${TEAM_ID}" <<<"$signature_info" || { echo "Unexpected signing team" >&2; exit 1; }
	grep -Fq "Identifier=${BUNDLE_ID}" <<<"$signature_info" || { echo "Unexpected bundle identifier" >&2; exit 1; }
	[[ -f "${APP_PATH}/Contents/Resources/LICENSE" ]] || { echo "LICENSE is missing from app resources" >&2; exit 1; }
	[[ -f "${APP_PATH}/Contents/Resources/NOTICE.md" ]] || { echo "NOTICE.md is missing from app resources" >&2; exit 1; }

	NOTARY_ZIP="${BUILD_DIR}/StayTab-${ARTIFACT_VERSION}-notary.zip"
	if [[ $skip_notarization -eq 0 ]]; then
		step "Notarize and staple app"
		rm -f "$NOTARY_ZIP"
		ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
		xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait |
			tee "${BUILD_DIR}/notarization-app.log"
		grep -Fq "status: Accepted" "${BUILD_DIR}/notarization-app.log" || { echo "App notarization failed" >&2; exit 1; }
		xcrun stapler staple "$APP_PATH"
		xcrun stapler validate "$APP_PATH"
	fi

	step "Create ZIP and DMG"
	rm -f "$ZIP_PATH" "$DMG_PATH"
	ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
	if [[ -d "$DMG_STAGE_DIR" ]]; then
		find "$DMG_STAGE_DIR" -mindepth 1 -delete
	else
		mkdir -p "$DMG_STAGE_DIR"
	fi
	ditto "$APP_PATH" "${DMG_STAGE_DIR}/StayTab.app"
	ditto "${REPO_ROOT}/LICENSE" "${DMG_STAGE_DIR}/LICENSE.txt"
	ditto "${REPO_ROOT}/NOTICE.md" "${DMG_STAGE_DIR}/NOTICE.md"
	ln -s /Applications "${DMG_STAGE_DIR}/Applications"
	hdiutil create \
		-volname "StayTab ${ARTIFACT_VERSION}" \
		-srcfolder "$DMG_STAGE_DIR" \
		-ov -format UDZO -fs HFS+ "$DMG_PATH" >/dev/null
	codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
	codesign --verify --verbose=2 "$DMG_PATH"

	if [[ $skip_notarization -eq 0 ]]; then
		step "Notarize and staple DMG"
		xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait |
			tee "${BUILD_DIR}/notarization-dmg.log"
		grep -Fq "status: Accepted" "${BUILD_DIR}/notarization-dmg.log" || { echo "DMG notarization failed" >&2; exit 1; }
		xcrun stapler staple "$DMG_PATH"
		xcrun stapler validate "$DMG_PATH"
	fi

	rm -f "$NOTARY_ZIP"
	printf 'VERSION=%s\nBUILD_NUMBER=%s\nARTIFACT_VERSION=%s\nTAG=%s\nDMG_PATH=%s\nZIP_PATH=%s\n' \
		"$VERSION" "$BUILD_NUMBER" "$ARTIFACT_VERSION" "$TAG" "$DMG_PATH" "$ZIP_PATH" >"$METADATA_PATH"
fi

step "Verify packaged assets"
shasum -a 256 "$DMG_PATH" "$ZIP_PATH"
if [[ $skip_notarization -eq 0 ]]; then
	xcrun stapler validate "$DMG_PATH"
	spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
fi

if [[ $auto_release -eq 1 ]]; then
	step "Publish ${TAG} to ${RELEASE_REPO}"
	require_command gh
	[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] || { echo "Working tree must be clean" >&2; exit 1; }
	HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
	REMOTE_SHA="$(git -C "$REPO_ROOT" ls-remote origin refs/heads/main | awk '{print $1}')"
	[[ "$HEAD_SHA" == "$REMOTE_SHA" ]] || {
		echo "HEAD is not the commit published at origin/main" >&2
		exit 1
	}
	if gh release view "$TAG" --repo "$RELEASE_REPO" >/dev/null 2>&1; then
		echo "Release already exists: ${TAG}" >&2
		exit 1
	fi
	if [[ -z "$notes_file" ]]; then
		notes_file="${BUILD_DIR}/release-notes-${TAG}.md"
		cat >"$notes_file" <<EOF
## Highlights

StayTab ${ARTIFACT_VERSION} 릴리스입니다.

### License and attribution

StayTab은 BetterCmdTab을 기반으로 하며 GPL-3.0으로 배포됩니다.
EOF
	fi
	release_flags=(--latest)
	[[ $is_beta -eq 1 ]] && release_flags=(--prerelease --latest=false)
	gh release create "$TAG" \
		--repo "$RELEASE_REPO" \
		--target "$HEAD_SHA" \
		--title "StayTab ${ARTIFACT_VERSION}" \
		--notes-file "$notes_file" \
		"${release_flags[@]}" \
		"${DMG_PATH}#$(basename "$DMG_PATH")" \
		"${ZIP_PATH}#$(basename "$ZIP_PATH")"
	printf 'Published: https://github.com/%s/releases/tag/%s\n' "$RELEASE_REPO" "$TAG"
fi

printf '\nStayTab package ready\n'
printf '  Version: %s (%s)\n' "$ARTIFACT_VERSION" "$BUILD_NUMBER"
printf '  DMG: %s\n' "$DMG_PATH"
printf '  ZIP: %s\n' "$ZIP_PATH"
if [[ $skip_notarization -eq 1 ]]; then
	printf '  Warning: local test package only; do not distribute.\n'
elif [[ $auto_release -eq 0 ]]; then
	printf '  Publish after manual verification with:\n'
	printf '    scripts/build_release.sh --skip-build --auto-release --notes-file notes.md\n'
fi
