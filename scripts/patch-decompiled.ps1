[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApktoolProject,

    [switch]$DryRun,
    [switch]$SkipUiText
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath $ApktoolProject).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:changeCount = 0

function Join-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $projectRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }
    return [IO.File]::ReadAllText($Path)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    if ($DryRun) {
        return
    }
    [IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Replace-Literal {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-ProjectPath $RelativePath
    $text = Read-TextFile $path

    if ($text.Contains($New)) {
        Write-Host "already patched: $Label"
        return
    }

    if (-not $text.Contains($Old)) {
        throw "Patch anchor not found for '$Label' in $RelativePath"
    }

    $text = $text.Replace($Old, $New)
    Write-TextFile $path $text
    $script:changeCount++
    Write-Host "patched: $Label"
}

function Replace-RegexOnce {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Replacement,
        [string]$AlreadyMarker,
        [string]$AlreadyPattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-ProjectPath $RelativePath
    $text = Read-TextFile $path

    if ($AlreadyMarker -and $text.Contains($AlreadyMarker)) {
        Write-Host "already patched: $Label"
        return
    }

    if ($AlreadyPattern -and [regex]::IsMatch($text, $AlreadyPattern, [Text.RegularExpressions.RegexOptions]::Singleline)) {
        Write-Host "already patched: $Label"
        return
    }

    $regex = [regex]::new($Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    $match = $regex.Match($text)
    if (-not $match.Success) {
        throw "Patch anchor not found for '$Label' in $RelativePath"
    }

    $text = $regex.Replace($text, $Replacement, 1)
    Write-TextFile $path $text
    $script:changeCount++
    Write-Host "patched: $Label"
}

function Insert-Before {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Anchor,
        [Parameter(Mandatory = $true)][string]$InsertText,
        [Parameter(Mandatory = $true)][string]$AlreadyMarker,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-ProjectPath $RelativePath
    $text = Read-TextFile $path

    if ($text.Contains($AlreadyMarker)) {
        Write-Host "already patched: $Label"
        return
    }

    $index = $text.IndexOf($Anchor, [StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw "Patch anchor not found for '$Label' in $RelativePath"
    }

    $text = $text.Insert($index, $InsertText)
    Write-TextFile $path $text
    $script:changeCount++
    Write-Host "patched: $Label"
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-ProjectPath $RelativePath
    $text = Read-TextFile $path
    if (-not $text.Contains($Needle)) {
        throw "Verification failed: $Label"
    }
}

$textureEncoder = "smali_classes2/com/seu/magicfilter/encoder/video/TextureMovieEncoder.smali"
$videoManager = "smali_classes2/com/jcr/android/smoothcam/config/VideoManager.smali"
$camera1Api = "smali_classes2/com/jcr/android/smoothcam/cameraapichange/Camera1_api.smali"
$cameraActivity = "smali_classes2/com/jcr/android/smoothcam/activity/CameraActivity.smali"
$resolutionAdapter = "smali_classes2/com/jcr/android/smoothcam/adapter/ResolutionAdapter.smali"
$cameraConstants = "smali_classes2/com/jcr/android/smoothcam/config/CameraConstants.smali"

Replace-Literal `
    -RelativePath $textureEncoder `
    -Old ".field private static final FRAME_RATE:I = 0x1e" `
    -New ".field private static final FRAME_RATE:I = 0x3c" `
    -Label "TextureMovieEncoder FRAME_RATE"

Replace-Literal `
    -RelativePath $textureEncoder `
    -Old "    const/high16 v1, 0x41f00000    # 30.0f" `
    -New "    const/high16 v1, 0x42700000    # 60.0f" `
    -Label "TextureMovieEncoder reserve frame rate float"

Replace-RegexOnce `
    -RelativePath $textureEncoder `
    -Pattern '(const/16\s+v3,\s+)0x1e(\s+\r?\n\s+\.line\s+\d+\s+\r?\n\s+\.line\s+\d+\s+\r?\n\s+const-string\s+v5,\s+"frame-rate")' `
    -Replacement '${1}0x3c${2}' `
    -AlreadyMarker 'const/16 v3, 0x3c' `
    -Label "TextureMovieEncoder MediaFormat frame-rate"

Replace-Literal `
    -RelativePath $videoManager `
    -Old "    iget v2, v0, Landroid/media/CamcorderProfile;->videoFrameRate:I" `
    -New "    const/16 v2, 0x3c" `
    -Label "VideoManager normalMediaRecorder videoFrameRate"

$setProfileCall = "    invoke-virtual {v1, v0}, Landroid/media/MediaRecorder;->setProfile(Landroid/media/CamcorderProfile;)V"
$setProfilePatched = @"
    invoke-virtual {v1, v0}, Landroid/media/MediaRecorder;->setProfile(Landroid/media/CamcorderProfile;)V

    const/16 v2, 0x3c

    invoke-virtual {v1, v2}, Landroid/media/MediaRecorder;->setVideoFrameRate(I)V
"@

Replace-Literal `
    -RelativePath $videoManager `
    -Old $setProfileCall `
    -New $setProfilePatched `
    -Label "VideoManager setVideoFrameRate after setProfile"

$force60Method = @"
.method private force60Fps()V
    .locals 3

    :try_start_0
    invoke-static {}, Lcom/seu/magicfilter/camera/CameraEngine;->getParameters()Landroid/hardware/Camera`$Parameters;

    move-result-object v0

    const/4 v1, 0x1

    invoke-virtual {v0, v1}, Landroid/hardware/Camera`$Parameters;->setRecordingHint(Z)V

    const v1, 0xea60

    invoke-virtual {v0, v1, v1}, Landroid/hardware/Camera`$Parameters;->setPreviewFpsRange(II)V

    const-string v1, " Camera1_api force60Fps"

    invoke-static {v1}, Lcom/seu/magicfilter/camera/CameraEngine;->getCamera(Ljava/lang/String;)Landroid/hardware/Camera;

    move-result-object v1

    invoke-virtual {v1, v0}, Landroid/hardware/Camera;->setParameters(Landroid/hardware/Camera`$Parameters;)V
    :try_end_0
    .catch Ljava/lang/RuntimeException; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    return-void
.end method

"@

Insert-Before `
    -RelativePath $camera1Api `
    -Anchor ".method public startRecord(IIIIFI)V" `
    -InsertText $force60Method `
    -AlreadyMarker ".method private force60Fps()V" `
    -Label "Camera1_api force60Fps method"

$focusCall = "    invoke-static {}, Lcom/seu/magicfilter/camera/CameraEngine;->setContinuousVideoFocus()V"
$focusCallPatched = @"
    invoke-static {}, Lcom/seu/magicfilter/camera/CameraEngine;->setContinuousVideoFocus()V

    invoke-direct {p0}, Lcom/jcr/android/smoothcam/cameraapichange/Camera1_api;->force60Fps()V
"@

Replace-Literal `
    -RelativePath $camera1Api `
    -Old $focusCall `
    -New $focusCallPatched `
    -Label "Camera1_api force60Fps before startRecord"

$saveInternalPattern = '(\.method public startRecordSaveInternal\(IIIIFI\)V\s+\.locals 7\s+\.line 1\s+)iput p4, p0, Lcom/jcr/android/smoothcam/cameraapichange/Camera1_api;->rctype:I'
$saveInternalReplacement = '${1}' + "invoke-direct {p0}, Lcom/jcr/android/smoothcam/cameraapichange/Camera1_api;->force60Fps()V`n`n    iput p4, p0, Lcom/jcr/android/smoothcam/cameraapichange/Camera1_api;->rctype:I"

Replace-RegexOnce `
    -RelativePath $camera1Api `
    -Pattern $saveInternalPattern `
    -Replacement $saveInternalReplacement `
    -AlreadyPattern '\.method public startRecordSaveInternal\(IIIIFI\)V.*?force60Fps\(\)V.*?\.end method' `
    -Label "Camera1_api force60Fps before startRecordSaveInternal"

if (-not $SkipUiText) {
    Replace-Literal -RelativePath $cameraActivity -Old "1280x720 30fps" -New "1280x720 60fps" -Label "CameraActivity 720p label"
    Replace-Literal -RelativePath $cameraActivity -Old "1920x1080 30fps" -New "1920x1080 60fps" -Label "CameraActivity 1080p label"
    Replace-Literal -RelativePath $cameraActivity -Old "%dx%d 30fps" -New "%dx%d 60fps" -Label "CameraActivity dynamic label"
    Replace-Literal -RelativePath $resolutionAdapter -Old "%s 30fps" -New "%s 60fps" -Label "ResolutionAdapter label"
    Replace-Literal -RelativePath $cameraConstants -Old " 30fps" -New " 60fps" -Label "CameraConstants labels"
    Replace-Literal -RelativePath $cameraConstants -Old "  30fps" -New "  60fps" -Label "CameraConstants double-space labels"
}

Assert-Contains -RelativePath $textureEncoder -Needle ".field private static final FRAME_RATE:I = 0x3c" -Label "TextureMovieEncoder FRAME_RATE=60"
Assert-Contains -RelativePath $textureEncoder -Needle "const/high16 v1, 0x42700000    # 60.0f" -Label "TextureMovieEncoder float=60"
Assert-Contains -RelativePath $textureEncoder -Needle 'const-string v5, "frame-rate"' -Label "TextureMovieEncoder frame-rate key still present"
Assert-Contains -RelativePath $videoManager -Needle "invoke-virtual {v1, v2}, Landroid/media/MediaRecorder;->setVideoFrameRate(I)V" -Label "VideoManager setVideoFrameRate present"
Assert-Contains -RelativePath $camera1Api -Needle ".method private force60Fps()V" -Label "Camera1_api force60Fps method present"
Assert-Contains -RelativePath $camera1Api -Needle "const v1, 0xea60" -Label "Camera1_api preview fps range=60000"

Write-Host "Patch complete. Files changed: $script:changeCount"
