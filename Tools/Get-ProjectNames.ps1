$namesInJson = Get-Content -Raw -Path .\Tools\ProjectNames.json | ConvertFrom-Json

$ProjectNames = @()

foreach ($nameInJson in $namesInJson) {
    $ProjectNames += $nameInJson.name
}

return $ProjectNames
