# Adds the KPI-card measures to the semantic model (_Measures table, TMDL):
#   - on-time split: On-Time Pickup %, On-Time Delivery %, Late Stops %, Early Stops %
#   - for every KPI in tools/kpi_catalog.json:
#       '<KPI> YoY Change'   numeric change, latest year in the selection vs the year before (hidden)
#       '<KPI> vs LY'        card text, e.g. "2024: ▲ 1.2% vs 2023"
#       '<KPI> vs LY Color'  green when the change is good, red when bad, grey when none
#       '<KPI> Target'       and '<KPI> Target Color' when the KPI has a target
# Re-running replaces the measures it created, so edit kpi_catalog.json and run again.
# Close Power BI Desktop first.
#   powershell -ExecutionPolicy Bypass -File tools\build_kpi_measures.ps1 -Repo .
param([string]$Repo = '.')
$ErrorActionPreference = 'Stop'
Set-Location $Repo
$enc = New-Object System.Text.UTF8Encoding($false)
$file = (Resolve-Path 'TSA_capstone.SemanticModel\definition\tables\_Measures.tmdl').Path
$catalog = (Get-Content 'tools\kpi_catalog.json' -Raw -Encoding UTF8 | ConvertFrom-Json).kpis

$GOOD = '#059669'; $BAD = '#DC2626'; $NEUTRAL = '#64748B'
$UP = [string][char]0x25B2; $DOWN = [string][char]0x25BC

# Stable lineage tags (same name -> same GUID) keep diffs small between runs
$md5 = [Security.Cryptography.MD5]::Create()
function Tag($name) { ([guid]::new($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes("sij-kpi:$name")))).ToString() }

$blocks = New-Object System.Collections.Generic.List[string]
$names = New-Object System.Collections.Generic.List[string]
function AddMeasure($name, $dax, $format, $folder, [switch]$hidden) {
  $lines = @("`tmeasure '$name' =")
  foreach ($l in ($dax.Trim() -split "`r?`n")) { $lines += "`t`t`t$($l.TrimEnd())" }
  if ($format) { $lines += "`t`tformatString: $format" }
  $lines += "`t`tdisplayFolder: $folder"
  if ($hidden) { $lines += "`t`tisHidden" }
  $lines += "`t`tlineageTag: $(Tag $name)"
  $script:blocks.Add(($lines -join "`r`n")); $script:names.Add($name)
}

# ---------- On-time split (industry standard: pickup and delivery separately, early vs late)
AddMeasure 'On-Time Pickup %' @'
CALCULATE ( [On-Time %], delivery_events[event_type] = "Pickup" )
'@ '0.0%' 'Service'
AddMeasure 'On-Time Delivery %' @'
CALCULATE ( [On-Time %], delivery_events[event_type] = "Delivery" )
'@ '0.0%' 'Service'
AddMeasure 'Late Stops %' @'
DIVIDE (
    COUNTROWS (
        FILTER (
            delivery_events,
            NOT delivery_events[on_time_flag]
                && delivery_events[actual_datetime] > delivery_events[scheduled_datetime]
        )
    ),
    COUNTROWS ( delivery_events )
)
'@ '0.0%' 'Service'
AddMeasure 'Early Stops %' @'
-- Stops outside the 2-hour window because they arrived early, not late
DIVIDE (
    COUNTROWS (
        FILTER (
            delivery_events,
            NOT delivery_events[on_time_flag]
                && delivery_events[actual_datetime] < delivery_events[scheduled_datetime]
        )
    ),
    COUNTROWS ( delivery_events )
)
'@ '0.0%' 'Service'

# ---------- Year-on-year comparison and targets for each KPI
foreach ($k in $catalog) {
  $m = $k.measure
  if ($k.points) { $change = '_cur - _prev'; $text = 'FORMAT ( ABS ( _change ) * 100, "0.0" ) & " pts"' }
  else { $change = 'DIVIDE ( _cur - _prev, _prev )'; $text = 'FORMAT ( ABS ( _change ), "0.0%" )' }
  $goodWhen = if ($k.higherIsBetter) { '_change > 0' } else { '_change < 0' }

  AddMeasure "$m YoY Change" @"
-- Latest year in the current selection compared with the year before it.
-- Month and quarter selections are kept, so March 2024 is compared with March 2023.
VAR _year = MAX ( 'Calendar'[Year] )
VAR _cur = CALCULATE ( [$m], 'Calendar'[Year] = _year )
VAR _prev = CALCULATE ( [$m], 'Calendar'[Year] = _year - 1 )
RETURN
    IF ( ISBLANK ( _cur ) || ISBLANK ( _prev ), BLANK (), $change )
"@ $(if ($k.points) { '0.0%' } else { '0.0%' }) 'KPI Comparison' -hidden

  AddMeasure "$m vs LY" @"
VAR _year = MAX ( 'Calendar'[Year] )
VAR _change = [$m YoY Change]
VAR _prefix = IF ( HASONEVALUE ( 'Calendar'[Year] ), "", _year & ": " )
RETURN
    IF (
        ISBLANK ( _change ),
        "No prior year to compare",
        IF (
            ROUND ( _change, 4 ) = 0,
            _prefix & "No change vs " & ( _year - 1 ),
            _prefix & IF ( _change > 0, "$UP ", "$DOWN " ) & $text & " vs " & ( _year - 1 )
        )
    )
"@ $null 'KPI Comparison'

  AddMeasure "$m vs LY Color" @"
VAR _change = [$m YoY Change]
RETURN
    IF ( ISBLANK ( _change ) || ROUND ( _change, 4 ) = 0, "$NEUTRAL", IF ( $goodWhen, "$GOOD", "$BAD" ) )
"@ $null 'KPI Comparison'

  if ($null -ne $k.target) {
    $t = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $k.target)
    $fmt = if ($k.points) { '0.0%' } elseif ($k.target -lt 10) { '0.00' } else { '#,0' }
    $meets = if ($k.higherIsBetter) { '_value >= [' + $m + ' Target]' } else { '_value <= [' + $m + ' Target]' }
    AddMeasure "$m Target" $t $fmt 'KPI Targets'
    AddMeasure "$m Target Color" @"
VAR _value = [$m]
RETURN
    IF ( ISBLANK ( _value ), "$NEUTRAL", IF ( $meets, "$GOOD", "$BAD" ) )
"@ $null 'KPI Targets'
  }
}

# ---------- Rewrite _Measures.tmdl: drop earlier copies, insert before the placeholder column
$src = [IO.File]::ReadAllText($file)
$anchor = "`tcolumn _placeholder"
$cut = $src.IndexOf($anchor)
if ($cut -lt 0) { throw 'placeholder column not found' }
$head = $src.Substring(0, $cut); $tail = $src.Substring($cut)
$parts = [regex]::Split($head, "(?m)(?=^\tmeasure )")
$keep = foreach ($p in $parts) {
  $mm = [regex]::Match($p, "^\tmeasure '?(.+?)'? =")
  if ($mm.Success -and $names.Contains($mm.Groups[1].Value)) { continue }
  $p
}
$body = (($keep -join '').TrimEnd() + "`r`n`r`n" + ($blocks -join "`r`n`r`n") + "`r`n`r`n")
[IO.File]::WriteAllText($file, $body + $tail, $enc)
"Wrote $($names.Count) measures to _Measures.tmdl"
