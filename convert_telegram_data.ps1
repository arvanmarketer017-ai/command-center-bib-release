# convert_telegram_data.ps1
# Konversi data_telegram.json (format lama, master_bot.py) jadi entri di
# data_bots.json (format baru, BIB/bot_engine.py), lalu simpan ke folder
# PROFIL_BOT_AMAN yang benar. Aman dijalankan berkali-kali -- bot yang sudah
# ada di data_bots.json (selain hasil konversi) tidak akan dihapus/ditimpa.
#
# Ditulis kompatibel Windows PowerShell 5.1 bawaan (tidak pakai -AsHashtable,
# yang baru ada di PowerShell 6+).
#
# Pemakaian (jalankan di PowerShell PC yang datanya mau dipindah):
#   powershell -ExecutionPolicy Bypass -File convert_telegram_data.ps1

function ConvertTo-HashtableManual($obj) {
    $ht = @{}
    if ($null -eq $obj) { return $ht }
    foreach ($prop in $obj.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }
    return $ht
}

$AppDir = "$env:LOCALAPPDATA\BIB"
$OldFile = Join-Path $AppDir "data_telegram.json"
$CredsDir = Join-Path $AppDir "PROFIL_BOT_AMAN"
$NewFile = Join-Path $CredsDir "data_bots.json"

if (-not (Test-Path $OldFile)) {
    Write-Host "Tidak ketemu $OldFile -- pastikan file data_telegram.json ada di $AppDir"
    exit 1
}

$old = Get-Content $OldFile -Raw | ConvertFrom-Json
$grupPusat = $old.grup_pusat

New-Item -ItemType Directory -Force -Path $CredsDir | Out-Null

if (Test-Path $NewFile) {
    $existing = Get-Content $NewFile -Raw | ConvertFrom-Json
    $newData = ConvertTo-HashtableManual $existing
} else {
    $newData = @{}
}

$count = 0
foreach ($botName in $old.bots.PSObject.Properties.Name) {
    $bot = $old.bots.$botName
    $key = "TELEGRAM_$botName"
    $newData[$key] = @{
        tipe            = "TELEGRAM"
        user            = $bot.user
        pass            = $bot.pass
        site_type       = ""
        chat_id_target  = $bot.chat_id
        chat_id_pusat   = $grupPusat
    }
    $count++
    Write-Host "Konversi: $key (chat_id target: $($bot.chat_id))"
}

# Set-Content -Encoding utf8 di Windows PowerShell 5.1 SELALU nulis BOM
# (byte penanda tersembunyi) di awal file -- Notepad transparan soal ini
# (kelihatan normal), tapi json.load() di Python (dipakai BIB) GAGAL parse
# file ber-BOM dan errornya ditelan diam-diam oleh load_bots(), jadi
# kelihatan seolah "tidak ada bot" padahal isinya benar. Makanya di sini
# ditulis manual pakai UTF8Encoding(false) supaya tidak ada BOM sama sekali.
$json = $newData | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($NewFile, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "Selesai. $count bot Telegram dikonversi ke:"
Write-Host $NewFile
Write-Host "Buka/restart BIB untuk melihat hasilnya di halaman Telegram Alert."
