#!/bin/bash

# ============================================================================
# 🚀 Firebase App Distribution - Android Build & Upload Script
# ============================================================================
# Builds Android APK/AAB with Flutter flavors and uploads to Firebase
#
# Usage:
#   ./build_and_distribute_android.sh [flavor] [build_type] [version] [app_package_name] [release_notes]
#
# Examples:
#   ./build_and_distribute_android.sh development apk com.example.app
#   ./build_and_distribute_android.sh production aab com.example.app "Bug fixes"
#   ./build_and_distribute_android.sh production apk com.example.app "New features"
#
# Arguments:
#   flavor        : development | production (default: development)
#   build_type    : apk | aab (default: apk)
#   app_package_name : Application package name
#   release_notes : Release notes (default: auto-generated)
# ============================================================================

set -e

# ============================================================================
# 🎨 Colors & Icons
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Icons
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_ROCKET="🚀"
ICON_PACKAGE="📦"
ICON_UPLOAD="☁️"
ICON_BUILD="🔨"
ICON_CLEAN="🧹"
ICON_CHECK="✓"
ICON_FIRE="🔥"
ICON_TIME="⏱️"
ICON_SIZE="💾"

# ============================================================================
# ⚙️ Configuration
# ============================================================================
FLAVOR="${1:-development}"
BUILD_TYPE="${2:-apk}"
APP_PACKAGE_NAME="${3:-}"
RELEASE_NOTES="${4:-}"

# Firebase Configuration - Will be read from google-services.json
FIREBASE_ANDROID_APP_ID=""
TESTER_GROUP="testers"

# Paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$PROJECT_ROOT/android"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
GOOGLE_SERVICES_FILE="$ANDROID_DIR/app/google-services.json"

# Build artifacts
BUILD_OUTPUT=""
VERSION_NAME=""
VERSION_CODE=""
BUILD_START_TIME=$(date +%s)

# ============================================================================
# 🎭 Animation Functions
# ============================================================================

spinner() {
	local pid=$1
	local message=$2
	local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
	local temp

	while kill -0 "$pid" 2>/dev/null; do
		temp=${spinstr#?}
		printf "\r${CYAN}%s${NC} %s" "${spinstr:0:1}" "$message"
		spinstr=$temp${spinstr:0:1}
		sleep 0.1
	done
	printf "\r"
}

progress_bar() {
	local current=$1
	local total=$2
	local width=50
	local percentage=$((current * 100 / total))
	local completed=$((width * current / total))
	local remaining=$((width - completed))

	printf "\r${BLUE}["
	printf "%${completed}s" | tr ' ' '█'
	printf "%${remaining}s" | tr ' ' '░'
	printf "]${NC} ${WHITE}%3d%%${NC}" "$percentage"
}

print_banner() {
	clear
	echo -e "${PURPLE}"
	echo "╔════════════════════════════════════════════════════════════════╗"
	echo "║                                                                ║"
	echo "║        🚀  Firebase App Distribution Build Script  🚀          ║"
	echo "║                                                                ║"
	echo "║                     Android APK/AAB Builder                    ║"
	echo "║                                                                ║"
	echo "╚════════════════════════════════════════════════════════════════╝"
	echo -e "${NC}\n"
}

print_section() {
	echo ""
	echo -e "${CYAN}╭─────────────────────────────────────────────────────────────╮${NC}"
	echo -e "${CYAN}│${NC} ${WHITE}$1${NC}"
	echo -e "${CYAN}╰─────────────────────────────────────────────────────────────╯${NC}"
	echo ""
}

print_success() {
	echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"
}

print_error() {
	echo -e "${RED}${ICON_ERROR} $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}${ICON_WARNING} $1${NC}"
}

print_info() {
	echo -e "${BLUE}${ICON_INFO} $1${NC}"
}

print_step() {
	echo -e "${PURPLE}${ICON_ROCKET} $1${NC}"
}

print_detail() {
	echo -e "${GRAY}  └─ $1${NC}"
}

# ============================================================================
# 🔥 Firebase Configuration
# ============================================================================

read_firebase_config() {
	print_step "Reading Firebase configuration from google-services.json..."

	if [[ ! -f "$GOOGLE_SERVICES_FILE" ]]; then
		print_error "google-services.json not found!"
		echo -e "${GRAY}  Expected location: android/app/google-services.json${NC}"
		echo -e "${GRAY}  Download it from Firebase Console > Project Settings > Your Apps${NC}"
		exit 1
	fi

	# Extract mobilesdk_app_id for the specific package name
	# Parse JSON to find the client with matching package_name
	print_detail "Looking for package: $APP_PACKAGE_NAME"

	# Use Python for reliable JSON parsing
	FIREBASE_ANDROID_APP_ID=$(python3 -c "
import json
import sys

try:
    with open('$GOOGLE_SERVICES_FILE', 'r') as f:
        data = json.load(f)
    
    package_name = '$APP_PACKAGE_NAME'
    
    # Search through client array for matching package
    for client in data.get('client', []):
        client_info = client.get('client_info', {})
        android_info = client_info.get('android_client_info', {})
        
        if android_info.get('package_name') == package_name:
            app_id = client_info.get('mobilesdk_app_id', '')
            if app_id:
                print(app_id)
                sys.exit(0)
    
    # If no match found, exit with error
    sys.exit(1)
    
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

	if [[ -z "$FIREBASE_ANDROID_APP_ID" ]]; then
		print_error "Failed to find Firebase App ID for package: $APP_PACKAGE_NAME"
		echo -e "${GRAY}  Make sure google-services.json contains an app with this package name${NC}"
		echo -e "${GRAY}  Available packages in google-services.json:${NC}"

		# List available packages to help debug
		python3 -c "
import json
try:
    with open('$GOOGLE_SERVICES_FILE', 'r') as f:
        data = json.load(f)
    for client in data.get('client', []):
        pkg = client.get('client_info', {}).get('android_client_info', {}).get('package_name', 'N/A')
        print(f'    - {pkg}')
except:
    pass
" 2>/dev/null

		exit 1
	fi

	print_success "Firebase App ID found for package"
	print_detail "Package: $APP_PACKAGE_NAME"
	print_detail "App ID: ${FIREBASE_ANDROID_APP_ID:0:40}..."
}

# ============================================================================
# 📖 Version Management
# ============================================================================

read_version_from_pubspec() {
	print_step "Reading version from pubspec.yaml..."

	if [[ ! -f "$PUBSPEC_FILE" ]]; then
		print_error "pubspec.yaml not found!"
		exit 1
	fi

	# Read version line (format: version: 1.0.0+1)
	local version_line=$(grep "^version:" "$PUBSPEC_FILE" | head -n 1)

	if [[ -z "$version_line" ]]; then
		print_error "Version not found in pubspec.yaml!"
		exit 1
	fi

	# Extract version (e.g., "1.0.0+1")
	local full_version=$(echo "$version_line" | sed 's/version: *//' | tr -d ' ')

	# Split version name and code
	VERSION_NAME=$(echo "$full_version" | cut -d'+' -f1)
	VERSION_CODE=$(echo "$full_version" | cut -d'+' -f2)

	# If no version code, use timestamp
	if [[ -z "$VERSION_CODE" ]] || [[ "$VERSION_CODE" == "$VERSION_NAME" ]]; then
		VERSION_CODE=$(date +%s)
	fi

	print_success "Version: $VERSION_NAME ($VERSION_CODE)"
	print_detail "Name: $VERSION_NAME"
	print_detail "Code: $VERSION_CODE"
}

set_custom_version() {
	local custom_version=$1

	print_step "Setting custom version: $custom_version"

	# Parse custom version (format: 1.0.0 or 1.0.0+123)
	if [[ "$custom_version" == *"+"* ]]; then
		VERSION_NAME=$(echo "$custom_version" | cut -d'+' -f1)
		VERSION_CODE=$(echo "$custom_version" | cut -d'+' -f2)
	else
		VERSION_NAME="$custom_version"
		VERSION_CODE=$(date +%s)
	fi

	print_success "Custom version set"
	print_detail "Name: $VERSION_NAME"
	print_detail "Code: $VERSION_CODE"
}

# ============================================================================
# ✅ Validation
# ============================================================================

validate_environment() {
	print_section "${ICON_CHECK} Environment Validation"

	if command -v flutter &>/dev/null; then
		local flutter_version=$(flutter --version | head -n 1)
		print_success "Flutter: $flutter_version"
	else
		print_error "Flutter not found!"
		echo -e "${GRAY}  Install: https://flutter.dev/docs/get-started/install${NC}"
		exit 1
	fi

	if command -v firebase &>/dev/null; then
		local firebase_version=$(firebase --version)
		print_success "Firebase CLI: $firebase_version"
	else
		print_error "Firebase CLI not found!"
		echo -e "${GRAY}  Install: npm install -g firebase-tools${NC}"
		exit 1
	fi

	if [[ -f "$PUBSPEC_FILE" ]]; then
		print_success "pubspec.yaml found"
	else
		print_error "pubspec.yaml not found!"
		exit 1
	fi

	if [[ -d "$ANDROID_DIR" ]]; then
		print_success "Android directory found"
	else
		print_error "Android directory not found!"
		exit 1
	fi

	# Check for google-services.json
	if [[ -f "$GOOGLE_SERVICES_FILE" ]]; then
		print_success "google-services.json found"
	else
		print_error "google-services.json not found!"
		echo -e "${GRAY}  Location: android/app/google-services.json${NC}"
		echo -e "${GRAY}  Download from Firebase Console${NC}"
		exit 1
	fi
}

validate_parameters() {
	print_section "${ICON_CHECK} Parameter Validation"

	# Validate flavor
	if [[ "$FLAVOR" != "development" && "$FLAVOR" != "production" && "$FLAVOR" != "staging" ]]; then
		print_error "Invalid flavor: $FLAVOR"
		echo -e "${GRAY}  Valid: development, production${NC}"
		exit 1
	fi
	print_success "Flavor: $FLAVOR"

	# Validate build type
	if [[ "$BUILD_TYPE" != "apk" && "$BUILD_TYPE" != "aab" ]]; then
		print_error "Invalid build type: $BUILD_TYPE"
		echo -e "${GRAY}  Valid: apk, aab${NC}"
		exit 1
	fi
	local build_type_upper=$(echo "$BUILD_TYPE" | tr '[:lower:]' '[:upper:]')
	print_success "Build type: $build_type_upper"

	# Validate package name
	if [[ -z "$APP_PACKAGE_NAME" ]]; then
		print_error "Package name not provided!"
		echo "Usage: ./build_and_distribute_android.sh <flavor> <buildType> <package_name>"
		exit 1
	fi
	print_success "Package name: $APP_PACKAGE_NAME"

	# Check keystore for production
	if [[ "$FLAVOR" == "production" ]]; then
		if [[ ! -f "$ANDROID_DIR/key.properties" ]]; then
			print_warning "key.properties not found"
			print_detail "Production build may fail without signing"
		else
			print_success "Keystore configured"
		fi
	fi
}

# ============================================================================
# 🔨 Build Process
# ============================================================================

clean_project() {
	print_section "${ICON_CLEAN} Cleaning Project"

	print_step "Running flutter clean..."
	flutter clean >/dev/null 2>&1 &
	spinner $! "Cleaning Flutter build cache..."
	print_success "Flutter cache cleaned"

	print_step "Removing Android build artifacts..."
	rm -rf "$ANDROID_DIR/app/build" >/dev/null 2>&1
	rm -rf "$ANDROID_DIR/.gradle" >/dev/null 2>&1
	rm -rf "$PROJECT_ROOT/build" >/dev/null 2>&1
	print_success "Build artifacts removed"
}

install_dependencies() {
	print_section "${ICON_PACKAGE} Installing Dependencies"

	print_step "Running flutter pub get..."
	flutter pub get >/dev/null 2>&1 &
	spinner $! "Fetching dependencies..."
	print_success "Dependencies installed"
}

build_android() {
	local build_type_upper=$(echo "$BUILD_TYPE" | tr '[:lower:]' '[:upper:]')
	print_section "${ICON_BUILD} Building Android $build_type_upper"

	echo -e "${WHITE}Build Configuration:${NC}"
	print_detail "Flavor: $FLAVOR"
	print_detail "Type: $build_type_upper"
	print_detail "Version: $VERSION_NAME ($VERSION_CODE)"
	echo ""

	print_step "Starting build process..."

	local build_cmd
	if [[ "$BUILD_TYPE" == "apk" ]]; then
		build_cmd="flutter build apk --flavor $FLAVOR --target lib/main_$FLAVOR.dart"
	else
		build_cmd="flutter build appbundle --release --flavor $FLAVOR --target lib/main_$FLAVOR.dart"
	fi
	print_step "Build Command: $build_cmd"

	# Execute build
	if $build_cmd; then
		print_success "Build completed successfully"
	else
		print_error "Build failed!"
		exit 1
	fi

	# Locate build output
	print_step "Locating build artifacts..."

	if [[ "$BUILD_TYPE" == "apk" ]]; then
		BUILD_OUTPUT=$(find "$PROJECT_ROOT/build/app/outputs/flutter-apk" -name "app-${FLAVOR}-release.apk" | head -n 1)
	else
		BUILD_OUTPUT=$(find "$PROJECT_ROOT/build/app/outputs/bundle" -name "app-${FLAVOR}-release.aab" | head -n 1)
	fi

	if [[ -z "$BUILD_OUTPUT" ]] || [[ ! -f "$BUILD_OUTPUT" ]]; then
		print_error "Build output not found!"
		exit 1
	fi

	# Display build info
	local file_size=$(du -h "$BUILD_OUTPUT" | cut -f1)
	print_success "Build artifact ready"
	print_detail "Path: ${BUILD_OUTPUT##*/}"
	print_detail "Size: $file_size"
}

# ============================================================================
# ☁️ Firebase Distribution
# ============================================================================

upload_to_firebase() {
	print_section "${ICON_UPLOAD} Uploading to Firebase"

	# Generate release notes if not provided
	if [[ -z "$RELEASE_NOTES" ]]; then
		RELEASE_NOTES="Version $VERSION_NAME - Built on $(date '+%Y-%m-%d at %H:%M:%S')"
	fi

	echo -e "${WHITE}Distribution Info:${NC}"
	print_detail "App ID: ${FIREBASE_ANDROID_APP_ID:0:30}..."
	print_detail "Version: $VERSION_NAME"
	print_detail "Testers: $TESTER_GROUP"
	print_detail "Notes: $RELEASE_NOTES"
	echo ""

	# Create temp file for release notes
	local notes_file="/tmp/release_notes_${BUILD_TYPE}_${VERSION_CODE}.txt"
	echo "$RELEASE_NOTES" >"$notes_file"

	print_step "Uploading to Firebase App Distribution..."

	# Upload with progress indication
	firebase appdistribution:distribute "$BUILD_OUTPUT" \
		--app "$FIREBASE_ANDROID_APP_ID" \
		--release-notes-file "$notes_file" \
		--groups "$TESTER_GROUP" &

	spinner $! "Uploading build to Firebase..."

	# Cleanup
	rm -f "$notes_file"

	print_success "Upload completed successfully!"
}

# ============================================================================
# 📊 Summary
# ============================================================================

print_summary() {
	local build_end_time=$(date +%s)
	local build_duration=$((build_end_time - BUILD_START_TIME))
	local minutes=$((build_duration / 60))
	local seconds=$((build_duration % 60))
	local build_type_upper=$(echo "$BUILD_TYPE" | tr '[:lower:]' '[:upper:]')

	print_section "${ICON_FIRE} Build Summary"

	echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_SUCCESS} ${WHITE}Build & Distribution Completed Successfully!${NC}             ${GREEN}║${NC}"
	echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
	echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_PACKAGE} Artifact Type:  ${CYAN}$build_type_upper${NC}                                     ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_BUILD} Flavor:         ${CYAN}${FLAVOR}${NC}                              ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_INFO}  Version:        ${CYAN}${VERSION_NAME} (${VERSION_CODE})${NC}                    ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_TIME}  Duration:       ${CYAN}${minutes}m ${seconds}s${NC}                              ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
	echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_UPLOAD} ${YELLOW}Testers will receive download notification${NC}               ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${ICON_FIRE}  ${YELLOW}View in Firebase Console:${NC}                                ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}  ${GRAY}https://console.firebase.google.com/project/_/appdistribution${NC} ${GREEN}║${NC}"
	echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
	echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
	echo ""
}

# ============================================================================
# 🚀 Main Execution
# ============================================================================

main() {
	print_banner

	# Environment validation
	validate_environment
	validate_parameters

	# Read Firebase configuration from google-services.json
	print_section "${ICON_FIRE} Firebase Configuration"
	read_firebase_config

	# Version management
	print_section "${ICON_INFO} Version Configuration"
	read_version_from_pubspec

	# Build process
	clean_project
	install_dependencies
	build_android

	# Upload to Firebase
	upload_to_firebase

	# Display summary
	print_summary
}

# Trap errors
trap 'print_error "Script failed! Restoring files..."; exit 1' ERR

# Execute main function
main
