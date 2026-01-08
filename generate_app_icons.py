#!/usr/bin/env python3
"""
OneHopeStep App Icon Generator
Generates rounded corner icons for iOS, Android, and Web platforms
"""

from PIL import Image, ImageDraw
import os
import shutil

# Source logo path
SOURCE_LOGO = os.path.expanduser("~/Downloads/OneHopeStep.png")
PROJECT_ROOT = "/Users/sertaccokhamur/bir-adim-umut"

# iOS icon sizes (filename: size)
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# Android icon sizes (folder: size)
ANDROID_ICONS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Web icon sizes
WEB_ICONS = {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
}

def add_rounded_corners(img, radius_percent=22.37):
    """Add rounded corners to an image (iOS style ~22.37% of width)"""
    size = img.size[0]
    radius = int(size * radius_percent / 100)
    
    # Create a mask for rounded corners
    mask = Image.new('L', img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    
    # Apply the mask
    result = Image.new('RGBA', img.size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    
    return result

def resize_icon(source_img, size, rounded=True, radius_percent=22.37):
    """Resize image and optionally add rounded corners"""
    # High quality resize
    resized = source_img.resize((size, size), Image.Resampling.LANCZOS)
    
    if rounded:
        resized = add_rounded_corners(resized, radius_percent)
    
    return resized

def generate_ios_icons(source_img):
    """Generate all iOS app icons"""
    ios_path = os.path.join(PROJECT_ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    
    print("\n📱 iOS İkonları Oluşturuluyor...")
    for filename, size in IOS_ICONS.items():
        icon = resize_icon(source_img, size, rounded=False)  # iOS rounds automatically
        icon_path = os.path.join(ios_path, filename)
        # Convert to RGB for iOS (no transparency)
        if icon.mode == 'RGBA':
            background = Image.new('RGB', icon.size, (255, 255, 255))
            background.paste(icon, mask=icon.split()[3])
            icon = background
        icon.save(icon_path, "PNG")
        print(f"  ✅ {filename} ({size}x{size})")

def generate_android_icons(source_img):
    """Generate all Android app icons with rounded corners"""
    android_res_path = os.path.join(PROJECT_ROOT, "android/app/src/main/res")
    
    print("\n🤖 Android İkonları Oluşturuluyor...")
    for folder, size in ANDROID_ICONS.items():
        folder_path = os.path.join(android_res_path, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Regular icon (with rounded corners for Android)
        icon = resize_icon(source_img, size, rounded=True, radius_percent=20)
        icon_path = os.path.join(folder_path, "ic_launcher.png")
        icon.save(icon_path, "PNG")
        print(f"  ✅ {folder}/ic_launcher.png ({size}x{size})")
        
        # Foreground icon (for adaptive icons) - no rounding, system handles it
        foreground = resize_icon(source_img, size, rounded=False)
        foreground_path = os.path.join(folder_path, "ic_launcher_foreground.png")
        foreground.save(foreground_path, "PNG")
        print(f"  ✅ {folder}/ic_launcher_foreground.png ({size}x{size})")

def generate_web_icons(source_img):
    """Generate web icons"""
    web_icons_path = os.path.join(PROJECT_ROOT, "web/icons")
    os.makedirs(web_icons_path, exist_ok=True)
    
    print("\n🌐 Web İkonları Oluşturuluyor...")
    for filename, size in WEB_ICONS.items():
        # Maskable icons should have padding, regular icons can have rounded corners
        if "maskable" in filename:
            icon = resize_icon(source_img, size, rounded=False)
        else:
            icon = resize_icon(source_img, size, rounded=True, radius_percent=15)
        
        icon_path = os.path.join(web_icons_path, filename)
        icon.save(icon_path, "PNG")
        print(f"  ✅ {filename} ({size}x{size})")
    
    # Also create favicon
    favicon = resize_icon(source_img, 32, rounded=True, radius_percent=15)
    favicon_path = os.path.join(PROJECT_ROOT, "web/favicon.png")
    favicon.save(favicon_path, "PNG")
    print(f"  ✅ favicon.png (32x32)")

def generate_assets_logo(source_img):
    """Generate logo for assets folder"""
    assets_path = os.path.join(PROJECT_ROOT, "assets/images")
    os.makedirs(assets_path, exist_ok=True)
    
    print("\n🎨 Assets Logosu Oluşturuluyor...")
    
    # Logo with rounded corners for profile screen etc.
    logo = resize_icon(source_img, 512, rounded=True, radius_percent=20)
    logo_path = os.path.join(assets_path, "app_logo.png")
    logo.save(logo_path, "PNG")
    print(f"  ✅ assets/images/app_logo.png (512x512)")
    
    # Also copy to web folder for HTML pages
    web_logo = resize_icon(source_img, 256, rounded=True, radius_percent=20)
    web_logo_path = os.path.join(PROJECT_ROOT, "web/logo.png")
    web_logo.save(web_logo_path, "PNG")
    print(f"  ✅ web/logo.png (256x256)")
    
    # Copy to docs folder too
    docs_path = os.path.join(PROJECT_ROOT, "docs")
    os.makedirs(docs_path, exist_ok=True)
    docs_logo_path = os.path.join(docs_path, "logo.png")
    web_logo.save(docs_logo_path, "PNG")
    print(f"  ✅ docs/logo.png (256x256)")

def main():
    print("🚀 OneHopeStep İkon Oluşturucu")
    print("=" * 40)
    
    # Check if source logo exists
    if not os.path.exists(SOURCE_LOGO):
        print(f"❌ Logo bulunamadı: {SOURCE_LOGO}")
        return
    
    # Load source image
    print(f"\n📂 Logo yükleniyor: {SOURCE_LOGO}")
    source_img = Image.open(SOURCE_LOGO).convert('RGBA')
    print(f"   Boyut: {source_img.size[0]}x{source_img.size[1]}")
    
    # Generate icons for all platforms
    generate_ios_icons(source_img)
    generate_android_icons(source_img)
    generate_web_icons(source_img)
    generate_assets_logo(source_img)
    
    print("\n" + "=" * 40)
    print("✅ Tüm ikonlar başarıyla oluşturuldu!")
    print("\n💡 Şimdi uygulamayı yeniden derleyin:")
    print("   flutter clean && flutter run")

if __name__ == "__main__":
    main()
