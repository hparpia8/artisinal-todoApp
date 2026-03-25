.PHONY: setup generate build open clean archive help

setup:
	@bash setup.sh

generate:
	@echo "Generating Xcode project..."
	@xcodegen generate

build: generate
	@xcodebuild -project TodoApp.xcodeproj \
		-scheme TodoApp \
		-configuration Debug \
		build | xcpretty 2>/dev/null || xcodebuild -project TodoApp.xcodeproj -scheme TodoApp -configuration Debug build

open: generate
	@open TodoApp.xcodeproj

run: build
	@open "$(shell xcodebuild -project TodoApp.xcodeproj -scheme TodoApp -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}')/TodoApp.app"

archive: generate
	@xcodebuild -project TodoApp.xcodeproj \
		-scheme TodoApp \
		-configuration Release \
		archive \
		-archivePath build/TodoApp.xcarchive

clean:
	@rm -rf TodoApp.xcodeproj build
	@echo "Cleaned."

help:
	@echo ""
	@echo "  Artisanal Todo — Build Commands"
	@echo "  ────────────────────────────────"
	@echo "  make setup     Install deps + generate Xcode project"
	@echo "  make generate  Regenerate project from project.yml"
	@echo "  make build     Build debug"
	@echo "  make open      Open in Xcode"
	@echo "  make archive   Build release archive"
	@echo "  make clean     Remove generated project + build artifacts"
	@echo ""
