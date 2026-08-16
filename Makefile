.PHONY: test test-unit test-uitest test-uitest-zh test-uitest-en uitest-run test-e2e generate lint report

# 9 個 SPM local package，各自跑 `swift test`（純邏輯 / in-memory SwiftData，秒級、免模擬器）。
# DesignSystem 只測純函式（滾輪幾何 WheelGeometry、月曆格線 CalendarStripGeometry），
# 元件本身是 View 測不動。
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
UITEST_REPORT_FLAGS := -resultBundlePath $(REPORT_DIR)/uitest-$(LANG_TAG).xcresult
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
# 英文覆蓋是**同一批測試再跑一輪**（`test-uitest-en`），不是每支 case 寫中英兩份 func
# ——差別只在注入給測試 runner 的 UITEST_APP_LANGUAGE。所以 `test-uitest` ＝ 兩輪都跑；
# 開發中只想跑一種語言就直接叫 `test-uitest-zh` / `test-uitest-en`。
#
# 裝置語系兩輪都維持繁中（configuration 不動）。要驗的是「app 語言 ≠ 裝置語系」的中英混雜；
# 兩邊都設英文的話 `String(localized:)` 也會回英文，反而把 bug 藏起來。
#
# ONLY：只跑指定的測試類別，空白分隔（`make test-uitest-en ONLY="SettingsUITests ExerciseListUITests"`）。
ONLY ?=
UITEST_ONLY_FLAGS := $(foreach t,$(ONLY),-only-testing:TrainingLaUITests/$(t))

# 預設兩輪都跑：同一批 case，app 繁中一輪、app 英文一輪。
test-uitest: test-uitest-zh test-uitest-en

test-uitest-zh: generate
	@$(MAKE) --no-print-directory uitest-run LANG_TAG=$(LANGUAGE) CONFIGURATION=$(LANGUAGE)

# 英文那一輪：裝置語系照舊，只把 app 的語言設定改成英文。
#
# 語言由 test plan 的 `en-app` configuration 用 environmentVariableEntries 注入
# （`UITEST_APP_LANGUAGE=en`），`UITests/UITestSupport.swift` 讀到就把
# `--uitest-language=en` 併進 launch arguments。
#
# ⚠️ 不能用 `xcodebuild test TEST_RUNNER_UITEST_APP_LANGUAGE=en`：帶了 `-testPlan` 之後
# 命令列的 TEST_RUNNER_* 會被**靜默忽略**，測試照樣跑但語言沒切——實測踩過，
# 而且因為期望值也是從同一個變數算出來的，守衛不會紅。
test-uitest-en: generate
	@$(MAKE) --no-print-directory uitest-run LANG_TAG=$(LANGUAGE)-app-en CONFIGURATION=en-app

# 兩個 target 共用的執行本體。CONFIGURATION 決定跑 test plan 的哪一組
# （zh-Hant＝app 走預設語言；en-app＝同一組裝置語系、app 切英文）。
uitest-run:
	@if [ "$(HEADLESS)" = "false" ]; then \
		echo "==> headless=false：開 Simulator.app"; open -a Simulator; \
	fi
	@# xcodebuild 遇到既有的 result bundle 會直接報 error 64（不會覆寫），所以先清掉上一次的。
	@if [ "$(REPORT)" = "true" ]; then \
		mkdir -p $(REPORT_DIR); rm -rf $(REPORT_DIR)/uitest-$(LANG_TAG).xcresult; \
	fi
	xcodebuild test \
		-project TrainingLa.xcodeproj \
		-scheme $(SCHEME) \
		-testPlan UITests \
		-destination '$(DESTINATION)' \
		-only-test-configuration $(CONFIGURATION) \
		$(UITEST_ONLY_FLAGS) \
		$(UITEST_REPORT_FLAGS)
ifeq ($(REPORT),true)
	@$(MAKE) --no-print-directory report KIND=ui LANG_TAG=$(LANG_TAG)
endif

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
