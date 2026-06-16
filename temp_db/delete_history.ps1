$dir = "c:\Users\tony\.gemini\antigravity-ide\scratch\Orion_U2_Hedge\temp_db"
# Clean up old extraction first to avoid assembly load issues
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
New-Item -ItemType Directory -Path $dir

$zipPath = "$dir\npgsql.zip"
$dllPath = "$dir\Npgsql.dll"

Write-Host "Downloading Npgsql 2.2.7..."
Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Npgsql/2.2.7" -OutFile $zipPath
Write-Host "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $dir)
Copy-Item "$dir\lib\net45\Npgsql.dll" $dllPath

Write-Host "Loading Npgsql..."
Add-Type -Path $dllPath

# Trust SSL by setting connection string properties
$connStr = "Server=ep-silent-firefly-ac8ibhrv-pooler.sa-east-1.aws.neon.tech;Database=neondb;User Id=neondb_owner;Password=npg_orfCuKy5xb1V;Port=5432;SSL=true;SSL Mode=Require;Trust Server Certificate=true"
$conn = New-Object Npgsql.NpgsqlConnection($connStr)
$conn.Open()

Write-Host "Connected! Deleting history before 2026-06-16..."
$query = "DELETE FROM `"PerformanceHistory`" WHERE `"date`" < '2026-06-16 00:00:00+00';"
$cmd = New-Object Npgsql.NpgsqlCommand($query, $conn)
$deleted = $cmd.ExecuteNonQuery()
Write-Host "Deleted $deleted rows!"

$conn.Close()
