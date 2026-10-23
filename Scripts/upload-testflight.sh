#!/bin/bash

set -eo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_directory/.." && pwd)"
export_options="$script_directory/TestFlightExportOptions.plist"
mode=""
requested_build_number=""
requested_marketing_version=""

usage() {
    cat <<'EOF'
Usage: Scripts/upload-testflight.sh --dry-run [--build-number NUMBER] [--marketing-version VERSION]
       Scripts/upload-testflight.sh --upload [--build-number NUMBER] [--marketing-version VERSION]

--dry-run archives and exports locally without uploading.
--upload exports directly to App Store Connect and requires explicit approval.
EOF
}

while (($#)); do
    case "$1" in
        --dry-run|--upload)
            if [[ -n "$mode" ]]; then
                echo "Choose exactly one of --dry-run or --upload." >&2
                exit 2
            fi
            mode="$1"
            shift
            ;;
        --build-number)
            (($# >= 2)) || { echo "--build-number requires a value." >&2; exit 2; }
            requested_build_number="$2"
            shift 2
            ;;
        --marketing-version)
            (($# >= 2)) || { echo "--marketing-version requires a value." >&2; exit 2; }
            requested_marketing_version="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$mode" ]]; then
    usage >&2
    exit 2
fi

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    echo "Set ASC_KEY_ID and ASC_ISSUER_ID by sourcing ~/.appstoreconnect/passata.env." >&2
    exit 1
fi
api_key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
if [[ ! -f "$api_key_path" ]]; then
    echo "The App Store Connect API key file is not present at the configured location." >&2
    exit 1
fi

if [[ -n "$requested_build_number" ]]; then
    [[ "$requested_build_number" =~ ^[0-9]+$ ]] || { echo "Build number must be a positive integer." >&2; exit 2; }
    build_number="$requested_build_number"
else
    current_build_number="$(xcodebuild -project "$repository_root/Passata.xcodeproj" -scheme Passata -configuration Release -sdk iphoneos -showBuildSettings 2>/dev/null | awk -F ' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }')"
    [[ "$current_build_number" =~ ^[0-9]+$ ]] || { echo "Could not determine CURRENT_PROJECT_VERSION from Xcode build settings." >&2; exit 1; }
    build_number="$((current_build_number + 1))"
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/passata-testflight.XXXXXX")"
archive_path="$temporary_directory/Passata.xcarchive"
export_path="$temporary_directory/export"
mkdir -p "$export_path"

cleanup() {
    rm -rf "$temporary_directory"
}
trap cleanup EXIT

run_xcodebuild() {
    local log_path="$1"
    shift
    if xcodebuild "$@" >"$log_path" 2>&1; then
        sed -e "s/${ASC_KEY_ID}/[REDACTED]/g" -e "s/${ASC_ISSUER_ID}/[REDACTED]/g" "$log_path"
    else
        local result=$?
        sed -e "s/${ASC_KEY_ID}/[REDACTED]/g" -e "s/${ASC_ISSUER_ID}/[REDACTED]/g" "$log_path" >&2
        return "$result"
    fi
}

echo "Archiving Passata at build $build_number."
if [[ -n "$requested_marketing_version" ]]; then
    run_xcodebuild "$temporary_directory/archive.log" \
        -project "$repository_root/Passata.xcodeproj" \
        -scheme Passata \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$archive_path" \
        -derivedDataPath "$temporary_directory/DerivedData" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$api_key_path" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        CURRENT_PROJECT_VERSION="$build_number" \
        MARKETING_VERSION="$requested_marketing_version" \
        archive
else
    run_xcodebuild "$temporary_directory/archive.log" \
        -project "$repository_root/Passata.xcodeproj" \
        -scheme Passata \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$archive_path" \
        -derivedDataPath "$temporary_directory/DerivedData" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$api_key_path" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
        CURRENT_PROJECT_VERSION="$build_number" \
        archive
fi

app_info="$archive_path/Products/Applications/Passata.app/Info.plist"
widget_info="$archive_path/Products/Applications/Passata.app/PlugIns/PassataWidgetExtension.appex/Info.plist"
[[ -f "$app_info" ]] || { echo "Archived app Info.plist was not found." >&2; exit 1; }
[[ -f "$widget_info" ]] || { echo "Archived widget extension Info.plist was not found." >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$app_info")" == "false" ]] || {
    echo "Archived app does not declare ITSAppUsesNonExemptEncryption as NO." >&2
    exit 1
}
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$widget_info")" == "Passata" ]] || {
    echo "Archived widget extension does not declare CFBundleDisplayName as Passata." >&2
    exit 1
}

if [[ "$mode" == "--dry-run" ]]; then
    run_xcodebuild "$temporary_directory/export.log" \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options"
    actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_info")"
    echo "Dry run succeeded: version ${requested_marketing_version:-$actual_version}, build $build_number. No upload was performed."
else
    upload_options="$temporary_directory/UploadExportOptions.plist"
    cp "$export_options" "$upload_options"
    /usr/libexec/PlistBuddy -c 'Set :destination upload' "$upload_options"
    export_log="$temporary_directory/export-upload.log"
    if xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportOptionsPlist "$upload_options" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$api_key_path" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID" >"$export_log" 2>&1; then
        sed -e "s/${ASC_KEY_ID}/[REDACTED]/g" -e "s/${ASC_ISSUER_ID}/[REDACTED]/g" "$export_log"
        actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_info")"
        echo "Upload submitted: version ${requested_marketing_version:-$actual_version}, build $build_number."
    else
        result=$?
        sed -e "s/${ASC_KEY_ID}/[REDACTED]/g" -e "s/${ASC_ISSUER_ID}/[REDACTED]/g" "$export_log" >&2
        exit "$result"
    fi
fi
