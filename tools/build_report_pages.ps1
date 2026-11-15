param([string]$Repo)
$ErrorActionPreference = 'Stop'
Set-Location $Repo
$enc = New-Object System.Text.UTF8Encoding($false)
$PAGES = "TSA_capstone.Report\definition\pages"
$VC = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.4.0/schema.json'
$PG = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
$PGS = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json'

function JStr($s) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '"'  { [void]$sb.Append('\"') }
      '\'  { [void]$sb.Append('\\') }
      "`n" { [void]$sb.Append('\n') }
      "`r" { [void]$sb.Append('\r') }
      "`t" { [void]$sb.Append('\t') }
      default { [void]$sb.Append($ch) }
    }
  }
  [void]$sb.Append('"'); $sb.ToString()
}
function ToJson($o, [int]$lvl) {
  $pad = '  ' * ($lvl + 1); $end = '  ' * $lvl
  if ($null -eq $o) { return 'null' }
  if ($o -is [string]) { return (JStr $o) }
  if ($o -is [bool]) { if ($o) { return 'true' } else { return 'false' } }
  if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $o) }
  if ($o -is [System.Collections.IDictionary]) {
    if ($o.Count -eq 0) { return '{}' }
    $parts = foreach ($k in $o.Keys) { $pad + (JStr ([string]$k)) + ': ' + (ToJson $o[$k] ($lvl + 1)) }
    return "{`n" + ($parts -join ",`n") + "`n$end}"
  }
  if ($o -is [System.Collections.IEnumerable]) {
    $items = @($o)
    if ($items.Count -eq 0) { return '[]' }
    $parts = foreach ($i in $items) { $pad + (ToJson $i ($lvl + 1)) }
    return "[`n" + ($parts -join ",`n") + "`n$end]"
  }
  throw "Unsupported type: $($o.GetType())"
}
function Save($path, $obj) {
  $dir = Split-Path $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
  [IO.File]::WriteAllText($path, ((ToJson $obj 0) + "`n").Replace("`n", "`r`n"), $enc)
}
# M "Total Revenue"  -> measure in _Measures ;  C "customers" "customer_name" -> column
function M($name) { @{ kind = 'Measure'; entity = '_Measures'; prop = $name } }
function C($entity, $prop) { @{ kind = 'Column'; entity = $entity; prop = $prop } }
function Field($f) { @{ $f.kind = @{ Expression = @{ SourceRef = @{ Entity = $f.entity } }; Property = $f.prop } } }
function Proj($f) { @{ field = (Field $f); queryRef = "$($f.entity).$($f.prop)"; nativeQueryRef = $f.prop } }
function Lit($v) { @{ expr = @{ Literal = @{ Value = $v } } } }

$script:vis = @()
function Visual($page, $id, $type, $x, $y, $w, $h, $roles, $title, $sortBy) {
  $qs = [ordered]@{}
  foreach ($r in $roles.Keys) { $qs[$r] = @{ projections = @($roles[$r] | ForEach-Object { Proj $_ }) } }
  $query = [ordered]@{ queryState = $qs }
  if ($sortBy) { $query.sortDefinition = @{ sort = @(@{ field = (Field $sortBy); direction = 'Descending' }); isDefaultSort = $true } }
  $v = [ordered]@{ visualType = $type; query = $query; drillFilterOtherVisuals = $true }
  if ($title) {
    $v.visualContainerObjects = @{ title = @(@{ properties = @{ show = (Lit 'true'); text = (Lit "'$title'") } }) }
  }
  $script:z += 1000
  $obj = [ordered]@{
    '$schema' = $VC; name = $id
    position = [ordered]@{ x = $x; y = $y; z = $script:z; width = $w; height = $h; tabOrder = $script:z }
    visual = $v
  }
  Save "$PAGES\$page\visuals\$id\visual.json" $obj
  $script:vis += [pscustomobject]@{ page = $page; id = $id; type = $type; fields = @($roles.Values | ForEach-Object { $_ }) }
}
function Cards($page, $prefix, $measures, $titles) {
  $n = $measures.Count; $gap = 10; $w = [math]::Floor((1040 - ($n - 1) * $gap) / $n)
  for ($i = 0; $i -lt $n; $i++) {
    Visual $page "$prefix$i" 'card' (10 + $i * ($w + $gap)) 10 $w 100 @{ Values = @((M $measures[$i])) } $titles[$i] $null
  }
}
function YearSlicer($page, $id) {
  Visual $page $id 'slicer' 1060 10 210 100 @{ Values = @((C 'Calendar' 'Year')) } 'Year' $null
}
function Page($name, $display) {
  $script:z = 0
  Save "$PAGES\$name\page.json" ([ordered]@{ '$schema' = $PG; name = $name; displayName = $display; displayOption = 'FitToPage'; height = 720; width = 1280 })
}

# Remove previously generated visuals so the script can be re-run
Get-ChildItem $PAGES -Directory | ForEach-Object { if (Test-Path "$($_.FullName)\visuals") { Remove-Item "$($_.FullName)\visuals" -Recurse -Force } }

# ---------------- Executive overview (reuses the existing blank page) ----------------
$p = 'b388af99db000d0b50c6'; Page $p 'Executive Overview'
Cards $p 'execCard' @('Total Revenue','Total Loads','Profit Margin %','On-Time %','Incidents per 100 Trips') @('Total Revenue','Total Loads','Profit Margin (fuel + maintenance only)','On-Time Delivery %','Incidents per 100 Trips')
YearSlicer $p 'execYear'
Visual $p 'execTrend' 'lineChart' 10 120 820 290 ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Total Revenue'), (M 'Total Operating Cost')) }) 'Revenue vs Operating Cost by Month' $null
Visual $p 'execType' 'clusteredBarChart' 840 120 430 290 ([ordered]@{ Category = @((C 'customers' 'customer_type')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer Type' (M 'Total Revenue')
Visual $p 'execCost' 'clusteredColumnChart' 10 420 620 290 ([ordered]@{ Category = @((C 'Calendar' 'Year')); Y = @((M 'Total Fuel Cost'), (M 'Total Maintenance Cost'), (M 'Total Claim Amount')) }) 'Cost Mix by Year' $null
Visual $p 'execOnTime' 'lineChart' 640 420 630 290 ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null

# ---------------- Customers ----------------
$p = 'customers01'; Page $p 'Customers'
Cards $p 'custCard' @('Active Customers','Total Revenue','Avg Revenue per Load','Revenue vs Potential %') @('Active Customers','Total Revenue','Avg Revenue per Load','Revenue vs Annual Potential')
YearSlicer $p 'custYear'
Visual $p 'custTop' 'clusteredBarChart' 10 120 520 590 ([ordered]@{ Category = @((C 'customers' 'customer_name')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer' (M 'Total Revenue')
Visual $p 'custFreight' 'clusteredColumnChart' 540 120 730 250 ([ordered]@{ Category = @((C 'customers' 'primary_freight_type')); Y = @((M 'Avg Revenue per Load')) }) 'Avg Revenue per Load by Freight Type' (M 'Avg Revenue per Load')
Visual $p 'custTable' 'tableEx' 540 380 730 330 ([ordered]@{ Values = @((C 'customers' 'customer_name'), (C 'customers' 'customer_type'), (C 'customers' 'account_status'), (M 'Total Revenue'), (M 'Customer Revenue Share %'), (M 'Revenue vs Potential %'), (M 'On-Time %'), (M 'Margin after Fuel %')) }) 'Customer Scorecard' (M 'Total Revenue')

# ---------------- Fleet ----------------
$p = 'fleet01'; Page $p 'Fleet'
Cards $p 'fleetCard' @('Active Trucks','Active Drivers','Avg Utilization Rate','Avg MPG','Idle %') @('Active Trucks','Active Drivers','Avg Utilization','Avg MPG','Idle Time %')
YearSlicer $p 'fleetYear'
Visual $p 'fleetMake' 'clusteredBarChart' 10 120 410 290 ([ordered]@{ Category = @((C 'trucks' 'make')); Y = @((M 'Avg Utilization Rate')) }) 'Utilization by Make' (M 'Avg Utilization Rate')
Visual $p 'fleetYearModel' 'clusteredColumnChart' 430 120 420 290 ([ordered]@{ Category = @((C 'trucks' 'model_year')); Y = @((M 'Maintenance Cost per Mile')) }) 'Maintenance Cost per Mile by Model Year' $null
Visual $p 'fleetDrivers' 'clusteredBarChart' 860 120 410 290 ([ordered]@{ Category = @((C 'drivers' 'home_terminal')); Y = @((M 'Avg MPG')) }) 'MPG by Driver Home Terminal' (M 'Avg MPG')
Visual $p 'fleetTable' 'tableEx' 10 420 1260 290 ([ordered]@{ Values = @((C 'trucks' 'unit_number'), (C 'trucks' 'make'), (C 'trucks' 'model_year'), (M 'Total Miles'), (M 'Avg MPG'), (M 'Idle %'), (M 'Total Maintenance Cost'), (M 'Maintenance Cost per Mile'), (M 'Downtime Hours'), (M 'Avg Utilization Rate')) }) 'Truck Scorecard' (M 'Total Maintenance Cost')

# ---------------- Service ----------------
$p = 'service01'; Page $p 'Service'
Cards $p 'svcCard' @('On-Time %','Avg Detention (min)','Avg Actual Transit Days','Avg Planned Transit Days','Preventable Incident %') @('On-Time Delivery %','Avg Detention (min)','Actual Transit Days','Planned Transit Days','Preventable Incidents %')
YearSlicer $p 'svcYear'
Visual $p 'svcTrend' 'lineChart' 10 120 620 290 ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null
Visual $p 'svcFacility' 'clusteredBarChart' 640 120 630 290 ([ordered]@{ Category = @((C 'facilities' 'facility_name')); Y = @((M 'Avg Detention (min)')) }) 'Avg Detention by Facility (min)' (M 'Avg Detention (min)')
Visual $p 'svcRoutes' 'tableEx' 10 420 820 290 ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Loads'), (M 'On-Time %'), (M 'Avg Actual Transit Days'), (M 'Avg Planned Transit Days')) }) 'Route Service Levels' (M 'Total Loads')
Visual $p 'svcIncidents' 'clusteredBarChart' 840 420 430 290 ([ordered]@{ Category = @((C 'safety_incidents' 'incident_type')); Y = @((M 'Total Safety Incidents')) }) 'Safety Incidents by Type' (M 'Total Safety Incidents')

# ---------------- Cost ----------------
$p = 'cost01'; Page $p 'Cost'
Cards $p 'costCard' @('Total Operating Cost','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price per Gallon','Profit') @('Operating Cost (fuel + maintenance)','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price / Gallon','Profit (fuel + maintenance only)')
YearSlicer $p 'costYear'
Visual $p 'costTrend' 'lineChart' 10 120 620 290 ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Cost per Mile'), (M 'Fuel Cost per Mile')) }) 'Cost per Mile by Month' $null
Visual $p 'costState' 'clusteredBarChart' 640 120 630 290 ([ordered]@{ Category = @((C 'fuel_purchases' 'location_state')); Y = @((M 'Avg Fuel Price per Gallon')) }) 'Fuel Price per Gallon by State' (M 'Avg Fuel Price per Gallon')
Visual $p 'costRoutes' 'tableEx' 10 420 1260 290 ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Revenue'), (M 'Revenue per Mile'), (M 'Total Fuel Cost'), (M 'Margin after Fuel'), (M 'Margin after Fuel %')) }) 'Route Margin after Fuel' (M 'Margin after Fuel')

# ---------------- Page order ----------------
Save "$PAGES\pages.json" ([ordered]@{ '$schema' = $PGS; pageOrder = @('b388af99db000d0b50c6','customers01','fleet01','service01','cost01'); activePageName = 'b388af99db000d0b50c6' })

# Emit a field list for validation
$script:vis | ForEach-Object { foreach ($f in $_.fields) { "{0}|{1}|{2}|{3}|{4}" -f $_.page, $_.id, $f.kind, $f.entity, $f.prop } }
