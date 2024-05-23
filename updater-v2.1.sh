#!/bin/bash

ROOT_APPS_FOLDER="$HOME/Apps"

function notify() {
    notify-send -a "Application Updater" "$@"
    shift
    echo "$@"
}

function notify_die() {
    EXIT_CODE=$1
    shift
    notify "$@"
    exit "$EXIT_CODE"
}

function github_fetch() {
    return "$(curl -s -H "Accept: application/vnd.github+json" -G -d 'per_page=1' "https://api.github.com/repos/$1/releases")"
}

function filter_fetched() {
    TYPE="$1"
    shift
    jq -r ".[].assets[] | select(.browser_download_url | test(\"$TYPE\")) | .browser_download_url"
}

function check_modification_time() {
    local file_path="$1"
    local local_modification_time
    local remote_modification_time

    local_modification_time=$(stat -c %Y "$file_path")
    remote_modification_time=$(curl -sI "${url[0]}" | awk '/^Last-Modified:/ {print $2 " " $3 " " $4}')

    # Compare modification times
    if [[ $local_modification_time -lt $(date -d "$remote_modification_time" +%s) ]]; then
        echo "true"  # Remote file is newer
    else
        echo "false"  # Local file is newer or same
    fi
}

function download_notify() {
    APP_FOLDER=$ROOT_APPS_FOLDER
    APP_NAME=$1
    local url
    local FETCHED_FILE
    local EXTENSION
    local REPO
    local TYPE

    case $APP_NAME in
        Ryujinx)
            EXTENSION="tar.gz"
            TYPE="linux_x64"
            REPO="Ryujinx/release-channel-master"
            ;;
        Cemu)
            EXTENSION="AppImage"
            TYPE="$EXTENSION"
            REPO="cemu-project/Cemu"
            ;;
        Panda3DS)
            EXTENSION="zip"
            url="https://nightly.link/wheremyfoodat/Panda3DS/workflows/Qt_Build/master/Linux%20executable.zip"
            ;;
        DolphinDev)
            EXTENSION="AppImage"
            TYPE="$EXTENSION"
            REPO="qurious-pixel/dolphin"
            ;;
        RMG)
            EXTENSION="AppImage"
            TYPE="$EXTENSION"
            REPO="Rosalie241/RMG"
            ;;
        melonDS)
            EXTENSION="zip"
            TYPE="linux_x64"
            REPO="melonDS-emu/melonDS"
            ;;
        SkyEmu)
            EXTENSION="zip"
            TYPE="Linux"
            REPO="skylersaleh/SkyEmu"
            ;;
        mGBAdev)
            EXTENSION="AppImage"
            url="https://s3.amazonaws.com/mgba/mGBA-build-latest-appimage-x64.appimage"
            ;;
        Sudachi)
            EXTENSION="7z"
            TYPE="linux"
            REPO="sudachi-emu/sudachi"
            ;;
        Lime3DS)
            EXTENSION="tar.gz"
            TYPE="appimage"
            REPO="Lime3DS/Lime3DS"
            ;;
        citraPMK)
            EXTENSION="7z"
            TYPE="appimage"
            REPO="PabloMK7/citra"
            ;;
        Citra-Enhanced)
            EXTENSION="zip"
            TYPE="appimage"
            REPO="Gamer64ytb/Citra-Enhanced"
            ;;
    esac

    mapfile -t url < <(github_fetch $REPO | filter_fetched $TYPE)

    FETCHED_FILE="$APP_NAME.$EXTENSION"

    notify "Checking for updates for $APP_NAME..."

    local download_required=false

    # Check if the file exists and if it's older than the remote file
    if [[ ! -f "$APP_FOLDER/$FETCHED_FILE" || $(check_modification_time "$APP_FOLDER/$FETCHED_FILE") == "true" ]]; then
        download_required=true
    fi

    if [[ "$download_required" == true ]]; then
        notify "Updating $APP_NAME..."
        curl -s -L -o "$APP_FOLDER/$FETCHED_FILE" "${url[0]}" || notify_die 1 "Update failed: $APP_NAME"

        notify "Update successful: $APP_NAME"
        case $APP_NAME in
            Ryujinx)
                tar xf "$APP_FOLDER/$FETCHED_FILE" -C "$APP_FOLDER/"
                chmod +x "$APP_FOLDER/publish/Ryujinx" "$APP_FOLDER/publish/Ryujinx.sh" "$APP_FOLDER/publish/Ryujinx.SDL2.Common.dll.config" "$APP_FOLDER/publish/mime/Ryujinx.xml"
                ;;
            Cemu | DolphinDev | RMG | mGBAdev)
                chmod +x "$APP_FOLDER/$FETCHED_FILE"
                ;;
            Panda3DS | melonDS | SkyEmu)
                7z x "$APP_FOLDER/$FETCHED_FILE" -y
                mv -f "$APP_FOLDER/Alber-x86_64.AppImage" "$APP_FOLDER/Panda3DS.AppImage"
                chmod +x "$APP_FOLDER/$FETCHED_FILE"
                ;;
            Sudachi | citraPMK)
                7z x "$APP_FOLDER/$FETCHED_FILE" -o* -y
                chmod +x "$APP_FOLDER/Sudachi/sudachi" "$APP_FOLDER/Sudachi/sudachi-cmd" "$APP_FOLDER/citraPMK/head/citra.AppImage" "$APP_FOLDER/citraPMK/head/citra-qt.AppImage" "$APP_FOLDER/citraPMK/head/citra-room.AppImage"
                xdg-open https://github.com/litucks/torzu/releases
                ;;
            Lime3DS)
                mkdir -p "$APP_FOLDER/Lime3DS"
                tar xf "$APP_FOLDER/$FETCHED_FILE" -C "$APP_FOLDER/Lime3DS" --strip-components=1
                chmod +x "$APP_FOLDER/Lime3DS/lime3ds-cli.AppImage" "$APP_FOLDER/Lime3DS/lime3ds-gui.AppImage" "$APP_FOLDER/Lime3DS/lime3ds-room.AppImage"
                ;;
            Citra-Enhanced)
                7z x "$APP_FOLDER/$FETCHED_FILE" citra*7z -y
                mv -f "$APP_FOLDER"/citra*7z "$APP_FOLDER"/Citra-Enhanced.7z
                7z x "$APP_FOLDER/Citra-Enhanced.7z" -o* -y
                chmod +x "$APP_FOLDER/Citra-Enhanced/head/citra.AppImage" "$APP_FOLDER/Citra-Enhanced/head/citra-qt.AppImage" "$APP_FOLDER/Citra-Enhanced/head/citra-room.AppImage"
                ;;
        esac
    else
        notify "$APP_NAME is already up to date."
    fi
}

# Flatpak
# ------------
notify "Flatpak updating"
flatpak update -y --noninteractive | sed -e '/Info\:/d' -e '/^$/d'

# Update applications
# -------------------
mkdir -p "$ROOT_APPS_FOLDER"
pushd "$ROOT_APPS_FOLDER" || exit
for APP in Ryujinx Cemu Panda3DS DolphinDev RMG melonDS SkyEmu mGBAdev Sudachi Lime3DS citraPMK Citra-Enhanced; do
    download_notify "$APP"
done
popd || exit