# Generates the TSA_capstone report pages (PBIR) from the semantic model's measures.
# Close Power BI Desktop before running, then reopen TSA_capstone.pbip.
#   powershell -ExecutionPolicy Bypass -File tools\build_report_pages.ps1 -Repo .
param([string]$Repo = '.')
$ErrorActionPreference = 'Stop'
Set-Location $Repo
$enc = New-Object System.Text.UTF8Encoding($false)
$PAGES = "TSA_capstone.Report\definition\pages"
$VC = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.4.0/schema.json'
$PG = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
$PGS = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json'

# ---------- JSON writer (2-space indent, CRLF, no BOM) ----------
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

# ---------- Field helpers ----------
# M "Total Revenue" -> measure in _Measures;  C "customers" "customer_name" -> column
function M($name) { @{ kind = 'Measure'; entity = '_Measures'; prop = $name } }
function C($entity, $prop) { @{ kind = 'Column'; entity = $entity; prop = $prop } }
function Field($f) { @{ $f.kind = @{ Expression = @{ SourceRef = @{ Entity = $f.entity } }; Property = $f.prop } } }
function Proj($f) { [ordered]@{ field = (Field $f); queryRef = "$($f.entity).$($f.prop)"; nativeQueryRef = $f.prop } }
function Lit($v) { @{ expr = @{ Literal = @{ Value = $v } } } }
function Title($text) { @{ title = @(@{ properties = [ordered]@{ show = (Lit 'true'); text = (Lit "'$text'") } }) } }

# ---------- Visual builders ----------
$script:vis = @()
function Emit($page, $id, $x, $y, $w, $h, $visual, $fields) {
  $script:z += 1000
  $obj = [ordered]@{
    '$schema' = $VC; name = $id
    position = [ordered]@{ x = $x; y = $y; z = $script:z; width = $w; height = $h; tabOrder = $script:z }
    visual = $visual
  }
  Save "$PAGES\$page\visuals\$id\visual.json" $obj
  $script:vis += [pscustomobject]@{ page = $page; id = $id; fields = @($fields) }
}
function Visual($page, $id, $type, $x, $y, $w, $h, $roles, $title, $sortBy) {
  $qs = [ordered]@{}
  foreach ($r in $roles.Keys) { $qs[$r] = @{ projections = @($roles[$r] | ForEach-Object { Proj $_ }) } }
  $query = [ordered]@{ queryState = $qs }
  if ($sortBy) { $query.sortDefinition = [ordered]@{ sort = @([ordered]@{ field = (Field $sortBy); direction = 'Descending' }); isDefaultSort = $true } }
  $v = [ordered]@{ visualType = $type; query = $query; drillFilterOtherVisuals = $true }
  if ($title) { $v.visualContainerObjects = (Title $title) }
  Emit $page $id $x $y $w $h $v @($roles.Values | ForEach-Object { $_ })
}

# Layout grid (1280 x 720 canvas)
$NAV_Y = 8;    $NAV_H = 40      # page navigation bar
$KPI_Y = 56;   $KPI_H = 88      # KPI cards, shown first under the nav bar
$SLC_Y = 152;  $SLC_H = 56      # slicer panel
$R1_Y = 216;   $R1_H = 243      # chart row 1
$R2_Y = 467;   $R2_H = 245      # chart row 2
$FULL_W = 1260; $GAP = 10

# Navigation bar: Power BI's page navigator lists every page and highlights
# the current one, so each page links to all the others.
function NavBar($page) {
  $v = [ordered]@{ visualType = 'pageNavigator'; drillFilterOtherVisuals = $true }
  Emit $page "${page}_nav" 10 $NAV_Y $FULL_W $NAV_H $v @()
}
function Cards($page, $measures, $titles) {
  $n = $measures.Count; $w = [math]::Floor(($FULL_W - ($n - 1) * $GAP) / $n)
  for ($i = 0; $i -lt $n; $i++) {
    Visual $page "${page}_kpi$i" 'card' (10 + $i * ($w + $GAP)) $KPI_Y $w $KPI_H @{ Values = @((M $measures[$i])) } $titles[$i] $null
  }
}
# Slicer panel: Year, Quarter and Month are synced across all pages, so a date
# selection carries over when you move between pages; two page-specific slicers follow.
function Slicers($page, $extra) {
  $list = @(
    @{ f = (C 'Calendar' 'Year');    t = 'Year';    sync = 'SyncYear' },
    @{ f = (C 'Calendar' 'Quarter'); t = 'Quarter'; sync = 'SyncQuarter' },
    @{ f = (C 'Calendar' 'Month');   t = 'Month';   sync = 'SyncMonth' }
  ) + $extra
  $n = $list.Count; $w = [math]::Floor(($FULL_W - ($n - 1) * $GAP) / $n)
  for ($i = 0; $i -lt $n; $i++) {
    $s = $list[$i]
    $v = [ordered]@{
      visualType = 'slicer'
      query = [ordered]@{ queryState = [ordered]@{ Values = @{ projections = @((Proj $s.f)) } } }
      objects = @{ data = @(@{ properties = @{ mode = (Lit "'Dropdown'") } }) }
      visualContainerObjects = (Title $s.t)
      drillFilterOtherVisuals = $true
    }
    if ($s.sync) { $v.syncGroup = [ordered]@{ groupName = $s.sync; fieldChanges = $true; filterChanges = $true } }
    Emit $page "${page}_slicer$i" (10 + $i * ($w + $GAP)) $SLC_Y $w $SLC_H $v @($s.f)
  }
}
function Page($name, $display) {
  $script:z = 0
  Save "$PAGES\$name\page.json" ([ordered]@{ '$schema' = $PG; name = $name; displayName = $display; displayOption = 'FitToPage'; height = 720; width = 1280 })
  NavBar $name
}

# Remove previously generated pages so the script can be re-run
Get-ChildItem $PAGES -Directory | ForEach-Object { if (Test-Path "$($_.FullName)\visuals") { Remove-Item "$($_.FullName)\visuals" -Recurse -Force } }

# ---------------- Executive Overview (reuses the original blank page) ----------------
$p = 'b388af99db000d0b50c6'; Page $p 'Executive Overview'
Cards $p @('Total Revenue','Total Loads','Profit Margin %','On-Time %','Incidents per 100 Trips','Cost per Mile') @('Total Revenue','Total Loads','Profit Margin (fuel + maint. only)','On-Time Delivery %','Incidents per 100 Trips','Cost per Mile')
Slicers $p @(@{ f = (C 'customers' 'customer_type'); t = 'Customer Type' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'execTrend' 'lineChart' 10 $R1_Y 820 $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Total Revenue'), (M 'Total Operating Cost')) }) 'Revenue vs Operating Cost by Month' $null
Visual $p 'execType' 'clusteredBarChart' 840 $R1_Y 430 $R1_H ([ordered]@{ Category = @((C 'customers' 'customer_type')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer Type' (M 'Total Revenue')
Visual $p 'execCost' 'clusteredColumnChart' 10 $R2_Y 620 $R2_H ([ordered]@{ Category = @((C 'Calendar' 'Year')); Y = @((M 'Total Fuel Cost'), (M 'Total Maintenance Cost'), (M 'Total Claim Amount')) }) 'Cost Mix by Year' $null
Visual $p 'execOnTime' 'lineChart' 640 $R2_Y 630 $R2_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null

# ---------------- Customers ----------------
$p = 'customers01'; Page $p 'Customers'
Cards $p @('Active Customers','Total Revenue','Total Billed Revenue','Avg Revenue per Load','Revenue vs Potential %','Margin after Fuel %') @('Active Customers','Total Revenue','Billed Revenue (incl. surcharges)','Avg Revenue per Load','Revenue vs Annual Potential','Margin after Fuel %')
Slicers $p @(@{ f = (C 'customers' 'customer_type'); t = 'Customer Type' }, @{ f = (C 'customers' 'account_status'); t = 'Account Status' })
Visual $p 'custTop' 'clusteredBarChart' 10 $R1_Y 520 ($R1_H + $GAP + $R2_H - 2) ([ordered]@{ Category = @((C 'customers' 'customer_name')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer' (M 'Total Revenue')
Visual $p 'custFreight' 'clusteredColumnChart' 540 $R1_Y 730 $R1_H ([ordered]@{ Category = @((C 'customers' 'primary_freight_type')); Y = @((M 'Avg Revenue per Load')) }) 'Avg Revenue per Load by Freight Type' (M 'Avg Revenue per Load')
Visual $p 'custTable' 'tableEx' 540 $R2_Y 730 $R2_H ([ordered]@{ Values = @((C 'customers' 'customer_name'), (C 'customers' 'customer_type'), (C 'customers' 'account_status'), (M 'Total Revenue'), (M 'Customer Revenue Share %'), (M 'Revenue vs Potential %'), (M 'On-Time %'), (M 'Margin after Fuel %')) }) 'Customer Scorecard' (M 'Total Revenue')

# ---------------- Fleet ----------------
$p = 'fleet01'; Page $p 'Fleet'
Cards $p @('Active Trucks','Active Drivers','Avg Utilization Rate','Avg MPG','Idle %','Downtime Hours') @('Active Trucks','Active Drivers','Avg Utilization','Avg MPG','Idle Time %','Downtime Hours')
Slicers $p @(@{ f = (C 'trucks' 'make'); t = 'Truck Make' }, @{ f = (C 'drivers' 'home_terminal'); t = 'Home Terminal' })
Visual $p 'fleetMake' 'clusteredBarChart' 10 $R1_Y 410 $R1_H ([ordered]@{ Category = @((C 'trucks' 'make')); Y = @((M 'Avg Utilization Rate')) }) 'Utilization by Make' (M 'Avg Utilization Rate')
Visual $p 'fleetYearModel' 'clusteredColumnChart' 430 $R1_Y 420 $R1_H ([ordered]@{ Category = @((C 'trucks' 'model_year')); Y = @((M 'Maintenance Cost per Mile')) }) 'Maintenance Cost per Mile by Model Year' $null
Visual $p 'fleetDrivers' 'clusteredBarChart' 860 $R1_Y 410 $R1_H ([ordered]@{ Category = @((C 'drivers' 'home_terminal')); Y = @((M 'Avg MPG')) }) 'MPG by Driver Home Terminal' (M 'Avg MPG')
Visual $p 'fleetTable' 'tableEx' 10 $R2_Y $FULL_W $R2_H ([ordered]@{ Values = @((C 'trucks' 'unit_number'), (C 'trucks' 'make'), (C 'trucks' 'model_year'), (M 'Total Miles'), (M 'Avg MPG'), (M 'Idle %'), (M 'Total Maintenance Cost'), (M 'Maintenance Cost per Mile'), (M 'Downtime Hours'), (M 'Avg Utilization Rate')) }) 'Truck Scorecard' (M 'Total Maintenance Cost')

# ---------------- Service ----------------
$p = 'service01'; Page $p 'Service'
Cards $p @('On-Time %','Avg Detention (min)','Avg Actual Transit Days','Avg Planned Transit Days','Incidents per Million Miles','Preventable Incident %') @('On-Time Delivery %','Avg Detention (min)','Actual Transit Days','Planned Transit Days','Incidents per Million Miles','Preventable Incidents %')
Slicers $p @(@{ f = (C 'facilities' 'facility_type'); t = 'Facility Type' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'svcTrend' 'lineChart' 10 $R1_Y 620 $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null
Visual $p 'svcFacility' 'clusteredBarChart' 640 $R1_Y 630 $R1_H ([ordered]@{ Category = @((C 'facilities' 'facility_name')); Y = @((M 'Avg Detention (min)')) }) 'Avg Detention by Facility (min)' (M 'Avg Detention (min)')
Visual $p 'svcRoutes' 'tableEx' 10 $R2_Y 820 $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Loads'), (M 'On-Time %'), (M 'Avg Actual Transit Days'), (M 'Avg Planned Transit Days')) }) 'Route Service Levels' (M 'Total Loads')
Visual $p 'svcIncidents' 'clusteredBarChart' 840 $R2_Y 430 $R2_H ([ordered]@{ Category = @((C 'safety_incidents' 'incident_type')); Y = @((M 'Total Safety Incidents')) }) 'Safety Incidents by Type' (M 'Total Safety Incidents')

# ---------------- Cost ----------------
$p = 'cost01'; Page $p 'Cost'
Cards $p @('Total Operating Cost','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price per Gallon','Total Claim Amount','Profit') @('Operating Cost (fuel + maint.)','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price / Gallon','Incident Claims','Profit (fuel + maint. only)')
Slicers $p @(@{ f = (C 'fuel_purchases' 'location_state'); t = 'Fuel State' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'costTrend' 'lineChart' 10 $R1_Y 620 $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Cost per Mile'), (M 'Fuel Cost per Mile')) }) 'Cost per Mile by Month' $null
Visual $p 'costState' 'clusteredBarChart' 640 $R1_Y 630 $R1_H ([ordered]@{ Category = @((C 'fuel_purchases' 'location_state')); Y = @((M 'Avg Fuel Price per Gallon')) }) 'Fuel Price per Gallon by State' (M 'Avg Fuel Price per Gallon')
Visual $p 'costRoutes' 'tableEx' 10 $R2_Y $FULL_W $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Revenue'), (M 'Revenue per Mile'), (M 'Total Fuel Cost'), (M 'Margin after Fuel'), (M 'Margin after Fuel %')) }) 'Route Margin after Fuel' (M 'Margin after Fuel')

# ---------------- Page order ----------------
Save "$PAGES\pages.json" ([ordered]@{ '$schema' = $PGS; pageOrder = @('b388af99db000d0b50c6','customers01','fleet01','service01','cost01'); activePageName = 'b388af99db000d0b50c6' })

# Emit a field list for validation
$script:vis | ForEach-Object { foreach ($f in $_.fields) { if ($f) { "{0}|{1}|{2}|{3}|{4}" -f $_.page, $_.id, $f.kind, $f.entity, $f.prop } } }
