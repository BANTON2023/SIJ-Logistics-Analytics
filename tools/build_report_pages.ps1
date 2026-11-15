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

# ---------- Field and formatting helpers ----------
# M "Total Revenue" -> measure in _Measures;  C "customers" "customer_name" -> column
function M($name) { @{ kind = 'Measure'; entity = '_Measures'; prop = $name } }
function C($entity, $prop) { @{ kind = 'Column'; entity = $entity; prop = $prop } }
function Field($f) { @{ $f.kind = @{ Expression = @{ SourceRef = @{ Entity = $f.entity } }; Property = $f.prop } } }
function Proj($f) { [ordered]@{ field = (Field $f); queryRef = "$($f.entity).$($f.prop)"; nativeQueryRef = $f.prop } }
function Lit($v) { @{ expr = @{ Literal = @{ Value = $v } } } }
function Col($hex) { @{ solid = @{ color = (Lit "'$hex'") } } }
# Formatting objects are arrays in PBIR. PowerShell unwraps a one-item array when
# a function returns it, so these helpers return with the unary comma (,@(...)).
function Off() { , @(@{ properties = @{ show = (Lit 'false') } }) }
function Title($text, $color) {
  $props = [ordered]@{ show = (Lit 'true'); text = (Lit "'$text'") }
  if ($color) { $props.fontColor = (Col $color) }
  , @(@{ properties = $props })
}
# Container with no card styling (used on the sidebar)
function Bare() { [ordered]@{ background = (Off); border = (Off); dropShadow = (Off) } }

# Palette (matches StaticResources/RegisteredResources/SIJ_Logistics_Theme.json)
$NAVY = '#0F2A44'; $NAVY_HOVER = '#1E3A5F'; $TEAL = '#14A3A3'; $AMBER = '#F59E0B'
$WHITE = '#FFFFFF'; $MUTED = '#CBD5E1'; $INK = '#0F2A44'; $SUBTLE = '#64748B'

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
  if ($title) { $v.visualContainerObjects = @{ title = (Title $title $null) } }
  Emit $page $id $x $y $w $h $v @($roles.Values | ForEach-Object { $_ })
}
function TextBox($page, $id, $x, $y, $w, $h, $runs) {
  $paras = @($runs | ForEach-Object { @{ textRuns = @(@{ value = $_.t; textStyle = [ordered]@{ fontFamily = $_.font; fontSize = $_.size; color = $_.color } }) } })
  $v = [ordered]@{
    visualType = 'textbox'
    objects = @{ general = @(@{ properties = @{ paragraphs = $paras } }) }
    visualContainerObjects = (Bare)
    drillFilterOtherVisuals = $true
  }
  Emit $page $id $x $y $w $h $v @()
}
# Button: PageNavigation (target page) or ClearAllSlicers
function Button($page, $id, $x, $y, $w, $h, $label, $action, $target, $fill, $fillT, $text, $hover) {
  $sel = @{ id = 'default' }
  $link = [ordered]@{ show = (Lit 'true'); type = (Lit "'$action'") }
  if ($target) { $link.navigationSection = (Lit "'$target'") }
  $vco = Bare; $vco.visualLink = @(@{ properties = $link })
  $v = [ordered]@{
    visualType = 'actionButton'
    objects = [ordered]@{
      icon = @(@{ properties = @{ show = (Lit 'false') }; selector = $sel })
      text = @(@{ properties = [ordered]@{ show = (Lit 'true'); text = (Lit "'$label'"); fontColor = (Col $text); fontSize = (Lit '11D'); fontFamily = (Lit "'Segoe UI Semibold'"); horizontalAlignment = (Lit "'left'"); leftMargin = (Lit '14D') }; selector = $sel })
      fill = @(
        @{ properties = [ordered]@{ show = (Lit 'true'); fillColor = (Col $fill); transparency = (Lit "${fillT}D") }; selector = $sel },
        @{ properties = [ordered]@{ show = (Lit 'true'); fillColor = (Col $hover); transparency = (Lit '0D') }; selector = @{ id = 'hover' } }
      )
      outline = @(@{ properties = @{ show = (Lit 'false') }; selector = $sel })
      shape = @(@{ properties = @{ roundEdge = (Lit '8L') }; selector = $sel })
    }
    visualContainerObjects = $vco
  }
  Emit $page $id $x $y $w $h $v @()
}

# ---------- Layout (1280 x 720 canvas) ----------
# Sidebar (x 0-200): brand, navigation buttons, filter slicers, clear-filters button
# Main area (x 216-1268): page header, KPI tiles beside the lead chart, then detail visuals
$SIDE_W = 200; $MX = 216; $MW = 1052; $GAP = 10
$HEAD_Y = 8; $HEAD_H = 46
$R1_Y = 60;  $R1_H = 238     # KPI tiles (3 x 2) + lead chart
$R2_Y = 308; $R2_H = 402     # detail visuals
$KPI_W = 166; $KPI_H = 114   # 3 tiles + 2 gaps = 518
$LEAD_X = $MX + 3 * $KPI_W + 3 * $GAP; $LEAD_W = $MX + $MW - $LEAD_X

$PAGE_LIST = @(
  @{ name = 'b388af99db000d0b50c6'; label = 'Executive Overview' },
  @{ name = 'customers01'; label = 'Customers' },
  @{ name = 'fleet01'; label = 'Fleet' },
  @{ name = 'service01'; label = 'Service' },
  @{ name = 'cost01'; label = 'Cost' }
)

function Sidebar($page) {
  # Navy panel
  $v = [ordered]@{
    visualType = 'shape'
    objects = [ordered]@{
      shape = @(@{ properties = @{ tileShape = (Lit "'rectangle'") } })
      fill = @(@{ properties = [ordered]@{ show = (Lit 'true'); fillColor = (Col $NAVY); transparency = (Lit '0D') } })
      outline = (Off)
    }
    visualContainerObjects = (Bare)
  }
  Emit $page "${page}_panel" 0 0 $SIDE_W 720 $v @()
  TextBox $page "${page}_brand" 12 10 176 58 @(
    @{ t = 'SIJ Logistics'; font = 'Segoe UI Semibold'; size = '16pt'; color = $WHITE },
    @{ t = 'Fleet & freight analytics'; font = 'Segoe UI'; size = '9pt'; color = $MUTED }
  )
  # Navigation: one button per page; the current page is highlighted
  $y = 80
  for ($i = 0; $i -lt $PAGE_LIST.Count; $i++) {
    $entry = $PAGE_LIST[$i]
    if ($entry.name -eq $page) { $fill = $TEAL; $fillT = 0; $txt = $WHITE } else { $fill = $NAVY; $fillT = 100; $txt = $MUTED }
    Button $page "${page}_nav$i" 12 $y 176 34 $entry.label 'PageNavigation' $entry.name $fill $fillT $txt $NAVY_HOVER
    $y += 40
  }
  TextBox $page "${page}_filtersLabel" 12 290 176 26 @(@{ t = 'FILTERS'; font = 'Segoe UI Semibold'; size = '9pt'; color = $MUTED })
}
# Slicer panel: Year, Quarter and Month are synced across pages (the selection
# carries over between pages); two slicers follow for the page's own categories.
function Slicers($page, $extra) {
  $list = @(
    @{ f = (C 'Calendar' 'Year');    t = 'Year';    sync = 'SyncYear' },
    @{ f = (C 'Calendar' 'Quarter'); t = 'Quarter'; sync = 'SyncQuarter' },
    @{ f = (C 'Calendar' 'Month');   t = 'Month';   sync = 'SyncMonth' }
  ) + $extra
  $y = 316
  for ($i = 0; $i -lt $list.Count; $i++) {
    $s = $list[$i]
    $vco = Bare; $vco.title = (Title $s.t $MUTED)
    $v = [ordered]@{
      visualType = 'slicer'
      query = [ordered]@{ queryState = [ordered]@{ Values = @{ projections = @((Proj $s.f)) } } }
      objects = @{ data = @(@{ properties = @{ mode = (Lit "'Dropdown'") } }) }
      visualContainerObjects = $vco
      drillFilterOtherVisuals = $true
    }
    if ($s.sync) { $v.syncGroup = [ordered]@{ groupName = $s.sync; fieldChanges = $true; filterChanges = $true } }
    Emit $page "${page}_slicer$i" 12 $y 176 56 $v @($s.f)
    $y += 60
  }
  Button $page "${page}_clear" 12 ($y + 6) 176 34 'Clear all filters' 'ClearAllSlicers' $null $AMBER 0 $INK '#FBBF24'
}
function Header($page, $title, $subtitle) {
  TextBox $page "${page}_header" $MX $HEAD_Y 820 $HEAD_H @(
    @{ t = $title; font = 'Segoe UI Semibold'; size = '16pt'; color = $INK },
    @{ t = $subtitle; font = 'Segoe UI'; size = '9pt'; color = $SUBTLE }
  )
}
# Six KPI tiles in a 3 x 2 block next to the page's lead chart
function Kpis($page, $measures, $titles) {
  for ($i = 0; $i -lt $measures.Count; $i++) {
    $col = $i % 3; $row = [math]::Floor($i / 3)
    Visual $page "${page}_kpi$i" 'card' ($MX + $col * ($KPI_W + $GAP)) ($R1_Y + $row * ($KPI_H + $GAP)) $KPI_W $KPI_H @{ Values = @((M $measures[$i])) } $titles[$i] $null
  }
}
function Page($name, $display, $subtitle) {
  $script:z = 0
  Save "$PAGES\$name\page.json" ([ordered]@{ '$schema' = $PG; name = $name; displayName = $display; displayOption = 'FitToPage'; height = 720; width = 1280 })
  Sidebar $name
  Header $name $display $subtitle
}
# Split the detail row into columns of the given widths (gaps added automatically)
function Cols($widths) {
  $xs = @(); $x = $MX
  foreach ($w in $widths) { $xs += , @($x, $w); $x += $w + $GAP }
  $xs
}

# Remove previously generated visuals so the script can be re-run
Get-ChildItem $PAGES -Directory | ForEach-Object { if (Test-Path "$($_.FullName)\visuals") { Remove-Item "$($_.FullName)\visuals" -Recurse -Force } }

# ---------------- Executive Overview (reuses the original blank page) ----------------
$p = 'b388af99db000d0b50c6'; Page $p 'Executive Overview' 'Revenue, cost, service and safety at a glance - 2022 to 2024'
Kpis $p @('Total Revenue','Total Loads','Profit Margin %','On-Time %','Incidents per 100 Trips','Cost per Mile') @('Total Revenue','Total Loads','Profit Margin*','On-Time Delivery','Incidents / 100 Trips','Cost per Mile*')
Slicers $p @(@{ f = (C 'customers' 'customer_type'); t = 'Customer Type' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'execTrend' 'lineChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Total Revenue'), (M 'Total Operating Cost')) }) 'Revenue vs Operating Cost by Month' $null
$c = Cols @(344, 344, 344)
Visual $p 'execType' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'customers' 'customer_type')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer Type' (M 'Total Revenue')
Visual $p 'execCost' 'clusteredColumnChart' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Category = @((C 'Calendar' 'Year')); Y = @((M 'Total Fuel Cost'), (M 'Total Maintenance Cost'), (M 'Total Claim Amount')) }) 'Cost Mix by Year' $null
Visual $p 'execOnTime' 'lineChart' $c[2][0] $R2_Y $c[2][1] $R2_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null

# ---------------- Customers ----------------
$p = 'customers01'; Page $p 'Customers' 'Who drives revenue, how much potential is captured, and how well we serve them'
Kpis $p @('Active Customers','Total Revenue','Total Billed Revenue','Avg Revenue per Load','Revenue vs Potential %','Margin after Fuel %') @('Active Customers','Total Revenue','Billed Revenue (incl. surcharges)','Avg Revenue per Load','Revenue vs Potential','Margin after Fuel')
Slicers $p @(@{ f = (C 'customers' 'customer_type'); t = 'Customer Type' }, @{ f = (C 'customers' 'account_status'); t = 'Account Status' })
Visual $p 'custFreight' 'clusteredColumnChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'customers' 'primary_freight_type')); Y = @((M 'Avg Revenue per Load')) }) 'Avg Revenue per Load by Freight Type' (M 'Avg Revenue per Load')
$c = Cols @(380, 662)
Visual $p 'custTop' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'customers' 'customer_name')); Y = @((M 'Total Revenue')) }) 'Revenue by Customer' (M 'Total Revenue')
Visual $p 'custTable' 'tableEx' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Values = @((C 'customers' 'customer_name'), (C 'customers' 'customer_type'), (M 'Total Revenue'), (M 'Customer Revenue Share %'), (M 'Revenue vs Potential %'), (M 'On-Time %'), (M 'Margin after Fuel %')) }) 'Customer Scorecard' (M 'Total Revenue')

# ---------------- Fleet ----------------
$p = 'fleet01'; Page $p 'Fleet' 'Utilization, fuel efficiency and maintenance across trucks and drivers'
Kpis $p @('Active Trucks','Active Drivers','Avg Utilization Rate','Avg MPG','Idle %','Downtime Hours') @('Active Trucks','Active Drivers','Avg Utilization','Avg MPG','Idle Time','Downtime Hours')
Slicers $p @(@{ f = (C 'trucks' 'make'); t = 'Truck Make' }, @{ f = (C 'drivers' 'home_terminal'); t = 'Home Terminal' })
Visual $p 'fleetYearModel' 'clusteredColumnChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'trucks' 'model_year')); Y = @((M 'Maintenance Cost per Mile')) }) 'Maintenance Cost per Mile by Model Year' $null
$c = Cols @(260, 260, 512)
Visual $p 'fleetMake' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'trucks' 'make')); Y = @((M 'Avg Utilization Rate')) }) 'Utilization by Make' (M 'Avg Utilization Rate')
Visual $p 'fleetDrivers' 'clusteredBarChart' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Category = @((C 'drivers' 'home_terminal')); Y = @((M 'Avg MPG')) }) 'MPG by Home Terminal' (M 'Avg MPG')
Visual $p 'fleetTable' 'tableEx' $c[2][0] $R2_Y $c[2][1] $R2_H ([ordered]@{ Values = @((C 'trucks' 'unit_number'), (C 'trucks' 'make'), (M 'Total Miles'), (M 'Avg MPG'), (M 'Maintenance Cost per Mile'), (M 'Downtime Hours'), (M 'Avg Utilization Rate')) }) 'Truck Scorecard' (M 'Total Miles')

# ---------------- Service ----------------
$p = 'service01'; Page $p 'Service' 'On-time delivery, detention, transit times and safety'
Kpis $p @('On-Time %','Avg Detention (min)','Avg Actual Transit Days','Avg Planned Transit Days','Incidents per Million Miles','Preventable Incident %') @('On-Time Delivery','Avg Detention (min)','Actual Transit Days','Planned Transit Days','Incidents / Million Miles','Preventable Incidents')
Slicers $p @(@{ f = (C 'facilities' 'facility_type'); t = 'Facility Type' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'svcTrend' 'lineChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null
$c = Cols @(300, 260, 472)
Visual $p 'svcFacility' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'facilities' 'facility_name')); Y = @((M 'Avg Detention (min)')) }) 'Avg Detention by Facility (min)' (M 'Avg Detention (min)')
Visual $p 'svcIncidents' 'clusteredBarChart' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Category = @((C 'safety_incidents' 'incident_type')); Y = @((M 'Total Safety Incidents')) }) 'Safety Incidents by Type' (M 'Total Safety Incidents')
Visual $p 'svcRoutes' 'tableEx' $c[2][0] $R2_Y $c[2][1] $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Loads'), (M 'On-Time %'), (M 'Avg Actual Transit Days'), (M 'Avg Planned Transit Days')) }) 'Route Service Levels' (M 'Total Loads')

# ---------------- Cost ----------------
$p = 'cost01'; Page $p 'Cost' 'Operating cost, fuel and margin by route - cost covers fuel and maintenance only'
Kpis $p @('Total Operating Cost','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price per Gallon','Total Claim Amount','Profit') @('Operating Cost*','Cost per Mile*','Fuel Cost per Mile','Avg Fuel Price / Gallon','Incident Claims','Profit*')
Slicers $p @(@{ f = (C 'fuel_purchases' 'location_state'); t = 'Fuel State' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'costTrend' 'lineChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Cost per Mile'), (M 'Fuel Cost per Mile')) }) 'Cost per Mile by Month' $null
$c = Cols @(400, 642)
Visual $p 'costState' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'fuel_purchases' 'location_state')); Y = @((M 'Avg Fuel Price per Gallon')) }) 'Fuel Price per Gallon by State' (M 'Avg Fuel Price per Gallon')
Visual $p 'costRoutes' 'tableEx' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Revenue'), (M 'Revenue per Mile'), (M 'Total Fuel Cost'), (M 'Margin after Fuel'), (M 'Margin after Fuel %')) }) 'Route Margin after Fuel' (M 'Margin after Fuel')

# ---------------- Page order ----------------
Save "$PAGES\pages.json" ([ordered]@{ '$schema' = $PGS; pageOrder = @($PAGE_LIST | ForEach-Object { $_.name }); activePageName = 'b388af99db000d0b50c6' })

# Emit a field list for validation
$script:vis | ForEach-Object { foreach ($f in $_.fields) { if ($f) { "{0}|{1}|{2}|{3}|{4}" -f $_.page, $_.id, $f.kind, $f.entity, $f.prop } } }
