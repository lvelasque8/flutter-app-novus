# Abre el emulador NovusTablet en una ventana cómoda y visible.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\tools\abrir-emulador.ps1
#
# Se puede cambiar el tamano con -Ancho y -Alto.

param(
    [int]$Ancho = 1050,
    [int]$Alto = 690
)

$emulator = "C:\Users\ba2855\AppData\Local\Android\Sdk\emulator\emulator.exe"
$avd = "NovusTablet"

if (-not (Test-Path $emulator)) {
    Write-Error "No se encontro el emulador en $emulator"
    exit 1
}

Write-Host "Abriendo $avd..." -ForegroundColor Cyan
Start-Process -FilePath $emulator -ArgumentList @(
    "-avd", $avd,
    "-no-snapshot",
    "-no-boot-anim",
    "-gpu", "swiftshader_indirect",
    "-scale", "0.4"
)

# Espera a que aparezca la ventana del emulador.
$proceso = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    $proceso = Get-Process |
        Where-Object { $_.MainWindowTitle -match "NovusTablet|Android Emulator" } |
        Select-Object -First 1
    if ($proceso) { break }
}

if (-not $proceso) {
    Write-Warning "El emulador arranco pero no se encontro su ventana."
    exit 0
}

# Mueve y redimensiona la ventana para que no se salga de la pantalla.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Ventana {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
}
"@

$SWP_SHOWWINDOW = 0x0040

# El emulador tarda unos segundos en definir su tamano; si se cambia antes,
# el mismo emulador lo vuelve a agrandar.
Start-Sleep -Seconds 12

for ($intento = 1; $intento -le 4; $intento++) {
    [Ventana]::SetWindowPos(
        $proceso.MainWindowHandle,
        [IntPtr]::Zero,
        0,
        0,
        $Ancho,
        $Alto,
        $SWP_SHOWWINDOW
    ) | Out-Null

    Start-Sleep -Seconds 3

    $rect = New-Object Ventana+RECT
    [Ventana]::GetWindowRect($proceso.MainWindowHandle, [ref]$rect) | Out-Null
    $actualAncho = $rect.Right - $rect.Left
    $actualAlto = $rect.Bottom - $rect.Top

    if ([Math]::Abs($actualAncho - $Ancho) -le 20 -and
        [Math]::Abs($actualAlto - $Alto) -le 20) {
        Write-Host "Ventana ajustada a ${actualAncho}x${actualAlto}." -ForegroundColor Green
        exit 0
    }
}

Write-Warning "No se pudo fijar el tamano de la ventana."
