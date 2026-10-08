# Pack the shared macOS artwork into Windows ICO sizes with transparent rounded corners.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskSource = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot '..\Sources\SearcheXtra\Resources\AppIcon.png'))
$taskFrames = @()
try {
    foreach ($taskSize in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $taskScaled = [Drawing.Bitmap]::new($taskSize, $taskSize)
        $taskScaling = [Drawing.Graphics]::FromImage($taskScaled)
        $taskScaling.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        # Match the inner plate crop used by macOS, without the outer white mat.
        $taskArtwork = [Drawing.RectangleF]::new(
            [single]($taskSource.Width * 160 / 1254), [single]($taskSource.Height * 172 / 1254),
            [single]($taskSource.Width * 930 / 1254), [single]($taskSource.Height * 910 / 1254))
        $taskScaling.DrawImage($taskSource, [Drawing.RectangleF]::new(0, 0, $taskSize, $taskSize),
            $taskArtwork, [Drawing.GraphicsUnit]::Pixel)
        $taskScaling.Dispose()
        $taskBitmap = [Drawing.Bitmap]::new($taskSize, $taskSize)
        $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskGraphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $taskPath = [Drawing.Drawing2D.GraphicsPath]::new()
        $taskDiameter = [single]($taskSize / 2)
        $taskEdge = [single]$taskSize
        $taskPath.AddArc(0, 0, $taskDiameter, $taskDiameter, 180, 90)
        $taskPath.AddArc($taskEdge - $taskDiameter, 0, $taskDiameter, $taskDiameter, 270, 90)
        $taskPath.AddArc($taskEdge - $taskDiameter, $taskEdge - $taskDiameter, $taskDiameter, $taskDiameter, 0, 90)
        $taskPath.AddArc(0, $taskEdge - $taskDiameter, $taskDiameter, $taskDiameter, 90, 90)
        $taskPath.CloseFigure()
        $taskBrush = [Drawing.TextureBrush]::new($taskScaled)
        $taskGraphics.FillPath($taskBrush, $taskPath)
        $taskStream = [IO.MemoryStream]::new()
        $taskBitmap.Save($taskStream, [Drawing.Imaging.ImageFormat]::Png)
        $taskFrames += [pscustomobject]@{ Size = $taskSize; Bytes = $taskStream.ToArray() }
        $taskStream.Dispose(); $taskBrush.Dispose(); $taskPath.Dispose()
        $taskGraphics.Dispose(); $taskBitmap.Dispose(); $taskScaled.Dispose()
    }
} finally { $taskSource.Dispose() }
$taskDestination = Join-Path $PSScriptRoot 'SearcheXtra\AppIcon.ico'
$taskWriter = [IO.BinaryWriter]::new([IO.File]::Create($taskDestination))
try {
    $taskWriter.Write([uint16]0); $taskWriter.Write([uint16]1); $taskWriter.Write([uint16]$taskFrames.Count)
    $taskOffset = 6 + 16 * $taskFrames.Count
    foreach ($taskFrame in $taskFrames) {
        $taskDimension = if ($taskFrame.Size -eq 256) { 0 } else { $taskFrame.Size }
        $taskWriter.Write([byte]$taskDimension); $taskWriter.Write([byte]$taskDimension)
        $taskWriter.Write([byte]0); $taskWriter.Write([byte]0)
        $taskWriter.Write([uint16]1); $taskWriter.Write([uint16]32)
        $taskWriter.Write([uint32]$taskFrame.Bytes.Length); $taskWriter.Write([uint32]$taskOffset)
        $taskOffset += $taskFrame.Bytes.Length
    }
    foreach ($taskFrame in $taskFrames) { $taskWriter.Write([byte[]]$taskFrame.Bytes) }
} finally { $taskWriter.Dispose() }

# The in-app image must carry its own alpha mask, just like the shell icon.
$taskAppImage = Join-Path $PSScriptRoot 'SearcheXtra\Assets\AppIcon.png'
[IO.File]::WriteAllBytes($taskAppImage, ($taskFrames | Where-Object Size -eq 256).Bytes)

# The installer wizard uses separate artwork from its executable icon.
foreach ($taskWizardIcon in @(
    @{ Size = 128; Name = 'WizardIcon.png' },
    @{ Size = 48; Name = 'WizardSmallIcon.png' }
)) {
    $taskFrame = $taskFrames | Where-Object Size -eq $taskWizardIcon.Size
    [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot ('Installer\' + $taskWizardIcon.Name)), $taskFrame.Bytes)
}
