# Generates the SIJ Logistics & Analytics report pages (TSA_capstone project) (PBIR) from the semantic model's measures.
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
function Pad($t, $r, $b, $l) { , @(@{ properties = [ordered]@{ top = (Lit "${t}D"); right = (Lit "${r}D"); bottom = (Lit "${b}D"); left = (Lit "${l}D") } }) }
function Fill($hex) { , @(@{ properties = [ordered]@{ show = (Lit 'true'); color = (Col $hex); transparency = (Lit '0D') } }) }
# Container with no card styling or padding (sidebar items, text, buttons).
# The theme adds 8/12 px padding to every visual; removing it here stops text
# boxes from clipping and showing a scroll bar.
function Bare() { [ordered]@{ background = (Off); border = (Off); dropShadow = (Off); padding = (Pad 0 0 0 0) } }

# Palette (matches StaticResources/RegisteredResources/SIJ_Logistics_Theme.json)
$NAVY = '#0F2A44'; $NAVY_HOVER = '#1E3A5F'; $TEAL = '#14A3A3'; $AMBER = '#F59E0B'
$WHITE = '#FFFFFF'; $MUTED = '#CBD5E1'; $INK = '#0F2A44'; $SUBTLE = '#64748B'
$PANEL_GREY = '#E2E8F0'; $LABEL = '#334155'
$BTN_GREY = '#F1F5F9'; $TEAL_PALE = '#CCEFEF'; $TEAL_DARK = '#0F8A8A'
# Sidebar text colours (no black on the sidebar): brand and buttons in theme blue,
# panel labels in dark teal, clear-button text in deep amber
$BRAND_BLUE = '#1F4E79'; $TEAL_TEXT = '#0F6B6B'; $AMBER_TEXT = '#7C2D12'

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
# Text box. Each paragraph is either one run @{ t; font; size; color; bold }
# or @{ runs = @(run, run, ...) } to mix bold and regular text on one line.
function Run($r) {
  $style = [ordered]@{ fontFamily = $r.font; fontSize = $r.size; color = $r.color }
  if ($r.bold) { $style.fontWeight = 'bold' }
  [ordered]@{ value = $r.t; textStyle = $style }
}
function TextBox($page, $id, $x, $y, $w, $h, $paragraphs, $vco) {
  $paras = @($paragraphs | ForEach-Object {
    if ($_.runs) { $rs = @($_.runs | ForEach-Object { Run $_ }) } else { $rs = @((Run $_)) }
    @{ textRuns = $rs }
  })
  if (-not $vco) { $vco = Bare }
  $v = [ordered]@{
    visualType = 'textbox'
    objects = @{ general = @(@{ properties = @{ paragraphs = $paras } }) }
    visualContainerObjects = $vco
    drillFilterOtherVisuals = $true
  }
  Emit $page $id $x $y $w $h $v @()
}
# Plain rectangle used for the sidebar and filter panels
function Panel($page, $id, $x, $y, $w, $h, $hex) {
  $v = [ordered]@{
    visualType = 'shape'
    objects = [ordered]@{
      shape = @(@{ properties = @{ tileShape = (Lit "'rectangle'") } })
      fill = @(@{ properties = [ordered]@{ show = (Lit 'true'); fillColor = (Col $hex); transparency = (Lit '0D') } })
      outline = (Off)
    }
    visualContainerObjects = (Bare)
  }
  Emit $page $id $x $y $w $h $v @()
}
# Button: PageNavigation (target page) or ClearAllSlicers.
# Power BI button formatting uses separate entries: one without a selector that only
# turns the setting on ("show"), then "default" (resting) and "hover" styling.
# Putting "show" together with the styling makes the formatting silently fail, and
# buttons under about 36 px tall clip their label.
function Button($page, $id, $x, $y, $w, $h, $label, $action, $target, $fill, $text, $hoverFill, $hoverText) {
  $def = @{ id = 'default' }; $hov = @{ id = 'hover' }
  $on = @{ properties = @{ show = (Lit 'true') } }
  $link = [ordered]@{ show = (Lit 'true'); type = (Lit "'$action'") }
  if ($target) { $link.navigationSection = (Lit "'$target'") }
  $vco = Bare; $vco.visualLink = @(@{ properties = $link })
  $txt = [ordered]@{ text = (Lit "'$label'"); fontColor = (Col $text); fontSize = (Lit '10D'); fontFamily = (Lit "'Segoe UI Semibold'"); horizontalAlignment = (Lit "'left'"); leftMargin = (Lit '12D') }
  $v = [ordered]@{
    visualType = 'actionButton'
    objects = [ordered]@{
      icon = @(
        @{ properties = @{ show = (Lit 'false') } },
        @{ properties = @{ placement = (Lit "'left'") }; selector = $def }
      )
      text = @(
        $on,
        @{ properties = $txt; selector = $def },
        @{ properties = [ordered]@{ text = (Lit "'$label'"); fontColor = (Col $hoverText) }; selector = $hov }
      )
      fill = @(
        $on,
        @{ properties = [ordered]@{ fillColor = (Col $fill); transparency = (Lit '0D') }; selector = $def },
        @{ properties = [ordered]@{ fillColor = (Col $hoverFill); transparency = (Lit '0D') }; selector = $hov }
      )
      outline = @(@{ properties = @{ show = (Lit 'false') } })
      shape = @(@{ properties = @{ tileShape = (Lit "'rectangleRounded'") }; selector = $def })
    }
    visualContainerObjects = $vco
  }
  Emit $page $id $x $y $w $h $v @()
}

# ---------- Layout (1280 x 720 canvas) ----------
# Sidebar (x 0-200): white brand and navigation panel on top, grey filter panel
#   from FILTER_Y down to the bottom edge, thin divider on the right.
# Header (x 200-1280, y 0-58): white full-width title bar.
# Main area (x 212-1268): 12 px margin on both sides and at the bottom; KPI tiles
#   beside the lead chart, then the detail visuals.
$SIDE_W = 200; $MX = 212; $MW = 1056; $GAP = 10
$HEAD_H = 58
$R1_Y = 68;  $R1_H = 232     # KPI tiles (3 x 2) + lead chart
$R2_Y = 310; $R2_H = 398     # detail visuals (ends at 708)
$KPI_W = 166; $KPI_H = 111   # 3 tiles + 2 gaps = 518
$LEAD_X = $MX + 3 * $KPI_W + 3 * $GAP; $LEAD_W = $MX + $MW - $LEAD_X
$NAV_Y = 62; $NAV_H = 36; $NAV_STEP = 40   # buttons below ~36 px clip their label
$FILTER_Y = 306              # grey filter panel top
$SLICER_Y = 334; $SLICER_H = 64; $SLICER_STEP = 66   # dropdown slicers need 64 px with no padding
$CLEAR_Y = 672; $CLEAR_H = 36

$PAGE_LIST = @(
  @{ name = 'b388af99db000d0b50c6'; label = 'Executive Overview' },
  @{ name = 'customers01'; label = 'Customers' },
  @{ name = 'fleet01'; label = 'Fleet' },
  @{ name = 'service01'; label = 'Service' },
  @{ name = 'cost01'; label = 'Cost' },
  @{ name = 'summary01'; label = 'Summary & Actions' }
)

function Sidebar($page) {
  Panel $page "${page}_panel" 0 0 $SIDE_W 720 $WHITE
  Panel $page "${page}_filterPanel" 0 $FILTER_Y $SIDE_W (720 - $FILTER_Y) $PANEL_GREY
  Panel $page "${page}_divider" ($SIDE_W - 1) 0 1 $FILTER_Y $PANEL_GREY
  TextBox $page "${page}_brand" 12 8 176 48 @(
    @{ t = 'SIJ Logistics'; font = 'Segoe UI'; size = '15pt'; color = $BRAND_BLUE; bold = $true },
    @{ t = '& Analytics'; font = 'Segoe UI'; size = '10pt'; color = $TEAL; bold = $true }
  )
  # Navigation: one button per page, labelled with the page title; the current
  # page is solid teal, the others light grey and turn pale teal on hover
  $y = $NAV_Y
  for ($i = 0; $i -lt $PAGE_LIST.Count; $i++) {
    $entry = $PAGE_LIST[$i]
    if ($entry.name -eq $page) { $fill = $TEAL; $txt = $WHITE; $hf = $TEAL_DARK; $ht = $WHITE }
    else { $fill = $BTN_GREY; $txt = $BRAND_BLUE; $hf = $TEAL_PALE; $ht = $TEAL_TEXT }
    Button $page "${page}_nav$i" 12 $y 176 $NAV_H $entry.label 'PageNavigation' $entry.name $fill $txt $hf $ht
    $y += $NAV_STEP
  }
  TextBox $page "${page}_filtersLabel" 12 ($FILTER_Y + 7) 176 20 @(@{ t = 'FILTERS'; font = 'Segoe UI'; size = '9pt'; color = $TEAL_TEXT; bold = $true })
}
# Slicer panel: Year, Quarter and Month are synced across pages (the selection
# carries over between pages); two slicers follow for the page's own categories.
# The slicers are spread over the grey panel so the clear button sits at the bottom.
function Slicers($page, $extra) {
  $list = @(
    @{ f = (C 'Calendar' 'Year');    t = 'Year';    sync = 'SyncYear' },
    @{ f = (C 'Calendar' 'Quarter'); t = 'Quarter'; sync = 'SyncQuarter' },
    @{ f = (C 'Calendar' 'Month');   t = 'Month';   sync = 'SyncMonth' }
  ) + $extra
  $y = $SLICER_Y
  for ($i = 0; $i -lt $list.Count; $i++) {
    $s = $list[$i]
    # One label per slicer: the slicer's own header carries the name, so the
    # container title is switched off (otherwise the name shows twice).
    # White rounded card on the grey panel (theme style), without the shadow.
    # Padding is declared explicitly: any per-visual container setting drops the
    # theme padding, and a 64 px dropdown has no room for more.
    $vco = [ordered]@{ title = (Off); dropShadow = (Off); padding = (Pad 0 0 0 0) }
    $v = [ordered]@{
      visualType = 'slicer'
      query = [ordered]@{ queryState = [ordered]@{ Values = @{ projections = @((Proj $s.f)) } } }
      objects = [ordered]@{
        data = @(@{ properties = @{ mode = (Lit "'Dropdown'") } })
        header = @(@{ properties = [ordered]@{ show = (Lit 'true'); text = (Lit "'$($s.t)'"); fontColor = (Col $BRAND_BLUE); textSize = (Lit '9D') } })
      }
      visualContainerObjects = $vco
      drillFilterOtherVisuals = $true
    }
    if ($s.sync) { $v.syncGroup = [ordered]@{ groupName = $s.sync; fieldChanges = $true; filterChanges = $true } }
    Emit $page "${page}_slicer$i" 12 $y 176 $SLICER_H $v @($s.f)
    $y += $SLICER_STEP
  }
  Button $page "${page}_clear" 12 $CLEAR_Y 176 $CLEAR_H 'Clear all filters' 'ClearAllSlicers' $null $AMBER $AMBER_TEXT '#FBBF24' $AMBER_TEXT
}
# Full-width title bar: bold page title with a one-line description underneath
function Header($page, $title, $subtitle) {
  $vco = [ordered]@{ background = (Fill $WHITE); border = (Off); dropShadow = (Off); padding = (Pad 6 16 4 16) }
  TextBox $page "${page}_header" $SIDE_W 0 (1280 - $SIDE_W) $HEAD_H @(
    @{ t = $title; font = 'Segoe UI'; size = '16pt'; color = $INK; bold = $true },
    @{ t = $subtitle; font = 'Segoe UI'; size = '9pt'; color = $SUBTLE }
  ) $vco
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
# Split the detail row into columns of the given widths (gaps added automatically).
# The last column stretches to the right margin so every page lines up.
function Cols($widths) {
  $xs = @(); $x = $MX
  for ($i = 0; $i -lt $widths.Count; $i++) {
    $w = $widths[$i]
    if ($i -eq $widths.Count - 1) { $w = $MX + $MW - $x }
    $xs += , @($x, $w); $x += $w + $GAP
  }
  $xs
}

# Remove previously generated visuals so the script can be re-run
# Retries because OneDrive can briefly lock folders while it syncs them.
function RemoveDir($path) {
  for ($try = 1; Test-Path $path; $try++) {
    try { Remove-Item $path -Recurse -Force -ErrorAction Stop }
    catch { if ($try -ge 10) { throw }; Start-Sleep -Milliseconds 500 }
  }
}
Get-ChildItem $PAGES -Directory | ForEach-Object { RemoveDir "$($_.FullName)\visuals" }

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
Kpis $p @('Active Customers','Total Revenue','Total Billed Revenue','Avg Revenue per Load','Revenue vs Potential %','Margin after Fuel %') @('Active Customers','Total Revenue','Billed Revenue','Avg Revenue per Load','Revenue vs Potential','Margin after Fuel')
Slicers $p @(@{ f = (C 'customers' 'customer_type'); t = 'Customer Type' }, @{ f = (C 'customers' 'account_status'); t = 'Account Status' })
Visual $p 'custFreight' 'clusteredColumnChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'customers' 'primary_freight_type')); Y = @((M 'Avg Revenue per Load')) }) 'Avg Revenue per Load by Freight Type' (M 'Avg Revenue per Load')
$c = Cols @(380, 662)
Visual $p 'custTop' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'customers' 'customer_name')); Y = @((M 'Total Revenue')) }) 'Revenue by Name (merges same-name accounts)' (M 'Total Revenue')
Visual $p 'custTable' 'tableEx' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Values = @((C 'customers' 'customer_id'), (C 'customers' 'customer_name'), (C 'customers' 'customer_type'), (M 'Total Revenue'), (M 'Customer Revenue Share %'), (M 'Revenue vs Potential %'), (M 'On-Time %'), (M 'Margin after Fuel %')) }) 'Customer Scorecard (one row per account)' (M 'Total Revenue')

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
Kpis $p @('On-Time %','Avg Detention (min)','Avg Actual Transit Days','Avg Planned Transit Days','Incidents per Million Miles','Preventable Incident %') @('On-Time Delivery','Avg Detention (min)','Actual Transit Days','Planned Transit Days','Incidents / M Miles','Preventable Incidents')
Slicers $p @(@{ f = (C 'facilities' 'facility_type'); t = 'Facility Type' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'svcTrend' 'lineChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'On-Time %')) }) 'On-Time Delivery % by Month' $null
$c = Cols @(300, 260, 472)
Visual $p 'svcFacility' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'facilities' 'facility_name')); Y = @((M 'Avg Detention (min)')) }) 'Avg Detention by Facility (min)' (M 'Avg Detention (min)')
Visual $p 'svcIncidents' 'clusteredBarChart' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Category = @((C 'safety_incidents' 'incident_type')); Y = @((M 'Total Safety Incidents')) }) 'Safety Incidents by Type' (M 'Total Safety Incidents')
Visual $p 'svcRoutes' 'tableEx' $c[2][0] $R2_Y $c[2][1] $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Loads'), (M 'On-Time %'), (M 'Avg Actual Transit Days'), (M 'Avg Planned Transit Days')) }) 'Route Service Levels' (M 'Total Loads')

# ---------------- Cost ----------------
$p = 'cost01'; Page $p 'Cost' 'Operating cost, fuel and margin by route - cost covers fuel and maintenance only'
Kpis $p @('Total Operating Cost','Cost per Mile','Fuel Cost per Mile','Avg Fuel Price per Gallon','Total Claim Amount','Profit') @('Operating Cost*','Cost per Mile*','Fuel Cost per Mile','Fuel Price / Gallon','Incident Claims','Profit*')
Slicers $p @(@{ f = (C 'fuel_purchases' 'location_state'); t = 'Fuel State' }, @{ f = (C 'routes' 'origin_state'); t = 'Origin State' })
Visual $p 'costTrend' 'lineChart' $LEAD_X $R1_Y $LEAD_W $R1_H ([ordered]@{ Category = @((C 'Calendar' 'Year Month')); Y = @((M 'Cost per Mile'), (M 'Fuel Cost per Mile')) }) 'Cost per Mile by Month' $null
$c = Cols @(400, 642)
Visual $p 'costState' 'clusteredBarChart' $c[0][0] $R2_Y $c[0][1] $R2_H ([ordered]@{ Category = @((C 'fuel_purchases' 'location_state')); Y = @((M 'Avg Fuel Price per Gallon')) }) 'Fuel Price per Gallon by State' (M 'Avg Fuel Price per Gallon')
Visual $p 'costRoutes' 'tableEx' $c[1][0] $R2_Y $c[1][1] $R2_H ([ordered]@{ Values = @((C 'routes' 'origin_city'), (C 'routes' 'destination_city'), (M 'Total Revenue'), (M 'Revenue per Mile'), (M 'Total Fuel Cost'), (M 'Margin after Fuel'), (M 'Margin after Fuel %')) }) 'Route Margin after Fuel' (M 'Margin after Fuel')

# ---------------- Summary & Actions ----------------
# Plain-language findings and recommendations for the full 2022-2024 period.
# Figures are fixed text (they do not respond to filters); the source analysis is
# in docs/Executive_Summary.md - update both together.
$p = 'summary01'; Page $p 'Summary & Actions' 'What the data says and what to do next - full period, January 2022 to December 2024'
TextBox $p "${p}_about" 12 ($FILTER_Y + 34) 176 150 @(
  @{ t = 'Figures on this page cover the full three years and do not change with filters.'; font = 'Segoe UI'; size = '9pt'; color = $BRAND_BLUE },
  @{ t = ' '; font = 'Segoe UI'; size = '6pt'; color = $LABEL },
  @{ t = 'Use the other pages to explore any number in detail.'; font = 'Segoe UI'; size = '9pt'; color = $TEAL_TEXT }
)
$CARD = [ordered]@{ padding = (Pad 10 14 10 14) }
function Heading($t, $hex) { @{ t = $t; font = 'Segoe UI'; size = '12pt'; color = $hex; bold = $true } }
function Bullet($lead, $rest) { @{ runs = @(@{ t = "- $lead"; font = 'Segoe UI'; size = '9.5pt'; color = $INK; bold = $true }, @{ t = " $rest"; font = 'Segoe UI'; size = '9.5pt'; color = $LABEL }) } }
function Spacer() { @{ t = ' '; font = 'Segoe UI'; size = '5pt'; color = $LABEL } }
$FW = 318; $FH = 315
TextBox $p "${p}_customers" $MX $R1_Y $FW $FH @(
  (Heading 'Customers: room to grow' $TEAL), (Spacer),
  (Bullet '$262.5M revenue' 'from 85,410 loads for 200 customers.'),
  (Bullet 'No single customer dominates:' 'the top 10 bring in only 5.7% of revenue, so losing one account is low risk.'),
  (Bullet 'Only about 16% of potential captured:' 'customers say they could give us far more freight than they do.'),
  (Bullet '32 inactive accounts' 'still produced $42.6M (16%) of revenue - they are worth winning back.')
) $CARD
TextBox $p "${p}_fleet" ($MX + $FW + $GAP) $R1_Y $FW $FH @(
  (Heading 'Fleet: busy, but idling' $TEAL), (Spacer),
  (Bullet '93 trucks and 125 drivers' 'ran 122 million miles.'),
  (Bullet 'Trucks are in use 83% of the time,' 'and fuel economy is the same (6.45 MPG) for every make.'),
  (Bullet 'Engines idle 28% of trip time:' 'about 599,000 hours of burning fuel without moving.'),
  (Bullet '1 in 3 repairs is an emergency.' '2018 trucks cost the most to maintain ($0.07 a mile, twice the 2020 trucks).')
) $CARD
TextBox $p "${p}_service" $MX ($R1_Y + $FH + $GAP) $FW $FH @(
  (Heading 'Service: the biggest problem' $AMBER), (Spacer),
  (Bullet 'Only 56% of stops are on time' '- 45% of deliveries and 67% of pickups.'),
  (Bullet 'Late stops are about 3 hours late,' 'and 9,382 stops flagged late were over 2 hours early, so appointment times do not match real drive times.'),
  (Bullet 'Drivers wait 92 minutes per stop' 'at customer docks; 36% of stops wait over 2 hours.'),
  (Bullet '170 safety incidents,' '33 injuries and $2.65M in claims; 38% were preventable.')
) $CARD
TextBox $p "${p}_cost" ($MX + $FW + $GAP) ($R1_Y + $FH + $GAP) $FW $FH @(
  (Heading 'Cost: fuel is almost everything' $TEAL), (Spacer),
  (Bullet 'Cost per load fell 12%' '($1,272 in 2022 to $1,114 in 2024), mainly because diesel fell from $4.20 to $3.65 a gallon.'),
  (Bullet 'Fuel is 92% of tracked cost,' 'and prices differ by only 2 cents between states, so savings must come from using less fuel.'),
  (Bullet 'Margins look high (61%)' 'because the data has no driver pay, insurance or overheads.')
) $CARD
$RX = $MX + 2 * ($FW + $GAP)
TextBox $p "${p}_actions" $RX $R1_Y ($MX + $MW - $RX) (2 * $FH + $GAP) @(
  (Heading 'Recommended actions' $INK), (Spacer),
  (Bullet '1. Fix delivery times first.' 'Set appointments from real drive times and track on-time weekly by customer. Target: 75% within 12 months.'), (Spacer),
  (Bullet '2. Charge for waiting time.' 'Agree 2 hours free time, then bill. Waiting beyond 2 hours came to 49,800 hours - about $3.7M at $75 an hour.'), (Spacer),
  (Bullet '3. Cut idling.' 'Idle limits, driver coaching and cab heaters/coolers. Halving idle time saves roughly 240,000 gallons (about $0.9M) over three years.'), (Spacer),
  (Bullet '4. Coach high-risk drivers.' '18 drivers had 3 or more incidents. Preventable incidents cost $0.9M in claims.'), (Spacer),
  (Bullet '5. Win back and grow accounts.' 'Call the 32 inactive customers, and target the 36 customers giving us under 10% of their potential.'), (Spacer),
  (Bullet '6. Plan maintenance, do not react.' 'Move emergency repairs into scheduled service and review the 2018 trucks for replacement.'), (Spacer),
  (Bullet '7. Complete the data.' 'Add driver pay and insurance to see true profit; 1,672 trips (2%) have no truck recorded.')
) $CARD

# ---------------- Page order ----------------
Save "$PAGES\pages.json" ([ordered]@{ '$schema' = $PGS; pageOrder = @($PAGE_LIST | ForEach-Object { $_.name }); activePageName = 'b388af99db000d0b50c6' })

# Emit a field list for validation
$script:vis | ForEach-Object { foreach ($f in $_.fields) { if ($f) { "{0}|{1}|{2}|{3}|{4}" -f $_.page, $_.id, $f.kind, $f.entity, $f.prop } } }
