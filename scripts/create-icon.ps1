$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$dir=Join-Path (Split-Path $PSScriptRoot) 'assets'
New-Item -ItemType Directory -Force $dir | Out-Null
$bitmap=[Drawing.Bitmap]::new(256,256)
$g=[Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([Drawing.Color]::Transparent)
$points=[Drawing.Point[]]@([Drawing.Point]::new(128,12),[Drawing.Point]::new(225,49),[Drawing.Point]::new(214,151),[Drawing.Point]::new(179,208),[Drawing.Point]::new(128,244),[Drawing.Point]::new(77,208),[Drawing.Point]::new(42,151),[Drawing.Point]::new(31,49))
$fill=[Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Point]::new(30,15),[Drawing.Point]::new(215,240),[Drawing.Color]::FromArgb(20,184,166),[Drawing.Color]::FromArgb(30,64,175))
$g.FillPolygon($fill,$points)
$pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(230,240,255),7)
$g.DrawPolygon($pen,$points)
$check=[Drawing.Pen]::new([Drawing.Color]::White,21)
$check.StartCap=[Drawing.Drawing2D.LineCap]::Round;$check.EndCap=[Drawing.Drawing2D.LineCap]::Round;$check.LineJoin=[Drawing.Drawing2D.LineJoin]::Round
$g.DrawLines($check,[Drawing.Point[]]@([Drawing.Point]::new(79,125),[Drawing.Point]::new(113,159),[Drawing.Point]::new(177,87)))
$bitmap.Save((Join-Path $dir 'sentinel.png'),[Drawing.Imaging.ImageFormat]::Png)
$icon=[Drawing.Icon]::FromHandle($bitmap.GetHicon())
$stream=[IO.File]::Create((Join-Path $dir 'sentinel.ico'))
try{$icon.Save($stream)}finally{$stream.Dispose();$icon.Dispose();$check.Dispose();$pen.Dispose();$fill.Dispose();$g.Dispose();$bitmap.Dispose()}
