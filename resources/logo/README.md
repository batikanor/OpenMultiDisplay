# Logo & Icon Guide

Hướng dẫn tạo logo cho OpenMultiDisplay.

---

## Files cần tạo

| File | Kích thước | Format | Dùng ở đâu |
|------|------------|--------|------------|
| `openmultidisplay-icon.png` | 512x512 | PNG (transparent) | macOS app icon, Android icon |
| `openmultidisplay-icon@2x.png` | 1024x1024 | PNG (transparent) | Retina displays |
| `openmultidisplay-logo.svg` | Vector | SVG | Website, scalable usage |
| `openmultidisplay-logo-dark.svg` | Vector | SVG | Dark mode variant |

---

## Concept Ideas

### Option 1: Two Screens
```
┌─────┐ ┌─────┐
│     │ │     │
│  M  │ │  T  │
│     │ │     │
└─────┘ └─────┘
   ↔️
```
Hai màn hình (Mac + Tablet) với connection indicator

### Option 2: Extended Display
```
┌──────────────┐
│    ┌────┐    │
│    │    │    │
│    └────┘    │
└──────────────┘
```
Một màn hình lớn với phần mở rộng

### Option 3: Abstract S
```
   ╭──╮
  ╱    ╲
 ╱      ╲
╱────────╲
         ╱
        ╱
╲──────╱
```
Chữ S cách điệu với gradient

---

## Style Guide

**Colors:**
- Primary: #00B8A9 (OpenMultiDisplay Teal)
- Secondary: #FF9F3F (Amber)
- Gradient: Blue → Amber
- Background: Transparent hoặc White

**Shape:**
- Rounded square (iOS style): corner radius ~22%
- Hoặc Circle

**Design Principles:**
- Simple, recognizable at small sizes
- Works on both light & dark backgrounds
- Không quá chi tiết (icon nhỏ sẽ bị mờ)

---

## Tools để tạo

### Free:
- [Figma](https://figma.com) - Vector design
- [Canva](https://canva.com) - Easy templates
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Apple icons

### Pro:
- Sketch
- Adobe Illustrator
- Affinity Designer

---

## Quick Start với SF Symbols

Nếu muốn nhanh, dùng SF Symbols:

```swift
// macOS: Export icon từ SF Symbols app
// Symbol: "rectangle.on.rectangle" hoặc "display.2"
```

1. Mở SF Symbols app
2. Tìm "display" hoặc "rectangle"
3. Export với màu #00B8A9
4. Thêm vào rounded square background

---

## Sau khi tạo xong

1. Đặt files vào thư mục này
2. Copy `openmultidisplay-icon.png` sang:
   - `website/assets/icon.png` (resize 128x128)
   - `MacHost/Resources/` (nếu cần)
   - `AndroidClient/app/src/main/res/mipmap-xxxhdpi/` (resize theo density)

3. Update paths trong README.md và website/index.html
