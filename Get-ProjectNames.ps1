$namesInJson = Get-Content -Raw -Path .\ProjectNames.json | ConvertFrom-Json

$ProjectNames = @()

foreach ($nameInJson in $namesInJson) {
    $ProjectNames += $nameInJson.name
}

return $ProjectNames