param(
    [string]$Root = "src",
    [string]$Output = "project_dump.txt"
)

# File extensions to include
$Extensions = @(
    ".lua",
    ".luau"
)

$Files = Get-ChildItem -Path $Root -Recurse -File |
    Where-Object {
        $Extensions -contains $_.Extension.ToLower()
    } |
    Sort-Object FullName

$Builder = [System.Text.StringBuilder]::new()

foreach ($File in $Files) {
    try {
        $RelativePath = Resolve-Path -Relative $File.FullName
        $Content = Get-Content $File.FullName -Raw -ErrorAction Stop

        [void]$Builder.AppendLine("($RelativePath):")
        [void]$Builder.AppendLine($Content)
        [void]$Builder.AppendLine("")
    }
    catch {
        Write-Warning "Failed to read $($File.FullName): $_"
    }
}

$Builder.ToString() | Set-Content -Path $Output -Encoding UTF8

Write-Host "Collected $($Files.Count) files into $Output"
