.PHONY: test test-unit test-uitest test-uitest-en test-e2e generate lint report

# 9 個 SPM local package，各自跑 `swift test`（純邏輯 / in-memory SwiftData，秒級、免模擬器）。
# DesignSystem 只測純函式（滾輪幾何 WheelGeometry），元件本身是 View 測不動。
PACKAGES := SharedKernel Spec Training Plan History Settings Reminders Ability DesignSystem

SCHEME := TrainingLa-Dev

# 可控變數跟 Xcode 專案共用同一份 Config.xcconfig（單一真實來源）：
# - DEVICE：跑 UITests 的模擬器機型（對應 `xcrun simctl list devicetypes`）。
# - HEADLESS（bool）：true（預設）＝ 不開 Simulator.app 視窗；false ＝ 先 `open -a Simulator` 讓你看著跑。
# - LANGUAGE：UITests 要用的 test plan configuration（裝置語系），zh-Hant／en。
# - REPORT（bool）：true ＝ 產生測試報告並上傳 Notion；false（預設）＝ 行為與加這個開關之前完全相同。
# 都可在指令列覆蓋，例如：make test-uitest DEVICE="iPhone 16 Pro" HEADLESS=false REPORT=true
CONFIG_FILE := Config.xcconfig
DEVICE ?= $(shell awk -F'= *' '/^TEST_DEVICE/ {print $$2}' $(CONFIG_FILE) | xargs)
HEADLESS ?= $(shell awk -F'= *' '/^TEST_HEADLESS/ {print $$2}' $(CONFIG_FILE) | xargs)
LANGUAGE ?= $(shell awk -F'= *' '/^TEST_LANGUAGE/ {print $$2}' $(CONFIG_FILE) | xargs)
REPORT ?= $(shell awk -F'= *' '/^TEST_REPORT/ {print $$2}' $(CONFIG_FILE) | xargs)

DESTINATION := platform=iOS Simulator,name=$(DEVICE)

# 報告產物；gitignored。REPORT=false 時完全不會產生。
REPORT_DIR := test-reports

# REPORT=true 才追加的旗標。刻意讓 REPORT=false 的指令跟加這個開關之前逐字相同——
# 預設路徑不該因為多了一個報告功能而改變行為（`-resultBundlePath` 會搬動 xcresult 的落點）。
ifeq ($(REPORT),true)
UITEST_REPORT_FLAGS := -resultBundlePath $(REPORT_DIR)/uitest-$(LANGUAGE).xcresult
else
UITEST_REPORT_FLAGS :=
endif

# unit test + uitest（不含 e2e：v0 尚無真實後端可測）。
test: test-unit test-uitest

# 逐 package 執行 unit test（純邏輯 + in-memory SwiftData，不跑模擬器，跟 UITests 分開）。
# REPORT=true 時各 package 另外吐一份 JUnit XML 供解析（swift-testing 會存成 *-swift-testing.xml）。
test-unit:
ifeq ($(REPORT),true)
	@mkdir -p $(REPORT_DIR)
	@rm -f $(REPORT_DIR)/unit-*.xml
	@set -e; for pkg in $(PACKAGES); do \
		echo "==> swift test: $$pkg"; \
		(cd Packages/$$pkg && swift test --xunit-output ../../$(REPORT_DIR)/unit-$$pkg.xml) || exit 1; \
	done
	@$(MAKE) --no-print-directory report KIND=unit LANG_TAG=n/a
else
	@for pkg in $(PACKAGES); do \
		echo "==> swift test: $$pkg"; \
		(cd Packages/$$pkg && swift test) || exit 1; \
	done
endif

# TrainingLa.xcodeproj 不進版控，跑 UI test 前先用 xcodegen 重生。
#
# 重生完把 UITests 的原始碼 touch 一次，強制那個 target 重新編譯。
# 原因：實測過改了 UITests/*.swift 之後 xcodebuild 連續三次都回報 0 個編譯動作、跑的是**舊的**
# 測試 bundle（改 package 原始碼則正常重建）。那會靜默地讓你以為測試通過——最糟的失敗模式。
# 推測是 xcodegen 每次重寫 pbxproj 打亂了這個 target 的增量狀態。整包 clean 要多花兩分鐘，
# 這個 target 很小，touch 一下重編只要幾秒。
generate:
	xcodegen generate
	@touch UITests/*.swift

# 只跑 UITests.xctestplan（跟 unit test 分開的獨立 Test Plan，見 project.yml）。
#
# 既有的 22 個測試靠中文標籤查元素，所以測試計畫的 configuration 決定裝置語系；
# EnglishLocalizationUITests 是唯一與語言無關的一支，另外跑（見 test-uitest-en），這裡排除。
test-uitest: generate
	@if [ "$(HEADLESS)" = "false" ]; then \
		echo "==> headless=false：開 Simulator.app"; open -a Simulator; \
	fi
	@# xcodebuild 遇到既有的 result bundle 會直接報 error 64（不會覆寫），所以先清掉上一次的。
	@if [ "$(REPORT)" = "true" ]; then \
		mkdir -p $(REPORT_DIR); rm -rf $(REPORT_DIR)/uitest-$(LANGUAGE).xcresult; \
	fi
	xcodebuild test \
		-project TrainingLa.xcodeproj \
		-scheme $(SCHEME) \
		-testPlan UITests \
		-destination '$(DESTINATION)' \
		-only-test-configuration $(LANGUAGE) \
		-skip-testing:TrainingLaUITests/EnglishLocalizationUITests \
		$(UITEST_REPORT_FLAGS)
ifeq ($(REPORT),true)
	@$(MAKE) --no-print-directory report KIND=ui LANG_TAG=$(LANGUAGE)
endif

# 英文本地化的 smoke test：裝置語系維持繁中、只把 app 的語言設定改成英文
# （靠 `--uitest-language=en` launch argument）。兩邊都設英文的話 `String(localized:)` 也會回英文，
# 反而看不出「不跟著 app 語言切」這個 bug——所以這裡刻意不動 configuration。
test-uitest-en: generate
	xcodebuild test \
		-project TrainingLa.xcodeproj \
		-scheme $(SCHEME) \
		-testPlan UITests \
		-destination '$(DESTINATION)' \
		-only-test-configuration zh-Hant \
		-only-testing:TrainingLaUITests/EnglishLocalizationUITests

# i18n 迴歸防護：擋裸 String(localized:) 與寫死的中文字串（見 scripts/check-i18n.sh）。
lint:
	@./scripts/check-i18n.sh

# 解析 test-reports/ 的產物並上傳 Notion。由 test-unit / test-uitest 在 REPORT=true 時呼叫，
# 也可以自己跑。上傳失敗只印警告、不改變結束碼——測試結果才是 exit code 的來源。
report:
	@python3 scripts/test_report.py --kind $(KIND) --language $(LANG_TAG) --dir $(REPORT_DIR) || \
		echo "⚠️ 測試報告上傳失敗（不影響測試結果）"

# e2e uitest（打真實後端 API）：v0 是 local-first、尚無後端（見 PROJECT_PLAN.md），先佔位。
# 之後接 Go 後端（v1）時，這裡改跑對應 API_HOST 的 UI test scheme。
test-e2e:
	@echo "test-e2e：尚無真實後端 API（v0 local-first），之後接 Go 後端（v1）再補上。"
