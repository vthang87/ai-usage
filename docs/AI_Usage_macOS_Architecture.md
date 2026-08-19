# AI Usage for macOS

## 1. Mục tiêu

Xây dựng một ứng dụng **native macOS** để theo dõi trạng thái và mức sử dụng của các AI coding tools như:

- Codex CLI
- Cursor
- (Mở rộng) Claude Code
- (Mở rộng) Gemini CLI
- (Mở rộng) GitHub Copilot

Ứng dụng hoạt động hoàn toàn **offline/local**, không cần server.

---

# 2. Mục tiêu MVP

## Chức năng

- Menu Bar App
- Widget macOS (Small, Medium)
- Refresh thủ công
- Refresh định kỳ
- Hiển thị:
  - Usage %
  - Quota
  - Thời gian reset
  - Online / Offline
  - Last Updated

---

# 3. Công nghệ

- Swift 6
- SwiftUI
- WidgetKit
- App Groups
- MenuBarExtra
- UserDefaults (App Group)

Không sử dụng:

- Electron
- Tauri
- Docker
- Web Server
- PostgreSQL

---

# 4. Kiến trúc

```text
AIUsage.app
│
├── Menu Bar
├── Settings
├── Collector
│   ├── Codex Provider
│   └── Cursor Provider
│
├── Shared App Group
│
└── AIUsageWidget
```

Luồng dữ liệu:

```text
Codex CLI
Cursor CLI
      │
      ▼
Collector
      │
      ▼
Shared App Group
      │
      ▼
WidgetKit
      │
      ▼
Desktop Widget
```

---

# 5. Cấu trúc Project

```text
AIUsage/

├── AIUsage/
│   ├── App/
│   ├── MenuBar/
│   ├── Settings/
│   ├── Providers/
│   │   ├── CodexProvider.swift
│   │   └── CursorProvider.swift
│   ├── Services/
│   └── Models/
│
├── AIUsageWidget/
│
└── Shared/
```

---

# 6. Data Model

```swift
struct UsageSnapshot {

    var codex: ProviderUsage?

    var cursor: ProviderUsage?

    var updatedAt: Date
}
```

---

# 7. Widget

## Small

- Codex %
- Cursor %
- Last updated

## Medium

- Codex
  - 5 Hour
  - Weekly
- Cursor
  - Usage
  - Reset
- Last Updated

---

# 8. Menu Bar

Ví dụ:

```text
🤖 72%

Codex
 5 Hour 72%
 Weekly 43%

Cursor
 Usage 61%

Refresh
Open Dashboard
Quit
```

---

# 9. Collector

Nhiệm vụ:

- Detect Codex CLI
- Detect Cursor CLI
- Parse output
- Chuẩn hóa dữ liệu
- Lưu App Group
- Reload Widget

---

# 10. Refresh Strategy

Collector:

- Mỗi 5 phút
- Refresh thủ công
- Khi mở ứng dụng

Widget:

- Đọc dữ liệu từ Shared App Group
- Reload timeline khi collector cập nhật

---

# 11. Apple Developer

## Không cần

Có thể phát triển và sử dụng trên máy cá nhân với:

- Xcode miễn phí
- Personal Team

Hỗ trợ:

- SwiftUI
- WidgetKit
- Menu Bar
- App Groups

## Chỉ cần Apple Developer khi

- Đưa lên App Store
- TestFlight
- Notarization
- Developer ID

---

# 12. Roadmap

## Phase 1

- Menu Bar
- Collector
- Codex
- Cursor
- Refresh

## Phase 2

- Widget Small
- Widget Medium
- Notifications

## Phase 3

- History
- Charts
- Claude Code
- Gemini CLI
- GitHub Copilot

---

# 13. Định hướng mở rộng

- Token history
- Cost analytics
- Daily usage
- Weekly usage
- Notifications khi quota gần hết
- Plugin architecture cho AI providers
- Xuất JSON/CSV
- Dark Mode / Light Mode

---

# 14. Kết luận

Dự án ưu tiên kiến trúc **native macOS** với SwiftUI + WidgetKit. Menu Bar App chịu trách nhiệm thu thập dữ liệu từ các CLI và lưu vào App Group; Widget chỉ đọc dữ liệu đã chuẩn hóa để hiển thị nhanh, giúp ứng dụng nhẹ, ổn định và dễ mở rộng.
