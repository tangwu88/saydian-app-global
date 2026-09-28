# Deterministic exports from the user-supplied, read-only black symbol.
# Requires ImageMagick 7. Do not upscale another exported icon as a source.
$ErrorActionPreference = 'Stop'
$brandRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $brandRoot 'assets/branding/saydian-black-logo-original.jpg'
$magick = (Get-Command magick -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $source)) { throw "Missing approved logo: $source" }

function Export-BrandImage([string[]]$Arguments) {
  & $magick @Arguments
  if ($LASTEXITCODE -ne 0) { throw "ImageMagick failed: $($Arguments -join ' ')" }
}

$branding = Join-Path $brandRoot 'assets/branding'
$master = Join-Path $branding 'saidian-launcher-master.png'
$mark = Join-Path $branding 'saidian-brand-mark.png'
$lockup = Join-Path $branding 'saidian-brand-lockup.png'

# The original is a JPEG with a .png filename and a light-gray background.
# Normalize its black/white tones while preserving the supplied geometry.
Export-BrandImage @($source, '-colorspace', 'Gray', '-level', '3%,92%',
  '-resize', '880x880', '-background', 'white', '-gravity', 'center',
  '-extent', '1024x1024', '-type', 'TrueColor', '-strip', "PNG24:$master")
$mask = Join-Path $branding 'saidian-black-mark-mask-temp.png'
try {
  # Only the area outside the circular emblem is transparent. Its internal
  # white shapes must stay white even where they approach the edge.
  Export-BrandImage @('-size', '1024x1024', 'xc:black', '-fill', 'white',
    '-draw', 'circle 540,503 915,503', "PNG24:$mask")
  Export-BrandImage @($master, $mask, '-alpha', 'off', '-compose',
    'CopyOpacity', '-composite', '-resize', '334x334', '-strip', "PNG32:$mark")
} finally {
  if (Test-Path -LiteralPath $mask) { Remove-Item -LiteralPath $mask }
}
Export-BrandImage @($master, '-resize', '1024x1024', '-strip',
  "PNG24:$(Join-Path $branding 'app_icon_source.png')")
Copy-Item -LiteralPath $mark -Destination (Join-Path $branding 'saidian-brand-mark-source.png') -Force
Export-BrandImage @($master, '-resize', '512x512', '-strip',
  "PNG24:$(Join-Path $branding 'saidian-launcher-rounded.png')")
Export-BrandImage @($master, '-resize', '512x512', '-strip',
  "PNG24:$(Join-Path $branding 'saidian-launcher-foreground.png')")

$smallMark = Join-Path $branding 'saidian-black-mark-lockup-temp.png'
try {
  Export-BrandImage @($master, '-resize', '224x224', "PNG24:$smallMark")
  Export-BrandImage @('-size', '630x284', 'canvas:white', $smallMark,
    '-geometry', '+20+30', '-composite', '-gravity', 'NorthWest',
    '-font', 'Arial-Bold', '-pointsize', '65', '-fill', '#17191C',
    '-annotate', '+255+112', 'SAYDIAN', '-font', 'Arial', '-pointsize', '39',
    '-fill', '#5D646B', '-annotate', '+259+172', 'Health',
    '-strip', "PNG24:$lockup")
} finally {
  if (Test-Path -LiteralPath $smallMark) { Remove-Item -LiteralPath $smallMark }
}
Copy-Item -LiteralPath $lockup -Destination (Join-Path $branding 'saidian-brand-lockup-source.png') -Force
Copy-Item -LiteralPath $lockup -Destination (Join-Path $branding 'saidian-brand-lockup-preview.png') -Force
Copy-Item -LiteralPath $lockup -Destination (Join-Path $brandRoot 'harmony-native/entry/src/main/resources/base/media/brand_lockup.png') -Force
Copy-Item -LiteralPath $master -Destination (Join-Path $brandRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png') -Force
foreach ($name in @('app_icon.png', 'app_icon_v2.png', 'app_icon_v3.png')) {
  Copy-Item -LiteralPath $master -Destination (Join-Path $brandRoot "harmony-native/AppScope/resources/base/media/$name") -Force
}

$iosContent = Get-Content -Raw -LiteralPath (Join-Path $brandRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') | ConvertFrom-Json
foreach ($item in $iosContent.images) {
  if ($item.filename -eq 'Icon-App-1024x1024@1x.png') { continue }
  $side = [int]([double]($item.size.Split('x')[0]) * [double]($item.scale.TrimEnd('x')))
  $target = Join-Path $brandRoot "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($item.filename)"
  Export-BrandImage @($master, '-resize', "${side}x${side}", '-strip', "PNG24:$target")
}

foreach ($row in @(@('mdpi',48,108), @('hdpi',72,162), @('xhdpi',96,216),
                 @('xxhdpi',144,324), @('xxxhdpi',192,432))) {
  $density = $row[0]; $size = [int]$row[1]; $adaptive = [int]$row[2]
  $legacy = Join-Path $brandRoot "android/app/src/main/res/mipmap-$density/ic_launcher.png"
  Export-BrandImage @($master, '-resize', "${size}x${size}", '-strip', "PNG24:$legacy")
  Copy-Item -LiteralPath $legacy -Destination (Join-Path $brandRoot "android/app/src/main/res/mipmap-$density/ic_launcher_round.png") -Force
  $safe = [int][Math]::Round($adaptive * 66 / 108)
  $foreground = Join-Path $brandRoot "android/app/src/main/res/drawable-$density/ic_launcher_foreground.png"
  $monochrome = Join-Path $brandRoot "android/app/src/main/res/drawable-$density/ic_launcher_monochrome.png"
  Export-BrandImage @($master, '-resize', "${safe}x${safe}", '-background', 'none',
    '-gravity', 'center', '-extent', "${adaptive}x${adaptive}", '-strip', "PNG32:$foreground")
  Export-BrandImage @($master, '-colorspace', 'Gray', '-negate', '-alpha', 'copy',
    '-fill', 'black', '-colorize', '100', '-resize', "${safe}x${safe}",
    '-background', 'none', '-gravity', 'center', '-extent', "${adaptive}x${adaptive}",
    '-strip', "PNG32:$monochrome")
}
Write-Output "Exported SAYDIAN Health black brand assets from $source"
