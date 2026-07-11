.PHONY: test test-unit test-uitest test-e2e generate

# 6 個 SPM local package，各自跑 `swift test`（純邏輯 / in-memory SwiftData，秒級、免模擬器）。
PACKAGES := SharedKernel Spec Training Plan History Settings

SCHEME := TrainingLa-Dev

# device / headless 這兩個可控變數，跟 Xcode 專案共用同一份 Config.xcconfig（單一真實來源）：
# - DEVICE：跑 UITests 的模擬器機型（對應 `xcrun simctl list devicetypes`）。
# - HEADLESS（bool：true/false）：true（預設）＝ 不開 Simulator.app 視窗；false ＝ 先
#   `open -a Simulator` 讓你看著跑。
# 兩者都可在指令列覆蓋，例如：make test-uitest DEVICE="iPhone 16 Pro" HEADLESS=false
CONFIG_FILE := Config.xcconfig
DEVICE ?= $(shell awk -F'= *' '/^TEST_DEVICE/ {print $$2}' $(CONFIG_FILE) | xargs)
HEADLESS ?= $(shell awk -F'= *' '/^TEST_HEADLESS/ {print $$2}' $(CONFIG_FILE) | xargs)

DESTINATION := platform=iOS Simulator,name=$(DEVICE)

# unit test + uitest（不含 e2e：v0 尚無真實後端可測）。
test: test-unit test-uitest

# 逐 package 執行 unit test（純邏輯 + in-memory SwiftData，不跑模擬器，跟 UITests 分開）。
test-unit:
	@for pkg in $(PACKAGES); do \
		echo "==> swift test: $$pkg"; \
		(cd Packages/$$pkg && swift test) || exit 1; \
	done

# TrainingLa.xcodeproj 不進版控，跑 UI test 前先用 xcodegen 重生。
generate:
	xcodegen generate

# 只跑 UITests.xctestplan（跟 unit test 分開的獨立 Test Plan，見 project.yml）。
test-uitest: generate
	@if [ "$(HEADLESS)" = "false" ]; then \
		echo "==> headless=false：開 Simulator.app"; open -a Simulator; \
	fi
	xcodebuild test \
		-project TrainingLa.xcodeproj \
		-scheme $(SCHEME) \
		-testPlan UITests \
		-destination '$(DESTINATION)'

# e2e uitest（打真實後端 API）：v0 是 local-first、尚無後端（見 PROJECT_PLAN.md），先佔位。
# 之後接 Go 後端（v1）時，這裡改跑對應 API_HOST 的 UI test scheme。
test-e2e:
	@echo "test-e2e：尚無真實後端 API（v0 local-first），之後接 Go 後端（v1）再補上。"
