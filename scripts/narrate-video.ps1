# Optional local production tool; no network service or paid voice dependency.
param([string]$OutputDirectory = '.local/video/audio')
$ErrorActionPreference = 'Stop'
$apxtmNarration = Get-Content -LiteralPath 'media/narration.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$apxtmOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
[IO.Directory]::CreateDirectory($apxtmOutput) | Out-Null
$apxtmVoice = New-Object -ComObject SAPI.SpVoice
$apxtmEnglish = @($apxtmVoice.GetVoices() | Where-Object { $_.GetDescription() -like '*Zira*' })
if ($apxtmEnglish.Count -ne 1) { throw 'An installed Microsoft Zira English voice is required; no voice is downloaded.' }
$apxtmVoice.Voice = $apxtmEnglish[0]
$apxtmVoice.Rate = 0
$apxtmNumber = 0
foreach ($apxtmChapter in $apxtmNarration.chapters) {
  foreach ($apxtmCaption in $apxtmChapter.captions) {
    $apxtmNumber++
    $apxtmFilename = Join-Path $apxtmOutput ('{0:d2}.wav' -f $apxtmNumber)
    $apxtmStream = New-Object -ComObject SAPI.SpFileStream
    try {
      $apxtmStream.Open($apxtmFilename, 3, $false)
      $apxtmVoice.AudioOutputStream = $apxtmStream
      $apxtmVoice.Speak([string]$apxtmCaption) | Out-Null
    } finally { $apxtmStream.Close() }
  }
}
Write-Output ('Generated {0} original caption/narration WAV files with an installed English voice.' -f $apxtmNumber)
