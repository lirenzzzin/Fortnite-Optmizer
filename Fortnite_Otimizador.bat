@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SELF=%~f0"
title FORTNITE OTIMIZADOR v2.1  -  Made by: Lina  ^|  Discord: kali_linax
:: Fortnite Otimizador v2.1 - lirenzzzin (Lina)  |  discord: kali_linax
:: github.com/lirenzzzin/Fortnite-Optmizer
::
:: uso:  Fortnite_Otimizador.bat [-DryRun] [-Language pt|en] [-SelfTest]
::   -DryRun   mostra o que faria, nao grava nada
::   -SelfTest roda os testes (uso meu)
::
:: changelog
::   2.1  idioma pt/en, visual novo, diagnostico com mais alertas, guia de mitos
::   2.0  reescrito em powershell, menus com setas, suporte amd/intel, plano de energia por cpu
::   1.5  ultima versao em batch puro
::
:: TODO
::   - testar de verdade em amd / intel hibrido / x3d (so testei no meu i5 + 1650)
::   - timer forcado: medir se vale a pena ou tirar
::   - ver se da pra aplicar opcoes da amd sem o adrenalin
::
:: o motor powershell fica no fim do arquivo, depois de #__PS_BEGIN__
if not "%~1"=="" goto RUN
net session >nul 2>&1
if errorlevel 1 goto ELEVATE
goto RUN

:ELEVATE
echo.
echo  =======================================================
echo    FORTNITE OTIMIZADOR v2.1
echo    Made by: Lina   ^|   Discord: kali_linax
echo  =======================================================
echo.
echo Solicitando permissao de administrador... / Requesting administrator permission...
powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -Verb RunAs" >nul 2>&1
if errorlevel 1 goto ELEVFAIL
exit /b 0

:ELEVFAIL
echo.
echo [ERRO] Nao consegui obter permissao de administrador. / Could not get administrator permission.
echo        Clique com o botao direito no arquivo e escolha "Executar como administrador".
echo        Right-click the file and choose "Run as administrator".
pause
exit /b 1

:RUN
set "PSDIR=%TEMP%\FortniteOtimizador"
if not exist "%PSDIR%" mkdir "%PSDIR%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $m=[regex]::Match($t,'(?m)^#__PS_BEGIN__\r?\n'); if(-not $m.Success){exit 9}; [IO.File]::WriteAllText($env:PSDIR+'\main.ps1',$t.Substring($m.Index+$m.Length),(New-Object Text.UTF8Encoding($true)))"
if errorlevel 1 goto EXTRACTFAIL
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSDIR%\main.ps1" -SelfPath "%SELF%" %*
set "RC=%errorlevel%"
exit /b %RC%

:EXTRACTFAIL
echo.
echo [ERRO] Nao consegui extrair o motor do arquivo. O .bat esta corrompido ou foi editado.
echo [ERROR] Could not extract the engine. The .bat file is corrupted or was edited.
pause
exit /b 1
#__PS_BEGIN__
param(
    [string]$SelfPath = '',
    [switch]$DryRun,
    [switch]$SelfTest,
    [string]$AutoKeys = '',
    [switch]$NoSplash,
    [string]$ScreenDump = '',
    [string]$Language = ''
)
# =====================================================================
#  FORTNITE OTIMIZADOR v2.1 - motor PowerShell (embutido no .bat)
#  Made by: Lina   |   Discord: kali_linax
#  so ASCII aqui (codepage do cmd zoa acento)
#  TODO: separar em modulos se crescer mais
#  -DryRun   : nao grava NADA no sistema (so mostra o que faria)
#  -SelfTest : bateria automatica de testes (usada no desenvolvimento)
# =====================================================================
$ErrorActionPreference = 'Continue'
$script:Version = '2.1'
$script:Dry = ([bool]$DryRun -or [bool]$SelfTest)
$script:Admin = $false
try {
    $script:Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

$script:Desktop = [Environment]::GetFolderPath('Desktop')
if (-not $script:Desktop) { $script:Desktop = Join-Path $env:USERPROFILE 'Desktop' }
$script:ToolsDir = Join-Path $script:Desktop 'Fortnite_Tools'
if ($script:Dry) {
    $script:BackupDir = Join-Path $env:TEMP 'FNO_DryRun_Backup'
} else {
    $script:BackupDir = Join-Path $script:Desktop 'Fortnite_Otimizador_Backup'
}
try { if (-not (Test-Path -LiteralPath $script:BackupDir)) { [void](New-Item -ItemType Directory -Force -Path $script:BackupDir) } } catch { }
$script:LogFile = Join-Path $script:BackupDir 'log.txt'
$script:StateFile = Join-Path $script:BackupDir 'state_v2.json'

# ---------------------------------------------------------------------
#  Saida colorida / log
# ---------------------------------------------------------------------
function Write-Out {
    param([string]$Text = '', [string]$Color = 'Gray', [switch]$NoNewLine)
    if ($NoNewLine) { Write-Host $Text -ForegroundColor $Color -NoNewline } else { Write-Host $Text -ForegroundColor $Color }
}
# Say traduz (L) antes de escrever; em portugues L nao faz nada
function Say {
    param([string]$Text = '', [string]$Color = 'Gray', [switch]$NoNewLine)
    Write-Out (L $Text) $Color -NoNewLine:$NoNewLine
}
function Write-Log {
    param([string]$Msg)
    try { Add-Content -LiteralPath $script:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg) -ErrorAction Stop } catch { }
}
function Say-Ok   { param([string]$T) $T = L $T; Write-Out ('  [OK] ' + $T) 'Green';  Write-Log ('OK ' + $T) }
function Say-Warn { param([string]$T) $T = L $T; Write-Out ('  [!]  ' + $T) 'Yellow'; Write-Log ('AVISO ' + $T) }
$script:BadMsgs = @()
function Say-Bad  { param([string]$T) $script:BadMsgs += $T; $T = L $T; Write-Out ('  [X]  ' + $T) 'Red'; Write-Log ('ERRO ' + $T) }
function Say-Info { param([string]$T) Write-Out ('       ' + (L $T)) 'Gray' }
function Say-Dry  { param([string]$T) Write-Out ('  [DRY] ' + $T) 'DarkYellow' }

# ---------------------------------------------------------------------
#  P/Invoke (timer, tela). C# 5 (compilador do PowerShell 5.1).
# ---------------------------------------------------------------------
if (-not ('FnoNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class FnoNative
{
    [DllImport("ntdll.dll")] static extern int NtQueryTimerResolution(out uint Min, out uint Max, out uint Cur);
    [DllImport("ntdll.dll")] static extern int NtSetTimerResolution(uint Desired, bool Set, out uint Cur);

    // {coarsest, finest, current} em unidades de 100ns (156250 = 15.625ms, 5000 = 0.5ms)
    public static uint[] TimerInfo()
    {
        uint mn, mx, cur;
        NtQueryTimerResolution(out mn, out mx, out cur);
        return new uint[] { mn, mx, cur };
    }

    public static uint SetTimer(uint desired)
    {
        uint cur;
        NtSetTimerResolution(desired, true, out cur);
        return cur;
    }

    // {media ms, maximo ms} de Thread.Sleep(1)
    public static double[] MeasureSleep(int samples)
    {
        Stopwatch sw = new Stopwatch();
        double sum = 0, max = 0;
        Thread.Sleep(1);
        for (int i = 0; i < samples; i++)
        {
            sw.Reset(); sw.Start();
            Thread.Sleep(1);
            sw.Stop();
            double ms = sw.Elapsed.TotalMilliseconds;
            sum += ms;
            if (ms > max) max = ms;
        }
        return new double[] { sum / samples, max };
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public ushort dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public uint dmFields;
        public int dmPositionX, dmPositionY;
        public uint dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public ushort dmLogPixels;
        public uint dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public uint dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi, EntryPoint = "EnumDisplaySettingsA")]
    static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Ansi, EntryPoint = "ChangeDisplaySettingsExA")]
    static extern int ChangeDisplaySettingsEx(string dev, ref DEVMODE dm, IntPtr hwnd, uint flags, IntPtr lParam);

    static DEVMODE NewDm()
    {
        DEVMODE dm = new DEVMODE();
        dm.dmDeviceName = new string(' ', 32);
        dm.dmFormName = new string(' ', 32);
        dm.dmSize = (ushort)Marshal.SizeOf(typeof(DEVMODE));
        return dm;
    }

    // {largura, altura, hz, bits}; null se falhar
    public static uint[] CurrentMode()
    {
        DEVMODE dm = NewDm();
        if (!EnumDisplaySettings(null, -1, ref dm)) return null;
        return new uint[] { dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency, dm.dmBitsPerPel };
    }

    // lista "LxA@Hz" de todos os modos (sem repetidos)
    public static string[] AllModes()
    {
        List<string> r = new List<string>();
        DEVMODE dm = NewDm();
        int i = 0;
        while (EnumDisplaySettings(null, i, ref dm))
        {
            string s = dm.dmPelsWidth + "x" + dm.dmPelsHeight + "@" + dm.dmDisplayFrequency;
            if (!r.Contains(s)) r.Add(s);
            i++;
            dm = NewDm();
        }
        return r.ToArray();
    }

    // 0 = ok. test=true so valida (nao muda nada)
    public static int SetMode(uint w, uint h, uint hz, bool test)
    {
        DEVMODE dm = NewDm();
        if (!EnumDisplaySettings(null, -1, ref dm)) return -100;
        dm.dmPelsWidth = w; dm.dmPelsHeight = h; dm.dmDisplayFrequency = hz;
        dm.dmFields = 0x80000 | 0x100000 | 0x400000; // largura | altura | frequencia
        uint flags = test ? 0x2u : 0x1u;             // CDS_TEST | CDS_UPDATEREGISTRY
        return ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, flags, IntPtr.Zero);
    }
}
'@ -ErrorAction Stop
}

# ---------------------------------------------------------------------
#  Executar comandos nativos (powercfg, netsh, bcdedit...) sem quebrar
# ---------------------------------------------------------------------
function Invoke-Native {
    param([string]$File, [string[]]$ArgList = @(), [switch]$Read)
    if ($script:Dry -and -not $Read) {
        Say-Dry ($File + ' ' + ($ArgList -join ' '))
        return [pscustomobject]@{ ExitCode = 0; Output = ''; Dry = $true }
    }
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = ''
    $code = -1
    try {
        $out = (& $File @ArgList 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } catch {
        $out = $_.Exception.Message
        $code = -1
    } finally {
        $ErrorActionPreference = $old
    }
    [pscustomobject]@{ ExitCode = $code; Output = $out; Dry = $false }
}

# ---------------------------------------------------------------------
#  Estado (backup exato de cada valor de registro alterado)
# ---------------------------------------------------------------------
function ConvertTo-Hash {
    param($O)
    if ($null -eq $O) { return $null }
    if ($O -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $O.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hash $p.Value }
        return $h
    }
    if (($O -is [System.Collections.IList]) -and -not ($O -is [string])) {
        $l = @()
        foreach ($i in $O) { $l += , (ConvertTo-Hash $i) }
        return , $l
    }
    return $O
}

function Load-State {
    $script:State = @{ Regs = @{}; Created = @(); Other = @{} }
    if (Test-Path -LiteralPath $script:StateFile) {
        try {
            $raw = Get-Content -LiteralPath $script:StateFile -Raw -ErrorAction Stop
            $h = ConvertTo-Hash (ConvertFrom-Json $raw)
            if ($h) {
                if ($h.Regs)    { $script:State.Regs = $h.Regs }
                if ($h.Created) { $script:State.Created = @($h.Created) }
                if ($h.Other)   { $script:State.Other = $h.Other }
            }
        } catch {
            Say-Warn ('state_v2.json ilegivel, comecando estado novo: ' + $_.Exception.Message)
            try { Copy-Item -LiteralPath $script:StateFile -Destination ($script:StateFile + '.corrompido') -Force } catch { }
        }
    }
}
function Save-State {
    if ($script:Dry) { return }
    try {
        $json = $script:State | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($script:StateFile, $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Say-Warn ('Nao salvei o estado: ' + $_.Exception.Message) }
}

# ---------------------------------------------------------------------
#  Registro (API .NET, visao 64 bits) - toda escrita passa por aqui
# ---------------------------------------------------------------------
function Split-RegPath {
    param([string]$P)
    $p2 = $P -replace '^Registry::', ''
    $p2 = $p2 -replace '^(HKEY_LOCAL_MACHINE|HKLM):?\\', 'HKLM\'
    $p2 = $p2 -replace '^(HKEY_CURRENT_USER|HKCU):?\\', 'HKCU\'
    $i = $p2.IndexOf('\')
    if ($i -lt 0) { $hive = $p2; $sub = '' } else { $hive = $p2.Substring(0, $i); $sub = $p2.Substring($i + 1) }
    $h = switch ($hive) { 'HKLM' { 'LocalMachine' } 'HKCU' { 'CurrentUser' } 'HKCR' { 'ClassesRoot' } 'HKU' { 'Users' } default { throw ('Hive invalido: ' + $P) } }
    [pscustomobject]@{ Hive = $h; Sub = $sub; Norm = ($hive + '\' + $sub) }
}
function Open-RegKey {
    param([string]$P, [switch]$Write, [switch]$Create)
    $s = Split-RegPath $P
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$s.Hive, [Microsoft.Win32.RegistryView]::Registry64)
    if ($Create) { return $base.CreateSubKey($s.Sub) }
    return $base.OpenSubKey($s.Sub, [bool]$Write)
}
function ConvertTo-RegKind {
    param([string]$T)
    switch ($T) {
        'DWord'        { [Microsoft.Win32.RegistryValueKind]::DWord }
        'QWord'        { [Microsoft.Win32.RegistryValueKind]::QWord }
        'String'       { [Microsoft.Win32.RegistryValueKind]::String }
        'ExpandString' { [Microsoft.Win32.RegistryValueKind]::ExpandString }
        'MultiString'  { [Microsoft.Win32.RegistryValueKind]::MultiString }
        'Binary'       { [Microsoft.Win32.RegistryValueKind]::Binary }
        default        { [Microsoft.Win32.RegistryValueKind]::String }
    }
}
# Le o valor atual: @{ KeyExists; Exists; Type; Value } (DWord sempre como uint32)
function Get-RegState {
    param([string]$P, [string]$N)
    $r = @{ KeyExists = $false; Exists = $false; Type = $null; Value = $null }
    $k = $null
    try { $k = Open-RegKey -P $P } catch { return $r }
    if ($null -eq $k) { return $r }
    try {
        $r.KeyExists = $true
        $names = $k.GetValueNames()
        $hit = $null
        foreach ($x in $names) { if ($x -ieq $N) { $hit = $x; break } }
        if ($null -ne $hit) {
            $r.Exists = $true
            $kind = $k.GetValueKind($hit)
            $v = $k.GetValue($hit, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $r.Type = $kind.ToString()
            if ($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord) { $v = [uint32]([BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$v), 0)) }
            elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) { $v = [Convert]::ToBase64String([byte[]]$v) }
            $r.Value = $v
        }
    } finally { $k.Close() }
    return $r
}
function Get-Reg {
    param([string]$P, [string]$N)
    $s = Get-RegState -P $P -N $N
    if ($s.Exists) { return $s.Value } else { return $null }
}
function Convert-ForKind {
    param([string]$T, $V)
    switch ($T) {
        'DWord'  { return [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$V), 0) }
        'QWord'  { return [BitConverter]::ToInt64([BitConverter]::GetBytes([uint64]$V), 0) }
        'Binary' { if ($V -is [string]) { return [Convert]::FromBase64String($V) } else { return [byte[]]$V } }
        'MultiString' { return [string[]]$V }
        default  { return [string]$V }
    }
}
# Guarda o valor ORIGINAL (so a 1a vez) antes de qualquer mudanca
function Record-Reg {
    param([string]$P, [string]$N)
    if ($script:Dry) { return }
    $s = Split-RegPath $P
    $key = $s.Norm + '|' + $N
    if ($script:State.Regs.ContainsKey($key)) { return }
    $cur = Get-RegState -P $P -N $N
    $rec = @{ Existed = $cur.Exists; Type = $cur.Type; Value = $cur.Value }
    if (-not $cur.KeyExists) {
        # acha o ancestral mais alto que ainda nao existe (p/ apagar no restore se ficar vazio)
        $parts = $s.Sub.Split('\')
        $acc = ''
        $top = $null
        for ($i = 0; $i -lt $parts.Length; $i++) {
            if ($acc) { $acc = $acc + '\' + $parts[$i] } else { $acc = $parts[$i] }
            $probe = Open-RegKey -P ($s.Norm.Split('\')[0] + '\' + $acc)
            if ($null -eq $probe) { $top = $s.Norm.Split('\')[0] + '\' + $acc; break } else { $probe.Close() }
        }
        if ($top -and ($script:State.Created -notcontains $top)) { $script:State.Created = @($script:State.Created) + $top }
    }
    $script:State.Regs[$key] = $rec
}
function Set-Reg {
    param([string]$P, [string]$N, [string]$T, $V)
    if ($script:Dry) { Say-Dry ('reg {0} : {1} = {2} ({3})' -f $P, $N, $V, $T); return $true }
    try {
        Record-Reg -P $P -N $N
        $k = Open-RegKey -P $P -Create -Write
        if ($null -eq $k) { throw 'chave nao abriu' }
        try { $k.SetValue($N, (Convert-ForKind $T $V), (ConvertTo-RegKind $T)) } finally { $k.Close() }
        $chk = Get-RegState -P $P -N $N
        $ok = $chk.Exists
        if ($ok -and ($T -eq 'DWord' -or $T -eq 'QWord')) { $ok = ([uint64]$chk.Value -eq [uint64]$V) }
        elseif ($ok -and $T -eq 'String') { $ok = ([string]$chk.Value -eq [string]$V) }
        if (-not $ok) { throw 'valor nao ficou gravado (permissao?)' }
        Write-Log ('REG {0} : {1} = {2}' -f $P, $N, $V)
        return $true
    } catch {
        Say-Bad ('Falhou {0} : {1} -> {2}' -f $P, $N, $_.Exception.Message)
        return $false
    }
}
function Remove-RegValue {
    param([string]$P, [string]$N)
    if ($script:Dry) { Say-Dry ('reg delete {0} : {1}' -f $P, $N); return $true }
    try {
        Record-Reg -P $P -N $N
        $k = Open-RegKey -P $P -Write
        if ($null -eq $k) { return $true }
        try { $k.DeleteValue($N, $false) } finally { $k.Close() }
        Write-Log ('REGDEL {0} : {1}' -f $P, $N)
        return $true
    } catch { Say-Bad ('Falhou apagar {0} : {1} -> {2}' -f $P, $N, $_.Exception.Message); return $false }
}
function Restore-RegOne {
    param([string]$Key)
    if (-not $script:State.Regs.ContainsKey($Key)) { return $false }
    $rec = $script:State.Regs[$Key]
    $i = $Key.LastIndexOf('|')
    $path = $Key.Substring(0, $i)
    $name = $Key.Substring($i + 1)
    if ($script:Dry) { Say-Dry ('restaurar ' + $Key); return $true }
    try {
        if ($rec.Existed) {
            $k = Open-RegKey -P $path -Create -Write
            try { $k.SetValue($name, (Convert-ForKind $rec.Type $rec.Value), (ConvertTo-RegKind $rec.Type)) } finally { $k.Close() }
        } else {
            $k = Open-RegKey -P $path -Write
            if ($null -ne $k) { try { $k.DeleteValue($name, $false) } finally { $k.Close() } }
        }
        return $true
    } catch { Say-Bad ('Falhou restaurar {0}: {1}' -f $Key, $_.Exception.Message); return $false }
}
function Test-KeyTreeEmpty {
    param($Key)
    if ($Key.ValueCount -gt 0) { return $false }
    foreach ($n in $Key.GetSubKeyNames()) {
        $sk = $Key.OpenSubKey($n)
        if ($null -eq $sk) { continue }
        try { if (-not (Test-KeyTreeEmpty $sk)) { return $false } } finally { $sk.Close() }
    }
    return $true
}
function Remove-EmptyCreatedKeys {
    if ($script:Dry) { return }
    $left = @()
    foreach ($c in @($script:State.Created)) {
        try {
            $s = Split-RegPath $c
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$s.Hive, [Microsoft.Win32.RegistryView]::Registry64)
            $k = $base.OpenSubKey($s.Sub)
            if ($null -eq $k) { continue }
            $empty = Test-KeyTreeEmpty $k
            $k.Close()
            if ($empty) { $base.DeleteSubKeyTree($s.Sub, $false) } else { $left += $c }
        } catch { $left += $c }
    }
    $script:State.Created = @($left)
}

# --- listas de valores {P,N,T,V}: aplicar / conferir / desfazer ---------
function Rg {
    param([string]$P, [string]$N, [string]$T, $V)
    @{ P = $P; N = $N; T = $T; V = $V }
}
function Apply-Regs {
    param($Regs)
    $ok = $true
    foreach ($r in $Regs) { if (-not (Set-Reg -P $r.P -N $r.N -T $r.T -V $r.V)) { $ok = $false } }
    return $ok
}
function Test-Regs {
    param($Regs)
    foreach ($r in $Regs) {
        $cur = Get-RegState -P $r.P -N $r.N
        if (-not $cur.Exists) { return $false }
        if ($r.T -eq 'DWord' -or $r.T -eq 'QWord') { if ([uint64]$cur.Value -ne [uint64]$r.V) { return $false } }
        else { if ([string]$cur.Value -ne [string]$r.V) { return $false } }
    }
    return $true
}
function Undo-Regs {
    param($Regs)
    $any = $false
    foreach ($r in $Regs) {
        $s = Split-RegPath $r.P
        $key = $s.Norm + '|' + $r.N
        if ($script:State.Regs.ContainsKey($key)) {
            if (Restore-RegOne -Key $key) { $any = $true; if (-not $script:Dry) { $script:State.Regs.Remove($key) } }
        }
    }
    Remove-EmptyCreatedKeys
    Save-State
    return $any
}
function Restore-AllRegs {
    $n = 0
    foreach ($k in @($script:State.Regs.Keys)) { if (Restore-RegOne -Key $k) { $n++ } }
    Remove-EmptyCreatedKeys
    if (-not $script:Dry) { $script:State.Regs = @{}; $script:State.Created = @() }
    Save-State
    return $n
}

# ---------------------------------------------------------------------
#  Utilitarios
# ---------------------------------------------------------------------
function Test-Cmd { param([string]$Name) return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Get-Guid {
    param([string]$Text)
    if ($Text -match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') { return $Matches[0] }
    return $null
}
function Wrap-Text {
    param([string]$Text, [int]$Width)
    $out = @()
    if (-not $Text) { return $out }
    $Text = L $Text
    foreach ($para in ($Text -split "`n")) {
        $line = ''
        foreach ($word in ($para -split ' ')) {
            if (($line.Length + $word.Length + 1) -gt $Width -and $line.Length -gt 0) { $out += $line; $line = $word }
            elseif ($line.Length -eq 0) { $line = $word }
            else { $line = $line + ' ' + $word }
        }
        $out += $line
    }
    return $out
}
function New-Backup-Copy {
    param([string]$File, [string]$Prefix)
    if (-not (Test-Path -LiteralPath $File)) { return }
    if ($script:Dry) { Say-Dry ('backup de ' + $File); return }
    try {
        if (-not (Test-Path -LiteralPath ($File + '.bak'))) { Copy-Item -LiteralPath $File -Destination ($File + '.bak') -Force }
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Copy-Item -LiteralPath $File -Destination (Join-Path $script:BackupDir ($Prefix + '_' + $stamp + '.ini')) -Force
    } catch { Say-Warn ('backup de ' + $File + ' falhou: ' + $_.Exception.Message) }
}

# =====================================================================
#  IDIOMA (pt / en)
#  O fonte continua em portugues. A traducao acontece NA SAIDA (Say,
#  menus, textos, confirmacoes, arte), em 3 camadas:
#   1) frase exata   2) molde com {0} (textos montados com -f)
#   3) trechos conhecidos (textos montados com +)
#  Dicionario: gerado pelo build (i18n/en_*.json -> $script:EnTsv).
# =====================================================================
$script:UiLang = 'pt'
$script:EnDict = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:EnTpl = @()
$script:EnFrag = @()
$script:L10nMemo = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:L10nMiss = $null
$script:PtWordRx = New-Object regex('\b(nao|voce|para|com|sem|seu|sua|seus|suas|mais|menos|esta|estao|sera|agora|ligado|ligada|desligado|desligada|aplicar|aplicado|aplicada|desfazer|voltar|reinicie|reiniciar|plano|energia|rede|tela|jogo|arquivo|pasta|ativo|ativa|nada|tudo|isso|este|esse|pelo|pela|quando|entao|depois|antes|ainda|tambem|dos|das|uma|pode|precisa|deixe|ligue|desligue|nucleos|padrao|configuracao|configuracoes|otimizacao|otimizacoes|erro|aviso|falha|falhou|concluido|aguarde|pressione|qualquer|tecla|escolha|escolher|mover|pular|sair|sim|abrir|instalar|encontrado|encontrada|detectado|detectada|atual|valor|maximo|minimo|nenhum|nenhuma|guia|menu principal|reinicio|pendente)\b', 'IgnoreCase')

function Initialize-Lang {
    if ($script:EnDict.Count -gt 0) { return }
    if (-not $script:EnTsv) { return }
    foreach ($line in ($script:EnTsv -split "`r?`n")) {
        if (-not $line) { continue }
        $p = $line.IndexOf("`t")
        if ($p -lt 1) { continue }
        $script:EnDict[$line.Substring(0, $p)] = $line.Substring($p + 1)
    }
    $tpl = New-Object System.Collections.ArrayList
    $frag = New-Object System.Collections.ArrayList
    foreach ($k in @($script:EnDict.Keys)) {
        $en = $script:EnDict[$k]
        if ($k -match '\{\d+(,-?\d+)?(:[^}]*)?\}') {
            $lit = [regex]::Replace($k, '\{\d+(,-?\d+)?(:[^}]*)?\}', '')
            if (($lit -replace '[^A-Za-z]', '').Length -lt 3) { continue }
            $parts = [regex]::Split($k, '(\{\d+(?:,-?\d+)?(?::[^}]*)?\})')
            $rx = '^'
            $order = @()
            foreach ($pp in $parts) {
                if ($pp -match '^\{(\d+)') { $rx += '(.*?)'; $order += [int]$Matches[1] }
                else { $rx += [regex]::Escape($pp) }
            }
            [void]$tpl.Add(@{ Rx = (New-Object regex(($rx + '$'), 'Singleline')); Order = $order; En = $en; Len = $lit.Length })
        } elseif ($k.Length -ge 8 -and $k.Contains(' ') -and $k -cne $en) {
            [void]$frag.Add(@{ Pt = $k; En = $en })
        }
    }
    $script:EnTpl = @($tpl | Sort-Object { - $_.Len })
    $script:EnFrag = @($frag | Sort-Object { - $_.Pt.Length })
}

function Set-UiLang {
    param([string]$Code)
    if ($Code -eq 'en') { Initialize-Lang; $script:UiLang = 'en' } else { $script:UiLang = 'pt' }
    $script:L10nMemo.Clear()
    $script:ArtCache = @{}
}

# Traduz um texto de interface (no-op em portugues)
function L {
    param([string]$T)
    if ($script:UiLang -ne 'en' -or -not $T) { return $T }
    $m = $null
    if ($script:L10nMemo.TryGetValue($T, [ref]$m)) { return $m }
    $r = Convert-ToEn $T
    $script:L10nMemo[$T] = $r
    return $r
}
function Get-ExactEn {
    param([string]$Core)
    $v = $null
    if ($script:EnDict.TryGetValue($Core, [ref]$v)) { return $v }
    return $null
}
function Convert-ToEn {
    param([string]$T)
    $core = $T.Trim()
    if (-not $core) { return $T }
    $lead = $T.Substring(0, $T.Length - $T.TrimStart().Length)
    $trail = $T.Substring($T.TrimEnd().Length)
    $v = Get-ExactEn $core
    if ($null -ne $v) { return ($lead + $v + $trail) }
    foreach ($tp in $script:EnTpl) {
        $mm = $tp.Rx.Match($core)
        if (-not $mm.Success) { continue }
        $out = $tp.En
        for ($g = 0; $g -lt $tp.Order.Count; $g++) {
            $val = $mm.Groups[$g + 1].Value
            $x = Get-ExactEn $val.Trim()
            if ($null -ne $x) { $val = $val.Replace($val.Trim(), $x) }
            $out = [regex]::Replace($out, ('\{' + $tp.Order[$g] + '(,-?\d+)?(:[^}]*)?\}'), $val.Replace('$', '$$'))
        }
        return ($lead + $out + $trail)
    }
    $out = $core
    foreach ($f in $script:EnFrag) { if ($out.Contains($f.Pt)) { $out = $out.Replace($f.Pt, $f.En) } }
    if ($null -ne $script:L10nMiss -and $script:PtWordRx.IsMatch($out)) { [void]$script:L10nMiss.Add($core) }
    return ($lead + $out + $trail)
}

# ---------------------------------------------------------------------
#  Preferencia salva (arquivo na pasta de backup; em -DryRun vai p/ TEMP)
# ---------------------------------------------------------------------
function Get-SavedLang {
    try {
        $f = Join-Path $script:BackupDir 'idioma.txt'
        if (Test-Path -LiteralPath $f) { $v = ([IO.File]::ReadAllText($f)).Trim(); if ($v -eq 'en' -or $v -eq 'pt') { return $v } }
    } catch { }
    try { if ((Get-Culture).TwoLetterISOLanguageName -ne 'pt') { return 'en' } } catch { }
    return 'pt'
}
function Save-Lang {
    try { [IO.File]::WriteAllText((Join-Path $script:BackupDir 'idioma.txt'), $script:UiLang) } catch { }
}

# Tela de idioma: aparece ANTES do carregamento. -Language pt|en pula a tela.
function Select-Language {
    if ($Language -eq 'en' -or $Language -eq 'pt') { Set-UiLang $Language; return }
    $def = Get-SavedLang
    if (-not $script:UseKeys) {
        $a = Read-Host '  Idioma / Language  [1] Portugues  [2] English'
        if ($a -match '^\s*2|^\s*[eE]') { Set-UiLang 'en' } elseif ($a -match '^\s*1|^\s*[pP]') { Set-UiLang 'pt' } else { Set-UiLang $def }
        Save-Lang
        return
    }
    $sel = 0
    if ($def -eq 'en') { $sel = 1 }
    $opts = @(@{ C = 'pt'; T = 'Portugues (Brasil)'; H = 'Tudo em portugues' }, @{ C = 'en'; T = 'English'; H = 'Everything in English' })
    $g = $script:G
    $hid = $false
    if ($script:CanCursor) { try { [Console]::CursorVisible = $false; $hid = $true } catch { } }
    try {
        $first = $true
        while ($true) {
            $w = Get-UiWidth
            if ($script:CanCursor) { if ($first) { Clear-Screen; $first = $false }; Set-Cur 0 0 } else { Say ('-' * 60) 'DarkGray' }
            $logo = Get-ArtBlock 'logo' $w ((Get-UiHeight) - 16)
            if ($logo) { [void](Write-Block $logo $w) } else { Say '' }
            Say ''
            $in = 56
            $rows = @()
            $rows += , @(@{ T = (Center 'IDIOMA  /  LANGUAGE' $in); F = 'White' })
            $rows += , @(@{ T = '' })
            for ($i = 0; $i -lt $opts.Count; $i++) {
                if ($i -eq $sel) { $rows += , @(@{ T = ('   ' + $g.Ptr + '  '); F = 'Yellow' }, @{ T = $opts[$i].T; F = 'Cyan' }, @{ T = ('   - ' + $opts[$i].H); F = 'DarkGray' }) }
                else { $rows += , @(@{ T = '      '; F = 'Gray' }, @{ T = $opts[$i].T; F = 'Gray' }) }
            }
            $rows += , @(@{ T = '' })
            $rows += , @(@{ T = (Center ($g.ArU + $g.ArD + ' + Enter    |    1 / 2') $in); F = 'DarkGray' })
            $box = New-BoxBlock $rows $in 'Cyan'
            [void](Write-Block (Get-CenteredBlock $box $w) $w)
            Say (' ' * $w)
            Write-Credits $w
            $k = Read-Key
            switch ($k.Key) {
                'UpArrow'   { $sel = 0 }
                'DownArrow' { $sel = 1 }
                'LeftArrow' { $sel = 0 }
                'RightArrow' { $sel = 1 }
                'Tab'       { $sel = 1 - $sel }
                'Enter'     { Set-UiLang $opts[$sel].C; Save-Lang; return }
                'Escape'    { Set-UiLang $opts[$sel].C; return }
                default {
                    $c = ([string]$k.KeyChar).ToLower()
                    if ($c -eq '1' -or $c -eq 'p') { Set-UiLang 'pt'; Save-Lang; return }
                    if ($c -eq '2' -or $c -eq 'e') { Set-UiLang 'en'; Save-Lang; return }
                }
            }
        }
    } finally {
        if ($hid) { try { [Console]::CursorVisible = $true } catch { } }
        if ($script:CanCursor) { Clear-Screen }
    }
}

# Dicionario pt -> en (gerado pelo build a partir de i18n/*.json)
$script:EnTsv = @'
AVISO	WARNING
ERRO	ERROR
state_v2.json ilegivel, comecando estado novo:	state_v2.json unreadable, starting new state:
Nao salvei o estado:	Failed to save state:
Hive invalido:	Invalid hive:
chave nao abriu	key did not open
valor nao ficou gravado (permissao?)	value not saved (permission?)
Falhou {0} : {1} -> {2}	Failed {0} : {1} -> {2}
Falhou apagar {0} : {1} -> {2}	Failed to delete {0} : {1} -> {2}
Falhou restaurar {0}: {1}	Failed to restore {0}: {1}
backup de	backup of
Rede:	Network:
Tela:	Display:
GPU nao detectada	GPU not detected
FORTNITE OTIMIZADOR v{0}  -  Made by: {1}  |  Discord: {2}	FORTNITE OPTIMIZER v{0}  -  Made by: {1}  |  Discord: {2}
FORTNITE OTIMIZADOR	FORTNITE OPTIMIZER
[MODO TESTE - nada e gravado]	[TEST MODE - nothing is written]
[TODOS]	[ALL]
[CABO]	[WIRED]
[NOTEBOOK]	[LAPTOP]
Setas	Arrow keys
Numero (vazio = voltar)	Number (empty = back)
NA	N/A
mais acima	more above
mais abaixo	more below
Setas: mover | Enter: escolher | Esc: voltar | 0-9: pular	Arrows: move | Enter: select | Esc: back | 0-9: jump
SIM	YES
NAO	NO
setas/Tab alternam  |  Enter confirma  |  S / N	arrows/Tab switch  |  Enter confirms  |  Y / N
Pressione qualquer tecla para continuar...	Press any key to continue...
Setas: rolar | PgUp/PgDn: pagina | Esc: voltar	Arrows: scroll | PgUp/PgDn: page | Esc: back
DIAGNOSTICO	DIAGNOSTICS
ENERGIA	POWER
REDE	NETWORK
SISTEMA	SYSTEM
APLICAR TUDO	APPLY ALL
GUIAS	GUIDES
RESTAURAR	RESTORE
Fortnite Otimizador	Fortnite Optimizer
powercfg nao aceitou	powercfg rejected it
(normal se o hardware nao suporta)	(normal if hardware doesn't support it)
Plano de energia original reativado.	Original power plan reactivated.
Aplique primeiro o plano de energia proprio.	Apply the custom power plan first.
CPU mantida sempre acordada (idle desabilitado).	CPU kept always awake (idle disabled).
Idle da CPU de volta ao normal.	CPU idle back to normal.
e registrar tarefa	and register task
Tarefa criada e iniciada (timer no minimo a cada logon).	Task created and started (timer at minimum every logon).
Falhou:	Failed:
remover tarefa	remove task
Timer forcado removido.	Forced timer removed.
Timer do Windows: melhor possivel = {0:N3} ms | padrao = {1:N3} ms | atual (neste processo) = {2:N3} ms	Windows Timer: best possible = {0:N3} ms | default = {1:N3} ms | current (this process) = {2:N3} ms
Sleep(1) real: media {0:N2} ms, pior {1:N2} ms	Sleep(1) actual: average {0:N2} ms, worst {1:N2} ms
(com o timer forcado ativo a media fica perto de 1-2 ms; sem ele ~15 ms. No Win11 o pedido e por processo,	(with forced timer active the average is around 1-2 ms; without it ~15 ms. On Win11 the request is per process,
a chave global do item "Timer global" faz o pedido do jogo valer para o sistema todo.)	the global key for the "Global timer" item makes the game's request apply system-wide.)
Valor atual:	Current value:
38 (0x26)  curto + variavel + boost 3:1	38 (0x26)  short + variable + boost 3:1
42 (0x2A)  curto + FIXO + boost 3:1  (mais agressivo)	42 (0x2A)  short + FIXED + boost 3:1  (more aggressive)
2  (padrao do Windows cliente)	2  (Windows client default)
O padrao do Windows cliente (2) ja resolve para curto+variavel; 0x26 e quase igual ao padrao. Efeito pequeno.	Windows client default (2) already resolves to short+variable; 0x26 is almost the same as default. Small effect.
Quantum fixo: alguns relatam menos latencia e melhor 1% low; em PC com muita coisa aberta pode prejudicar multitarefa. Testes independentes nao mostram diferenca estatistica clara.	Fixed quantum: some report less latency and better 1% low; on a PC with lots open it can hurt multitasking. Independent tests show no clear statistical difference.
Volta ao valor padrao.	Restores to default value.
Nenhum dispositivo USB/HID com gerenciamento de energia encontrado.	No USB/HID device with power management found.
desligar economia:	turn off power saving:
nao consegui:	failed:
Simulado (modo teste).	Simulated (test mode).
Economia de energia desligada em {0} dispositivo(s) USB/HID.	Power saving turned off on {0} USB/HID device(s).
Nada a desfazer (nenhum dispositivo alterado por esta versao).	Nothing to undo (no device changed by this version).
religar economia:	turn power saving back on:
Economia de energia USB restaurada.	USB power saving restored.
PADRAO	DEFAULT
ATIVAR MSI em todos os dispositivos abaixo que ainda nao estao ON	ENABLE MSI on all devices below that are not yet ON
Grava MSISupported=1 na chave do dispositivo (o mesmo que o MSI Utility faz). Precisa reiniciar. Se algum driver nao suportar MSI o Windows ignora; em caso raro de tela preta, entre no Modo Seguro e use Desfazer/Restaurar.	Writes MSISupported=1 to the device key (same as MSI Utility does). Requires restart. If any driver doesn't support MSI Windows ignores it; in rare case of black screen, enter Safe Mode and use Undo/Restore.
Estado atual do MSI: {0}. (PADRAO = o driver decide; NVIDIA moderna e a maioria das placas de rede/USB ja usam MSI sozinhas.) Enter alterna este dispositivo.	Current MSI state: {0}. (DEFAULT = driver decides; modern NVIDIA and most network/USB cards already use MSI on their own.) Enter toggles this device.
Voltar	Back
MSI MODE (interrupcoes)	MSI MODE (interrupts)
Menos DPC/ISR compartilhado = menos micro-stutter. Ganho tipico: pequeno. Exige reboot.	Less shared DPC/ISR = less micro-stutter. Typical gain: small. Requires reboot.
MSI ativado:	MSI enabled:
Reinicie o PC para valer.	Restart the PC for it to take effect.
Desfazer MSI em	Undo MSI on
Alterado. Reinicie.	Changed. Restart.
Ativar MSI em	Enable MSI on
Ativado. Reinicie.	Enabled. Restart.
desligar Enhancements em ate {0} endpoint(s)	turn off Enhancements on up to {0} endpoint(s)
Enhancements desligados em {0} dispositivo(s).	Enhancements turned off on {0} device(s).
{0} dispositivo(s) protegido(s) pelo Windows - nesses use Som > Propriedades > Aprimoramentos.	{0} device(s) protected by Windows - on those use Sound > Properties > Enhancements.
Sem backup de audio (nunca aplicado).	No audio backup (never applied).
restaurar audio	restore audio
Audio restaurado.	Audio restored.
BCDEdit de volta ao padrao (reinicie).	BCDEdit back to default (restart).
BCDEDIT AVANCADO (alto risco)	BCDEDIT ADVANCED (high risk)
Resultado MISTO em testes: ajuda em alguns PCs, piora FPS/stutter em outros. Teste 1 por vez.	MIXED results in tests: helps on some PCs, worsens FPS/stutter on others. Test 1 at a time.
Garantir que useplatformclock NAO esta forcado (apaga o valor)	Ensure useplatformclock is NOT forced (deletes the value)
DESFAZER tudo (volta ao padrao)	UNDO everything (restores to default)
Desliga o tick dinamico: agenda em intervalos fixos. Mais previsivel, mais consumo em idle. Ja causou queda de FPS em relatos de Overclock.net/Blur Busters.	Disables dynamic tick: schedules at fixed intervals. More predictable, higher idle consumption. Has caused FPS drops in Overclock.net/Blur Busters reports.
Politica de sincronia do TSC entre nucleos. Evidencia fraca/mista; alguns dizem que ajuda a estabilizar frametime.	TSC sync policy between cores. Weak/mixed evidence; some say it helps stabilize frametime.
Windows moderno ja NAO forca o HPET por padrao. Este item so apaga o valor caso alguem tenha ligado (nao ha ganho em ligar).	Modern Windows no longer forces HPET by default. This item only deletes the value if someone enabled it (no gain in enabling).
Restaura o valor anterior (ou apaga o valor) dos tres itens.	Restores the previous value (or deletes the value) of all three items.
Modo atual: {0}x{1} @ {2} Hz	Current mode: {0}x{1} @ {2} Hz
Maximo que o Windows oferece nesta resolucao: {0} Hz (em qualquer resolucao: {1} Hz)	Maximum Windows offers at this resolution: {0} Hz (at any resolution: {1} Hz)
Ja esta no maximo dessa resolucao.	Already at the maximum for this resolution.
Sua tela chega a {0} Hz em outra resolucao; teste trocar a resolucao ou crie o modo com CRU / Painel da GPU.	Your display reaches {0} Hz at another resolution; try changing resolution or create the mode with CRU / GPU Control Panel.
Se o monitor tem mais Hz que isso, use cabo DisplayPort, ative a taxa no menu OSD do monitor e/ou crie o modo no painel da GPU.	If your monitor has more Hz than this, use DisplayPort cable, enable the rate in the monitor's OSD menu and/or create the mode in the GPU control panel.
Trocar para {0}x{1} @ {2} Hz agora? (a tela pisca; volta sozinha se voce nao confirmar em 15 s)	Switch to {0}x{1} @ {2} Hz now? (screen flickers; reverts itself if you don't confirm in 15 s)
O driver recusou o modo (codigo	Driver rejected the mode (code
Falhou (codigo	Failed (code
Ficou bom? Manter {0} Hz?	Looks good? Keep {0} Hz?
Voltei para o modo anterior.	Reverted to the previous mode.
Tela em {0} Hz.	Display at {0} Hz.
Tela {0}x{1} {2}->{3} Hz	Display {0}x{1} {2}->{3} Hz
Taxa de atualizacao da tela no MAXIMO	Display refresh rate at MAXIMUM
Maior ganho isolado de latencia: cada Hz a mais reduz o tempo entre quadros (60Hz = 16,7 ms; 144Hz = 6,9 ms; 240Hz = 4,2 ms). Detecta o maior Hz que o Windows oferece e troca com teste e confirmacao (volta sozinho se a tela ficar preta).	Largest isolated latency gain: each extra Hz reduces time between frames (60Hz = 16.7 ms; 144Hz = 6.9 ms; 240Hz = 4.2 ms). Detects the highest Hz Windows offers and switches with test and confirmation (reverts itself if screen goes black).
Game Mode ON + gravacao em 2o plano (Game DVR) OFF	Game Mode ON + background recording (Game DVR) OFF
Liga o Game Mode, desliga o Game DVR/captura em fundo e o "FSE behavior" global (Fullscreen Optimizations). No Ryzen X3D de 2 CCDs a Xbox Game Bar e mantida, porque o driver 3D V-Cache da AMD usa a Game Bar para detectar jogos.	Turns on Game Mode, turns off Game DVR/background capture and global "FSE behavior" (Fullscreen Optimizations). On Ryzen X3D with 2 CCDs, Xbox Game Bar is kept because AMD's 3D V-Cache driver uses Game Bar to detect games.
Plano de energia OTIMIZADO (perfil automatico do seu CPU)	OPTIMIZED power plan (automatic profile for your CPU)
Cria/atualiza o plano "Fortnite Otimizador" com ~20 configuracoes avancadas conferidas no SEU Windows (boost agressivo, EPP maximo, sem core parking, USB/USB3/PCIe/Wi-Fi/HD sem economia, resfriamento ativo, Power Throttling OFF). O perfil muda conforme o CPU: Intel classico, Intel hibrido P+E, Ryzen, Ryzen X3D de 2 CCDs (que NAO pode desestacionar nucleos). Seu plano atual nao e alterado; o Desfazer volta pra ele. Veja o item abaixo para escolher/exportar/importar.	Creates/updates the "Fortnite Optimizer" plan with ~20 advanced settings tailored to YOUR Windows (aggressive boost, max EPP, no core parking, USB/USB3/PCIe/Wi-Fi/HD without power saving, active cooling, Power Throttling OFF). Profile varies by CPU: classic Intel, Intel hybrid P+E, Ryzen, Ryzen X3D with 2 CCDs (which cannot unpark cores). Your current plan is not changed; Undo reverts to it. See the item below to choose/export/import.
Plano de energia: escolher perfil, ver tudo, EXPORTAR / IMPORTAR .pow	Power plan: choose profile, see all, EXPORT / IMPORT .pow
Menu completo do plano de energia: aplica o perfil recomendado, deixa escolher outro (Intel classico / hibrido / Ryzen / X3D 2 CCDs), mostra cada configuracao com o motivo, exporta o plano para um arquivo .pow (para compartilhar) e importa um .pow.	Complete power plan menu: applies recommended profile, lets you choose another (classic Intel / hybrid / Ryzen / X3D 2 CCDs), shows each setting with reason, exports plan to a .pow file (to share) and imports a .pow.
Timer global: pedido de resolucao do jogo vale p/ o sistema todo	Global timer: game resolution request applies to entire system
A partir do Win10 2004/Win11 o timer de 0,5 ms pedido pelo jogo passou a valer so p/ o processo dele. GlobalTimerResolutionRequests=1 restaura o comportamento global (uma chave, nenhum programa rodando). Sem efeito no Win10 antigo.	From Win10 2004/Win11 onwards, the 0.5 ms timer requested by the game only applies to its process. GlobalTimerResolutionRequests=1 restores global behavior (one key, no program running). No effect on old Win10.
Timer FORCADO no minimo (tarefa agendada, sem baixar .exe)	Timer FORCED to minimum (scheduled task, no .exe download)
Tarefa no logon (PowerShell nativo, 0 download) que pede a MENOR resolucao possivel via NtSetTimerResolution. Custo real: CPU acorda ~2000x/s em vez de ~64x/s, mais consumo em idle e bateria. Combine com o item acima; se o jogo ja pede sozinho, o ganho extra e pequeno. Use "Medir timer" no Diagnostico para conferir.	Task at logon (native PowerShell, 0 download) that requests the LOWEST possible resolution via NtSetTimerResolution. Real cost: CPU wakes ~2000x/s instead of ~64x/s, more idle and battery consumption. Combine with the item above; if the game already requests it, extra gain is small. Use "Measure timer" in Diagnostics to check.
Mouse 1:1 no Windows (Enhance Pointer Precision OFF)	Mouse 1:1 on Windows (Enhance Pointer Precision OFF)
HONESTO: o Fortnite usa raw input e NAO tem aceleracao de mouse no PC, entao isto NAO muda a mira dentro do jogo; so deixa o cursor de desktop/menu/loja 1:1. Para a mira o que importa: DPI fixo (400-1600), polling 1000 Hz+ no software do mouse e sensibilidade no proprio jogo.	HONEST: Fortnite uses raw input and has NO mouse acceleration on PC, so this does NOT change aim in-game; only makes desktop/menu/shop cursor 1:1. For aim what matters: fixed DPI (400-1600), 1000 Hz+ polling in mouse software and sensitivity in the game itself.
Efeitos visuais do Windows no minimo (sem transparencia/animacao)	Windows visual effects at minimum (no transparency/animation)
Menos trabalho para o DWM. Ganho real so em GPU integrada/PC fraco (+2 a 5% FPS); em GPU dedicada e minimo. Muda a aparencia do Windows (sem transparencia).	Less work for DWM. Real gain only on integrated GPU/weak PC (+2 to 5% FPS); on dedicated GPU it's minimal. Changes Windows appearance (no transparency).
Fortnite sempre na GPU de alto desempenho (Configuracoes > Graficos)	Fortnite always on high-performance GPU (Settings > Graphics)
Importante em notebooks/PCs com placa integrada + dedicada: garante que o jogo NAO rode na integrada. Precisa achar o FortniteClient-Win64-Shipping.exe.	Important on laptops/PCs with integrated + dedicated GPU: ensures the game does NOT run on integrated. Needs to find FortniteClient-Win64-Shipping.exe.
Fullscreen Optimizations OFF no exe do Fortnite	Fullscreen Optimizations OFF on Fortnite exe
Marca DISABLEDXMAXIMIZEDWINDOWEDMODE no exe. No Win11 24H2/25H2 o modo "Independent Flip" ja evita o compositor em muitos casos, entao o ganho hoje e menor que no Win10; o item so garante o comportamento antigo. Use tambem "Tela cheia" (nao janela) no jogo.	Sets DISABLEDXMAXIMIZEDWINDOWEDMODE on exe. On Win11 24H2/25H2 "Independent Flip" mode already avoids the compositor in many cases, so gain today is less than on Win10; the item only guarantees the old behavior. Also use "Fullscreen" (not windowed) in the game.
MMCSS: prioridade "Games" + SystemResponsiveness=10	MMCSS: "Games" priority + SystemResponsiveness=10
Reserva mais CPU/GPU para tarefas multimidia registradas como Games. Nao ha prova de que o Fortnite use essa classe do MMCSS; efeito pequeno/nao comprovado. Mantido por ser seguro e reversivel.	Reserves more CPU/GPU for multimedia tasks registered as Games. No proof that Fortnite uses this MMCSS class; small/unproven effect. Kept because it's safe and reversible.
Win32PrioritySeparation (fatia de CPU do app em foco)	Win32PrioritySeparation (CPU slice of focused app)
Tweak classico. O padrao do Windows cliente ja e "curto+variavel"; 38 (0x26) e quase igual. 42 (0x2A) usa quantum FIXO e e o unico que muda de verdade, com resultados mistos em testes. Voce escolhe o valor.	Classic tweak. Windows client default is already "short+variable"; 38 (0x26) is almost the same. 42 (0x2A) uses FIXED quantum and is the only one that truly changes, with mixed test results. You choose the value.
Prioridade ALTA fixa p/ o Fortnite (CPU + disco) via registro	HIGH fixed priority for Fortnite (CPU + disk) via registry
Grava PerfOptions (CpuPriorityClass=High, IoPriority=High) para o FortniteClient-Win64-Shipping.exe: o Windows ja cria o processo com prioridade alta, sem programa extra. O Easy Anti-Cheat bloqueia mudar prioridade de fora com o jogo aberto, mas isto e aplicado na criacao. Nao ha relato conhecido de ban por PerfOptions; a Epic nao documenta. Se o EAC reclamar, desfaca.	Writes PerfOptions (CpuPriorityClass=High, IoPriority=High) for FortniteClient-Win64-Shipping.exe: Windows already creates the process with high priority, no extra program. Easy Anti-Cheat blocks changing priority from outside with the game open, but this is applied at creation. No known reports of bans for PerfOptions; Epic doesn't document. If EAC complains, undo.
HAGS: agendamento de GPU acelerado por hardware	HAGS: hardware-accelerated GPU scheduling
Deixa a GPU gerenciar a propria fila. OBRIGATORIO para DLSS Frame Generation (RTX 40/50): nao desligue se voce usa FG em outros jogos. Na latencia pura o efeito e pequeno e varia (+-1 a 2%, depende do driver). Por isso NAO entra no "Aplicar tudo". Teste com o CapFrameX antes de decidir. Precisa reiniciar.	Lets the GPU manage its own queue. REQUIRED for DLSS Frame Generation (RTX 40/50): don't disable if you use FG in other games. For pure latency the effect is small and varies (+-1 to 2%, depends on driver). That's why it's NOT in "Apply all". Test with CapFrameX before deciding. Requires restart.
USB/HID: desligar "permitir desligar p/ economizar energia"	USB/HID: turn off "allow to sleep to save power"
Evita o mouse/teclado dormir e demorar para acordar (falha de 1o movimento/micro-atraso). Aplica a todos os hubs/dispositivos USB e HID e guarda a lista p/ desfazer.	Prevents mouse/keyboard from sleeping and taking time to wake (first movement failure/micro-lag). Applies to all USB/HID hubs and devices and saves list for undo.
MSI Mode da GPU / USB / Placa de rede (sem baixar ferramenta)	MSI Mode for GPU / USB / Network Card (no tool download)
Interrupcao por mensagem em vez de linha compartilhada = menos DPC. No Windows 11 com driver atual a maioria das GPUs/placas de rede JA vem em MSI/MSI-X, entao muitas vezes nao ha nada a fazer: o menu mostra o estado de cada dispositivo e ativa so o que precisa. Para achar o driver culpado de picos, meca antes com o LatencyMon (menu Programas). Exige reiniciar.	Message interrupt instead of shared line = less DPC. On Windows 11 with current driver most GPUs/network cards already come in MSI/MSI-X, so often there's nothing to do: the menu shows each device's state and enables only what needs it. To find the driver causing spikes, measure first with LatencyMon (Programs menu). Requires restart.
Audio: Enhancements do Windows OFF	Audio: Windows Enhancements OFF
Tira o DSP (EQ/loudness) do caminho do som. Parte das chaves e protegida pelo Windows; o script muda onde da e avisa o resto (desligue em Som > Propriedades > Aprimoramentos).	Removes DSP (EQ/loudness) from audio path. Some keys are protected by Windows; script changes where it can and warns about the rest (turn off in Sound > Properties > Enhancements).
CPU sempre em C0 (desabilitar idle states) - EXTREMO	CPU always in C0 (disable idle states) - EXTREME
Configura o plano "Fortnite Otimizador" com IDLEDISABLE=1: a CPU nunca entra em estados de economia, sem latencia de despertar. Esquenta e consome bem mais, vida util menor com cooler fraco. Evidencia de ganho perceptivel e fraca. So desktop, e so para quem mede.	Configures "Fortnite Optimizer" plan with IDLEDISABLE=1: CPU never enters power-saving states, no wake latency. Heats up and uses much more power, shorter lifespan with weak cooler. Evidence of perceptible gain is weak. Desktop only, and only for those who measure.
Buffer de HID mouse/teclado = 32 (NAO COMPROVADO)	Mouse/keyboard HID buffer = 32 (UNPROVEN)
MouseDataQueueSize/KeyboardDataQueueSize (padrao 100). Pesquisa dividida; varios testes nao acham ganho real e alguns chamam de placebo. Sem risco de quebrar (nao use menos de 16).	MouseDataQueueSize/KeyboardDataQueueSize (default 100). Divided research; many tests find no real gain and some call it placebo. No risk of breaking (don't use less than 16).
VBS / Integridade de memoria (HVCI) OFF  -  REDUZ SEGURANCA	VBS / Memory Integrity (HVCI) OFF  -  REDUCES SECURITY
Microsoft e testes independentes mostram +5 a 15% FPS em alguns jogos ao desligar (varia muito; em CPU recente e menor). Custo: perde uma camada anti-malware de kernel e desliga Credential Guard. Se voce usa VirtualBox/WSL2/Hyper-V isso nao afeta. Depois confirme em Seguranca do Windows > Isolamento de nucleo. Updates grandes do Windows 11 (24H2/25H2) podem religar sozinho: reconfira o estado aqui apos cada atualizacao de versao. Reversivel.	Microsoft and independent tests show +5 to 15% FPS on some games when disabled (varies greatly; less on recent CPU). Cost: loses a kernel anti-malware layer and disables Credential Guard. If you use VirtualBox/WSL2/Hyper-V this doesn't affect it. Then confirm in Windows Security > Core Isolation. Large Windows 11 updates (24H2/25H2) may re-enable on their own: recheck status here after each version update. Reversible.
MPO (Multi-Plane Overlay) OFF - correcao de flicker/stutter	MPO (Multi-Plane Overlay) OFF - flicker/stutter fix
Recomendacao oficial da NVIDIA para flicker/tela preta/stutter com varios monitores ou HDR. NAO e um tweak de latencia comprovado: so use se voce tem esses sintomas. Precisa reiniciar.	Official NVIDIA recommendation for flicker/black screen/stutter with multiple monitors or HDR. NOT a proven latency tweak: only use if you have these symptoms. Requires restart.
BCDEdit avancado (dynamictick / tscsyncpolicy)	BCDEdit advanced (dynamictick / tscsyncpolicy)
ALTO RISCO/misto: em alguns PCs melhora DPC, em outros PIORA FPS. Guarda o valor anterior e tem "Desfazer tudo". Teste 1 por vez.	HIGH RISK/mixed: improves DPC on some PCs, worsens FPS on others. Saves previous value and has "Undo everything". Test 1 at a time.
Desativado	Disabled
Lendo as opcoes reais do seu adaptador...	Reading your adapter's actual options...
Nada a alterar: o adaptador ja esta sem economia de energia/moderacao de interrupcao (ou o driver nao expoe essas opcoes).	Nothing to change: adapter already has no power saving/interrupt moderation (or driver doesn't expose these options).
O que sera alterado ({0} item(ns)):	What will be changed ({0} item(s)):
Aviso: o adaptador reinicia (rede cai ~5 s). Interrupt Moderation OFF = menos latencia, um pouco mais de CPU.	Warning: adapter restarts (network drops ~5 s). Interrupt Moderation OFF = less latency, slightly more CPU.
Aplicar estas mudancas?	Apply these changes?
Nic	NIC
Nao consegui alterar	Failed to change
Adaptador ajustado.	Adapter adjusted.
Nada a desfazer (nenhum ajuste de adaptador feito por esta versao).	Nothing to undo (no adapter adjustment made by this version).
restaurar {0} {1} = {2}	restore {0} {1} = {2}
Nao consegui restaurar	Failed to restore
Adaptador restaurado.	Adapter restored.
DNS NAO muda o ping dentro da partida (o jogo fala por IP/UDP); acelera login, loja e matchmaking.	DNS does NOT change ping in-game (game speaks via IP/UDP); speeds up login, shop and matchmaking.
Automatico (DHCP) - restaurar	Automatic (DHCP) - restore
Geralmente o mais rapido no Brasil.	Usually fastest in Brazil.
Muito estavel.	Very stable.
Bloqueia dominios maliciosos.	Blocks malicious domains.
Volta a usar o DNS que o roteador/provedor entrega.	Goes back to using DNS that router/ISP provides.
DNS automatico em	DNS automatic on
Dns	DNS
DNS em	DNS on
DNS restaurado.	DNS restored.
Tcp	TCP
netsh falhou:	netsh failed:
TCP no padrao anterior.	TCP at previous default.
Teredo, 6to4 e ISATAP desligados.	Teredo, 6to4 and ISATAP disabled.
Tuneis no padrao.	Tunnels at default.
Lso	LSO
LSO OFF em	LSO OFF on
LSO em	LSO on
LSO restaurado.	LSO restored.
Isto faz "netsh winsock reset" + "netsh int ip reset": limpa a pilha de rede. Precisa REINICIAR.	This does "netsh winsock reset" + "netsh int ip reset": cleans the network stack. Needs RESTART.
Fazer o reset limpo agora?	Do clean reset now?
Reset feito. REINICIE o PC.	Reset done. RESTART the PC.
Adaptador de rede: sem economia de energia / moderacao de interrupcao	Network adapter: no power saving / interrupt moderation
Le as opcoes REAIS do seu driver (por palavra-chave, independe do idioma) e mostra o que vai mudar antes de aplicar: Ethernet -> EEE, Green Ethernet, Interrupt Moderation, Flow Control OFF. Wi-Fi -> economia de energia em "Desempenho maximo" e roaming no minimo. Guarda o valor antigo p/ desfazer.	Reads your driver's ACTUAL options (by keyword, language-independent) and shows what will change before applying: Ethernet -> EEE, Green Ethernet, Interrupt Moderation, Flow Control OFF. Wi-Fi -> power saving at "Maximum Performance" and roaming at minimum. Saves old value for undo.
Nagle OFF + ACK imediato nas suas placas de rede	Nagle OFF + immediate ACK on your network cards
TcpNoDelay/TcpAckFrequency=1 so afetam TCP (login, party, chat). O gameplay do Fortnite e UDP, entao NAO muda tiro/build. Seguro e reversivel; aplicado so as placas fisicas ativas.	TcpNoDelay/TcpAckFrequency=1 only affect TCP (login, party, chat). Fortnite gameplay is UDP, so does NOT change shots/builds. Safe and reversible; applied only to active physical cards.
Tira o limite de pacotes/s do MMCSS para multimidia. Guias de jogo recomendam, mas nao ha medicao confiavel de ganho no Fortnite. Inofensivo.	Removes MMCSS packet/s limit for multimedia. Game guides recommend, but no reliable measurement of gain in Fortnite. Harmless.
QoS: reserva de banda 0% (NonBestEffortLimit=0)	QoS: bandwidth reserve 0% (NonBestEffortLimit=0)
HONESTO: a reserva de 20% so existe quando algum app usa QoS; na pratica e mito/placebo. Mantido por compatibilidade, inofensivo.	HONEST: the 20% reserve only exists when some app uses QoS; in practice it's myth/placebo. Kept for compatibility, harmless.
Pilha TCP: autotuning normal, RSS on, ECN off, timestamps off	TCP stack: autotuning normal, RSS on, ECN off, timestamps off
Configuracao saudavel e conservadora. Em geral o Windows ja vem assim; util p/ desfazer ajustes ruins de "otimizadores de internet". Guarda os valores atuais.	Healthy and conservative configuration. Generally Windows comes like this; useful to undo bad adjustments from "internet optimizers". Saves current values.
Desligar tuneis IPv6 legados (Teredo / 6to4 / ISATAP)	Turn off legacy IPv6 tunnels (Teredo / 6to4 / ISATAP)
Menos trafego/DNS inesperado em segundo plano. Teredo desligado pode afetar alguns jogos P2P do Xbox/Microsoft Store; o Fortnite usa servidores da Epic e nao depende dele.	Less unexpected traffic/DNS in the background. Teredo disabled can affect some Xbox/Microsoft Store P2P games; Fortnite uses Epic servers and doesn't depend on it.
Large Send Offload (LSO) OFF - REINICIA o adaptador	Large Send Offload (LSO) OFF - RESTART the adapter
Alguns drivers Realtek/Intel geram picos com LSO. Desliga v4/v6 e reinicia o adaptador (queda de ~5 s). Nao entra no "Aplicar tudo" por causa da queda de rede.	Some Realtek/Intel drivers generate spikes with LSO. Turns off v4/v6 and restarts adapter (drop ~5 s). NOT in "Apply all" because of network drop.
DNS rapido (Cloudflare / Google / Quad9) ou voltar ao automatico	Fast DNS (Cloudflare / Google / Quad9) or back to automatic
Acelera login, loja e matchmaking. NAO muda o ping dentro da partida. Guarda o DNS anterior de cada adaptador.	Speeds up login, shop and matchmaking. Does NOT change ping in-game. Saves previous DNS of each adapter.
Reset limpo da pilha de rede (winsock + IP)	Clean network stack reset (winsock + IP)
Conserta rede corrompida por VPN/antivirus/otimizadores antigos. Precisa reiniciar. So use se estiver com problema.	Fixes network corrupted by VPN/antivirus/old optimizers. Needs restart. Only use if you have a problem.
winget nao encontrado (instale o "App Installer" na Microsoft Store).	winget not found (install "App Installer" from Microsoft Store).
Instalado:	Installed:
winget retornou codigo	winget returned code
(se ja estava instalado, ignore).	(if already installed, ignore).
Edita os perfis do driver NVIDIA (o que o Painel de Controle esconde). O item "Perfil de baixa latencia" do menu NVIDIA usa a linha de comando dele (-silentImport) para aplicar tudo sem abrir nada. Codigo aberto (GitHub Orbmu2k).	Edits NVIDIA driver profiles (what Control Panel hides). The "Low Latency Profile" item in NVIDIA menu uses its command line (-silentImport) to apply everything without opening anything. Open source (GitHub Orbmu2k).
CapFrameX (medir FPS, frametime e latencia)	CapFrameX (measure FPS, frametime and latency)
A ferramenta certa para PROVAR se um tweak ajudou: captura frametime, 1%/0.1% lows e (com PresentMon) latencia. Compare antes/depois; sem medir e placebo.	The right tool to PROVE if a tweak helped: captures frametime, 1%/0.1% lows and (with PresentMon) latency. Compare before/after; without measuring it's placebo.
Mostra qual driver causa picos de DPC/ISR (audio estalando, mouse pulando). Base para decidir sobre MSI Mode e drivers problematicos.	Shows which driver causes DPC/ISR spikes (audio crackling, mouse jumping). Basis to decide about MSI Mode and problematic drivers.
ISLC (limpa a Standby List da RAM)	ISLC (clears RAM Standby List)
Esvazia a memoria "em espera" quando ela enche (evita hitch de alocacao). Config comum: lista 1024 MB, livre 1024 MB, timer 0,50 ms, polling 500 ms. So ajuda se voce enche a RAM (16 GB ou menos + navegador aberto).	Empties "standby" memory when it fills (avoids allocation hitch). Common config: list 1024 MB, free 1024 MB, timer 0.50 ms, polling 500 ms. Only helps if you fill RAM (16 GB or less + browser open).
HWiNFO (temperaturas, clocks, sensores)	HWiNFO (temperatures, clocks, sensors)
Confere se a CPU/GPU esta em thermal throttling depois de aplicar o plano de energia maximo.	Checks if CPU/GPU is thermal throttling after applying maximum power plan.
Process Lasso (regras de prioridade/afinidade)	Process Lasso (priority/affinity rules)
Prioridade e afinidade persistentes por programa. Em CPU Intel hibrida (12a gen+) ou Ryzen de 2 CCDs ajuda a prender o jogo nos nucleos certos. O EAC pode bloquear mudar o jogo com ele aberto; use as regras para os OUTROS apps.	Persistent priority and affinity per app. On hybrid Intel CPUs (12th gen+) or Ryzen 2-CCD: helps pin the game to the right cores. EAC can block priority changes with the game open; use rules for OTHER apps.
RivaTuner Statistics Server (limitador de FPS)	RivaTuner Statistics Server (FPS limiter)
Limitador de FPS de menor variacao de frametime. O Fortnite ja tem limitador proprio + Reflex; RTSS e opcional e o overlay pode ser bloqueado pelo Easy Anti-Cheat. Use so se souber por que.	FPS limiter with lower frametime variance. Fortnite already has its own limiter + Reflex; RTSS is optional and the overlay can be blocked by Easy Anti-Cheat. Use only if you know why.
MSI Afterburner (OC/undervolt/curva de ventoinha)	MSI Afterburner (OC/undervolt/fan curve)
Ajuste de clock/voltagem/ventoinha. Undervolt = menos calor e clocks mais estaveis (menos throttling).	Adjust clock/voltage/fan curve. Undervolt = lower heat and stable clocks (less throttling).
Remove o driver de video por completo (use no Modo Seguro) antes de instalar um novo. Resolve stutter/erros de driver quebrado ou trocado de marca NVIDIA/AMD/Intel.	Remove the video driver completely (use in Safe Mode) before installing a new one. Fixes stutter/errors from broken or switched-brand drivers (NVIDIA/AMD/Intel).
NVCleanstall (driver NVIDIA enxuto)	NVCleanstall (lean NVIDIA driver)
Instala o driver NVIDIA sem telemetria/extras que voce nao quer. Opcional.	Install NVIDIA driver without telemetry/extras you don't want. Optional.
Cria resolucoes/Hz personalizadas (resolucao esticada de jogador pro). Depois use restart64.exe para reiniciar o driver.	Create custom resolutions/Hz (pro player stretched resolution). Then use restart64.exe to restart the driver.
Sysinternals Autoruns (o que inicia com o Windows)	Sysinternals Autoruns (what starts with Windows)
Lista TUDO que inicia com o Windows (mais completo que o Gerenciador de Tarefas).	Lists EVERYTHING that starts with Windows (more complete than Task Manager).
CrystalDiskInfo (saude do SSD/HD)	CrystalDiskInfo (SSD/HD health)
Verifica a saude do disco onde o Fortnite esta instalado.	Check the health of the disk where Fortnite is installed.
O&O ShutUp10++ (privacidade/telemetria)	O&O ShutUp10++ (privacy/telemetry)
Mexe em MUITAS configuracoes de privacidade do Windows. Ganho de FPS desprezivel; use so por privacidade e crie o ponto de restauracao por ele.	Tweaks MANY Windows privacy settings. FPS gain negligible; use only for privacy and create a restore point through it.
PROGRAMAS E INTEGRACOES (winget)	PROGRAMS AND INTEGRATIONS (winget)
Instala/abre direto por aqui. So programas oficiais; nada e instalado sem voce escolher.	Install/open directly from here. Official programs only; nothing is installed without your choice.
Instalar / atualizar via winget	Install / update via winget
Abrir o programa	Open the program
Removido do autostart:	Removed from autostart:
Nenhuma entrada NVIDIA no autostart do usuario.	No NVIDIA entries in user autostart.
Para desligar o overlay/gravacao de vez (o proprio app controla):	To turn off overlay/recording for good (the app itself controls it):
App NVIDIA > Configuracoes > Overlay do jogo = OFF  (e Instant Replay / ShadowPlay = OFF)	NVIDIA app > Settings > Game Overlay = OFF  (and Instant Replay / ShadowPlay = OFF)
Custo do overlay/Instant Replay ligado: alguns % de FPS e uma fila de captura a mais.	Cost of overlay/Instant Replay on: some % FPS and an extra capture queue.
Prefer maximum performance: GPU nao desce de clock durante o jogo.	Prefer maximum performance: GPU doesn't drop clock during gameplay.
Fila de quadros CPU->GPU = 1 (menos latencia).	CPU->GPU frame queue = 1 (less latency).
Liga o caminho Ultra Low Latency do driver. (Com Reflex ligado no jogo, o Reflex assume.)	Enables Ultra Low Latency path in driver. (With Reflex on in-game, Reflex takes over.)
Faz o Painel NVIDIA mostrar "Ultra".	Makes NVIDIA Control Panel show 'Ultra'.
High performance (menos custo de textura; diferenca visual minima).	High performance (lower texture cost; minimal visual difference).
Highest available: garante o maior Hz da tela.	Highest available: guarantees the monitor's highest Hz.
Vai gravar no perfil "Fortnite" do driver NVIDIA (IDs conferidos no codigo-fonte do Profile Inspector):	Will save to 'Fortnite' profile in NVIDIA driver (IDs verified in Profile Inspector source code):
Nao mexe em VSync/G-Sync (deixe o Fortnite controlar). So afeta o Fortnite, nao o perfil global.	Doesn't touch VSync/G-Sync (let Fortnite control). Affects only Fortnite, not the global profile.
NVIDIA Profile Inspector nao esta instalado. Instalar agora via winget (Orbmu2k.nvidiaProfileInspector)?	NVIDIA Profile Inspector not installed. Install now via winget (Orbmu2k.nvidiaProfileInspector)?
Nao achei o nvidiaProfileInspector.exe apos instalar. Abra o menu Programas e tente de novo.	Could not find nvidiaProfileInspector.exe after installing. Open the Programs menu and try again.
Aplicar o perfil de baixa latencia (com backup dos perfis atuais)?	Apply the low-latency profile (with backup of current profiles)?
Backup dos perfis:	Profiles backup:
Nenhum perfil customizado para exportar (normal em instalacao limpa).	No custom profile to export (normal on clean install).
O Profile Inspector demorou; conferindo mesmo assim.	Profile Inspector took a while; checking anyway.
Perfil importado no driver.	Profile imported into driver.
NVIDIA: perfil Fortnite importado via NPI	NVIDIA: Fortnite profile imported via NPI
Confira: abra o NVIDIA Profile Inspector, digite "Fortnite" no campo de perfil.	Check: open NVIDIA Profile Inspector, type 'Fortnite' in the profile field.
Desfazer: no Profile Inspector, perfil Fortnite > botao "restaurar perfil aos padroes".	Undo: in Profile Inspector, Fortnite profile > 'Restore profile to defaults' button.
nvidia-smi nao encontrado (driver NVIDIA instalado?).	nvidia-smi not found (NVIDIA driver installed?).
CLOCK DA GPU (nvidia-smi)	GPU CLOCK (nvidia-smi)
Vale so ate reiniciar. GTX 16 / RTX suportam.	Valid only until restart. GTX 16 / RTX supported.
Travar faixa 75%-100% do boost maximo	Lock to 75%-100% of max boost
Liberar (voltar ao automatico)	Release (return to auto)
A GPU nunca desce abaixo de ~75% do clock maximo: some o atraso de "acordar" a GPU entre cenas leves e pesadas. Custo: mais calor/consumo em idle enquanto travado. Equivale a "Prefer maximum performance" mas mais rigido.	GPU never drops below ~75% of max clock: removes the delay to 'wake up' the GPU between light and heavy scenes. Cost: more heat/power draw at idle while locked. Equivalent to 'Prefer maximum performance' but stricter.
Executa nvidia-smi -rgc.	Runs nvidia-smi -rgc.
Clock liberado.	Clock released.
Nao consegui ler o clock maximo:	Could not read max clock:
Travar clock da GPU em {0}-{1} MHz ate reiniciar?	Lock GPU clock to {0}-{1} MHz until restart?
GPU travada em {0}-{1} MHz. Reiniciar ou "Liberar" desfaz.	GPU locked to {0}-{1} MHz. Restart or 'Release' to undo.
nvidia-smi recusou:	nvidia-smi refused:
Perfil de BAIXA LATENCIA do Fortnite no driver (via Profile Inspector)	Fortnite LOW-LATENCY profile in driver (via Profile Inspector)
Integracao real: instala (winget) e comanda o NVIDIA Profile Inspector pela linha de comando, faz backup dos perfis e importa um perfil so do Fortnite: Prefer max performance, pre-rendered frames=1, Ultra Low Latency, filtro de textura High performance, Hz maximo. Se voce liga o NVIDIA Reflex no jogo, o Reflex assume a fila (recomendado).	Real integration: installs (winget) and commands NVIDIA Profile Inspector via command line, backs up profiles and imports a Fortnite-only profile: Prefer max performance, pre-rendered frames=1, Ultra Low Latency, High performance texture filter, max Hz. If you enable NVIDIA Reflex in-game, Reflex takes over the queue (recommended).
NVIDIA: fechar Share/Overlay e tirar do autostart	NVIDIA: close Share/Overlay and remove from autostart
ShadowPlay/Instant Replay/overlay gravando em segundo plano custam alguns % de FPS e uma fila extra. Encerra os processos, remove entradas NVIDIA do autostart (com backup) e mostra onde desligar no app NVIDIA.	ShadowPlay/Instant Replay/overlay recording in the background cost some % FPS and an extra queue. Ends the processes, removes NVIDIA entries from autostart (with backup) and shows where to turn off in NVIDIA app.
Travar faixa de clock da GPU (nvidia-smi -lgc) - ate reiniciar	Lock GPU clock range (nvidia-smi -lgc) - until restart
Elimina a rampa de clock da GPU (P8 -> P0). Mais calor/consumo enquanto travado. Some no reboot. Uso avancado.	Eliminates GPU clock ramp (P8 -> P0). More heat/power while locked. Goes away on reboot. Advanced use.
O INI esta somente-leitura (congelado). Libere em Fortnite > Congelar/liberar INI.	The INI is read-only (frozen). Release it at Fortnite > Freeze/unfreeze INI.
Nao salvou o INI (Fortnite aberto?):	Could not save INI (Fortnite open?):
GameUserSettings.ini nao encontrado. Abra o Fortnite 1x, entre numa partida, feche e tente de novo.	GameUserSettings.ini not found. Open Fortnite once, enter a match, close and try again.
O Fortnite esta ABERTO: ele sobrescreve o INI ao fechar. Feche o jogo antes.	Fortnite is OPEN: it overwrites the INI on close. Close the game first.
Continuar mesmo assim?	Continue anyway?
Ilimitado (0)  - maximo FPS, com Reflex controla a fila	Unlimited (0)  - max FPS, with Reflex controls the queue
Igual ao Hz do monitor ({0})	Same as monitor Hz ({0})
Hz - 3 ({0})  - p/ G-Sync/FreeSync sem tearing	Hz - 3 ({0})  - for G-Sync/FreeSync without tearing
LIMITE DE FPS	FPS CAP
Preset Performance: VSync OFF, tudo Low, sem Nanite/RT/blur, tela cheia exclusiva. A resolucao atual e preservada.	Preset Performance: VSync OFF, everything Low, no Nanite/RT/blur, exclusive fullscreen. Current resolution preserved.
Bom quando a CPU nao alcanca o Hz do monitor. Se a GPU ficar em 95-100%, ligue o Reflex no jogo.	Good when CPU can't reach monitor Hz. If GPU stays at 95-100%, enable Reflex in-game.
Frametime mais estavel se o PC passa folgado do Hz.	More stable frametime if PC passes monitor Hz easily.
Cap logo abaixo do Hz mantem o VRR (G-Sync/FreeSync) ativo sem tearing.	Cap just below Hz keeps VRR (G-Sync/FreeSync) active without tearing.
Aplicar o preset de performance no GameUserSettings.ini (com backup)?	Apply performance preset to GameUserSettings.ini (with backup)?
O INI ja estava com estes valores.	The INI already had these values.
{0} chave(s) alterada(s):	{0} key(s) changed:
INI atualizado.	INI updated.
No jogo: Video > Modo de renderizacao = Desempenho (reinicia o jogo) e NVIDIA Reflex = Ligado + Impulso (se tiver).	In-game: Video > Render Mode = Performance (restarts game) and NVIDIA Reflex = On + Boost (if available).
Engine.ini: chaves removidas.	Engine.ini: keys removed.
somente-leitura	read-only
INIs congelados. Para mudar opcoes no jogo, libere antes (Desfazer).	INIs frozen. To change options in-game, release first (Undo).
INIs liberados.	INIs released.
Onde colar: Launcher > foto do perfil > Configuracoes > Fortnite > Argumentos de linha de comando adicionais.	Where to paste: Launcher > profile picture > Settings > Fortnite > Additional command-line arguments.
-NOSPLASH   (seguro)	-NOSPLASH   (safe)
-NOSPLASH -USEALLAVAILABLECORES   (comunidade)	-NOSPLASH -USEALLAVAILABLECORES   (community)
Limpar (deixar em branco)	Clear (leave blank)
So pula o video de abertura. Zero risco. Escolha de renderizacao (DX12/Desempenho) se faz DENTRO do jogo, nao aqui.	Only skips the opening video. Zero risk. Render choice (DX12/Performance) is made INSIDE the game, not here.
-USEALLAVAILABLECORES e argumento da comunidade Unreal: efeito NAO comprovado no Fortnite atual. Inofensivo. Removi -malloc=system (pode piorar) e -NOTEXTURESTREAMING (estoura VRAM em GPU de 4-6 GB) das versoes antigas deste script.	-USEALLAVAILABLECORES is an Unreal community argument: effect NOT proven on current Fortnite. Harmless. I removed -malloc=system (can worsen) and -NOTEXTURESTREAMING (maxes out VRAM on 4-6 GB GPUs) from old versions of this script.
Copia texto vazio.	Copies empty text.
Copiado para a area de transferencia: "	Copied to clipboard: "
Nao consegui copiar; digite manualmente.	Could not copy; type manually.
Abrir o Epic Launcher agora?	Open Epic Launcher now?
Programas abertos que roubam CPU/GPU:	Open programs draining CPU/GPU:
ATENCAO: Chrome/Edge fecham (abas voltam ao reabrir, mas formularios e downloads em andamento se perdem).	WARNING: Chrome/Edge will close (tabs return on reopen, but open forms and downloads are lost).
Fechar esses programas agora?	Close these programs now?
Programas fechados.	Programs closed.
Nenhum dreno conhecido aberto.	No known drains open.
Abrir o Fortnite agora pelo Epic Launcher?	Open Fortnite now via Epic Launcher?
Nao consegui abrir o launcher:	Could not open launcher:
Aguardando o processo do jogo (ate 120 s)...	Waiting for game process (up to 120 s)...
O jogo ainda nao abriu (login/atualizacao?). Se voce aplicou "Prioridade ALTA fixa", ela vale quando abrir.	Game hasn't opened yet (login/update?). If you applied 'Fixed HIGH Priority', it will apply when it opens.
Prioridade High aplicada ao Fortnite.	High priority applied to Fortnite.
O Easy Anti-Cheat nao deixa mudar a prioridade de fora (normal). Use "Prioridade ALTA fixa" no menu Windows.	Easy Anti-Cheat won't let you change priority from outside (normal). Use 'Fixed HIGH Priority' in the Windows menu.
A gravacao de replay se desliga NO JOGO: Configuracoes > Jogo > Replays > Gravar replays = DESLIGADO.	Replay recording turns off IN-GAME: Settings > Gameplay > Replays > Record replays = OFF.
Nao ha replays salvos.	No replays saved.
Apagar {0} replay(s) antigo(s) ({1} MB)? Isso NAO da p/ desfazer.	Delete {0} old replay(s) ({1} MB)? This CANNOT be undone.
Replays apagados.	Replays deleted.
No Epic Launcher: Biblioteca > Fortnite > ... > Gerenciar > Verificar. Arquivo corrompido = crash/stutter.	In Epic Launcher: Library > Fortnite > ... > Manage > Verify. Corrupt file = crash/stutter.
Abrir o Epic Launcher?	Open Epic Launcher?
Abrir a pasta de configuracoes do Fortnite?	Open Fortnite config folder?
salvar nativa {0}x{1}@{2}	save native {0}x{1}@{2}
Resolucao nativa salva: {0}x{1} @ {2} Hz	Native resolution saved: {0}x{1} @ {2} Hz
GameUserSettings.ini nao achado (abra o Fortnite 1x). Windows ja trocado.	GameUserSettings.ini not found (open Fortnite once). Windows already changed.
Fortnite INI em {0}x{1} (tela cheia exclusiva).	Fortnite INI at {0}x{1} (exclusive fullscreen).
#Escala da imagem (para a resolucao esticada preencher a tela sem barras pretas)	#Image scaling (so stretched resolution fills screen without black bars)
Painel de Controle NVIDIA > Ajustar tamanho e posicao da area de trabalho > Escala: TELA CHEIA, Executar escala em: GPU, marque "Substituir o modo de escala definido por jogos e programas". Aplicar.	NVIDIA Control Panel > Adjust desktop size and position > Scaling: FULLSCREEN, Run scaling on: GPU, check 'Override scaling mode set by games and programs'. Apply.
Criar o modo: Alterar resolucao > Personalizar > Criar resolucao personalizada.	Create the mode: Change resolution > Customize > Create custom resolution.
AMD Software > Configuracoes > Tela: GPU Scaling = LIGADO, Scaling Mode = Full Panel (painel cheio). Resolucoes personalizadas na mesma aba.	AMD Software > Settings > Display: GPU Scaling = ON, Scaling Mode = Full Panel. Custom resolutions in same tab.
Intel Graphics Software > Sistema > Tela > Escala = TELA CHEIA e marque substituir configuracoes do aplicativo.	Intel Graphics Software > System > Display > Scaling = FULLSCREEN and check override application settings.
No menu OSD do monitor: escala = CHEIA/FULL (nao "Aspecto"/"1:1").	In monitor OSD menu: scaling = FULL (not 'Aspect'/'1:1').
Modo de janela = Tela cheia (exclusivo), nao "Tela cheia em janela".	Window mode = Fullscreen (exclusive), not 'Fullscreen windowed'.
ESCALA / ESTICAR RESOLUCAO	SCALING / STRETCHED RESOLUTION
(a do Peterbot; boa p/ comecar)	(Peterbot's; good to start)
(classica 4:3 - modelos mais largos)	(classic 4:3 - wider models)
Menos pixels = mais FPS e modelos mais largos; custo: imagem mais borrada e menos visao lateral. Windows E Fortnite mudam juntos p/ nao dar conflito. Se o modo nao existir no driver, o script explica como criar (CRU / painel da GPU). Presets sao para monitor 1080p.	Fewer pixels = more FPS and wider models; cost: blurrier image and less peripheral vision. Windows AND Fortnite change together to avoid conflict. If the mode doesn't exist in driver, script explains how to create (CRU / GPU panel). Presets are for 1080p monitors.
Reverter para a resolucao nativa (Windows + Fortnite)	Revert to native resolution (Windows + Fortnite)
Usa a nativa salva na 1a vez que voce aplicou um preset.	Uses the native saved the first time you applied a preset.
Tela ficou quadrada / barras pretas? (como esticar)	Screen turned square / black bars? (how to stretch)
Guia de escala por marca de GPU.	GPU brand scaling guide.
Abrir CRU (instala via winget se faltar)	Open CRU (install via winget if missing)
Custom Resolution Utility do ToastyX.	ToastyX's Custom Resolution Utility.
RESOLUCOES ESTICADAS	STRETCHED RESOLUTIONS
Agora: {0}x{1} @ {2} Hz	Now: {0}x{1} @ {2} Hz
O modo {0} ainda nao existe no driver.	Mode {0} doesn't exist in driver yet.
Crie-o em: NVIDIA (Alterar resolucao > Personalizar) | AMD (Tela > Resolucoes personalizadas) | CRU (Add > Detailed).	Create it at: NVIDIA (Change resolution > Customize) | AMD (Display > Custom resolutions) | CRU (Add > Detailed).
Depois reinicie o driver (restart64.exe do CRU) e rode este preset de novo.	Then restart driver (restart64.exe from CRU) and run this preset again.
Trocar Windows e Fortnite para {0}x1080 @ {1} Hz?	Switch Windows and Fortnite to {0}x1080 @ {1} Hz?
Resolucao esticada {0}x1080	Stretched resolution {0}x1080
Falta so o ESCALA (item "Tela ficou quadrada?") se aparecerem barras pretas.	Only missing SCALING (item 'Screen turned square?') if black bars appear.
Sem nativa salva; usando 1920x1080.	No native saved; using 1920x1080.
CRU nao instalado. Instalar via winget?	CRU not installed. Install via winget?
Vai limpar arquivos temporarios (~{0} MB): TEMP do usuario, Windows\Temp, logs e crashes do Fortnite. Arquivos em uso sao pulados.	Will clean temp files (~{0} MB): user TEMP, Windows\Temp, Fortnite logs and crashes. In-use files are skipped.
Limpar agora?	Clean now?
Tambem limpar o cache de shaders do DirectX (D3DSCache)? Use so se tem stutter/corrupcao: na 1a partida os shaders recompilam (mais lenta).	Also clean DirectX shader cache (D3DSCache)? Use only if you have stutter/corruption: on 1st match shaders recompile (slower).
limpar temporarios	clean temps
limpar D3DSCache	clean D3DSCache
D3DSCache limpo.	D3DSCache cleaned.
Limpeza concluida.	Cleanup done.
DiagTrack (telemetria) sera desativado. Spooler (impressao) e SysMain (Superfetch) so se voce confirmar.	DiagTrack (telemetry) will be disabled. Spooler (print) and SysMain (Superfetch) only if you confirm.
O tipo de inicio original de cada servico e guardado e volta no Restaurar. Nunca mexe em EAC/rede/audio.	Each service's original start type is saved and returns on Restore. Never touches EAC/network/audio.
Desativar DiagTrack?	Disable DiagTrack?
Voce NAO usa impressora? Desativar o Spooler?	You DON'T use a printer? Disable Spooler?
Tem SSD e disco em 100% com stutter? Desativar SysMain (quem tem HDD deve MANTER)?	Have SSD and 100% disk with stutter? Disable SysMain (HDD users should KEEP)?
Servico desativado:	Service disabled:
Atualizacoes pausadas ate	Updates paused until
Excluido do Defender:	Excluded from Defender:
Defender recusou (antivirus de terceiros ativo?):	Defender refused (third-party antivirus active?):
Sem exclusoes registradas.	No exclusions recorded.
Exclusoes removidas.	Exclusions removed.
Programas que iniciam com o Windows (desative o que nao usa em Ctrl+Shift+Esc > Inicializar):	Programs that start with Windows (disable unused ones at Ctrl+Shift+Esc > Startup):
Fortnite no SSD = carregamento bem mais rapido e menos stutter ao carregar skins/mapa.	Fortnite on SSD = much faster loading and less stutter when loading skins/map.
Se estiver no HDD: Epic Launcher > Fortnite > ... > Mover para SSD. Em SSD nunca desfragmente (so TRIM, automatico).	If on HDD: Epic Launcher > Fortnite > ... > Move to SSD. Never defragment on SSD (only TRIM, automatic).
GameUserSettings.ini: preset de PERFORMANCE (backup automatico)	GameUserSettings.ini: PERFORMANCE preset (auto backup)
Edita as chaves reais do Fortnite (por secao): VSync OFF, sombras/efeitos/pos-processo/AA/texturas Low, sem Nanite/RayTracing/blur/frame generation, tela cheia exclusiva, mostrar FPS. Mostra cada chave alterada e preserva a resolucao. Feche o jogo antes (ele sobrescreve o INI ao sair). Maior ganho de FPS em PC fraco.	Edits actual Fortnite keys (by section): VSync OFF, shadows/effects/post-process/AA/textures Low, no Nanite/RayTracing/blur/frame generation, exclusive fullscreen, show FPS. Shows each changed key and preserves resolution. Close game first (it overwrites INI on exit). Biggest FPS gain on weak PC.
Engine.ini: r.OneFrameThreadLag / GTSyncType / GC (NAO COMPROVADO)	Engine.ini: r.OneFrameThreadLag / GTSyncType / GC (NOT PROVEN)
r.OneFrameThreadLag=1 ja e o padrao da Unreal Engine e a Epic nao documenta Engine.ini como suportado (pode ignorar ou reverter). Efeito pratico desconhecido/nulo. Mantido so por compatibilidade; o desfazer remove exatamente as chaves adicionadas.	r.OneFrameThreadLag=1 is already Unreal Engine's default and Epic doesn't document Engine.ini as supported (can ignore or revert). Practical effect unknown/nil. Kept only for compatibility; undo removes exactly the added keys.
Congelar os INIs (somente-leitura) p/ o jogo nao desfazer o preset	Freeze INIs (read-only) so game doesn't undo preset
Com somente-leitura, mudar opcoes DENTRO do jogo nao salva. Fluxo certo: configure tudo, congele, jogue; para mudar, libere (Desfazer) antes.	With read-only, changing options INSIDE the game won't save. Right flow: configure all, freeze, play; to change, release (Undo) first.
Resolucao esticada (presets de pro) - Windows + Fortnite juntos	Stretched resolution (pro presets) - Windows + Fortnite together
Presets 1440/1650/1680/1720/1750 x 1080. Troca a resolucao do Windows (API nativa, sem baixar nircmd) e sincroniza o INI do Fortnite. Guarda a nativa p/ reverter. Explica como criar o modo (CRU/NVIDIA/AMD) e como esticar sem barras pretas.	Presets 1440/1650/1680/1720/1750 x 1080. Switches Windows resolution (native API, no nircmd download) and syncs Fortnite INI. Stores native to revert. Explains how to create mode (CRU/NVIDIA/AMD) and stretch without black bars.
Launch options do Epic Launcher (copia p/ area de transferencia)	Epic Launcher launch options (copy to clipboard)
Versao corrigida: so -NOSPLASH e (opcional) -USEALLAVAILABLECORES. Removidos os argumentos que podiam PIORAR (-malloc=system, -NOTEXTURESTREAMING).	Fixed version: only -NOSPLASH and (optional) -USEALLAVAILABLECORES. Removed arguments that could WORSEN (-malloc=system, -NOTEXTURESTREAMING).
MODO FOCO: fecha drenos (Discord/Chrome/...) e abre o Fortnite	FOCUS MODE: closes drains (Discord/Chrome/...) and opens Fortnite
Lista o que esta aberto e so fecha com sua confirmacao (pede pra fechar normal, depois forca). Abre o jogo pelo launcher e espera o processo aparecer (sem tempo fixo de 45 s).	Lists what's open and only closes with your confirmation (asks to close normally, then forces). Opens game via launcher and waits for process to appear (no fixed 45 s wait).
Replays: desligar no jogo + apagar replays antigos	Replays: turn off in-game + delete old replays
A gravacao de replay grava em disco durante a partida; desligue em Configuracoes > Jogo > Replays. O script pode apagar os .replay antigos (pede confirmacao, nao tem desfazer).	Replay recording writes to disk during match; turn off at Settings > Gameplay > Replays. Script can delete old .replay files (asks for confirmation, no undo).
Verificar arquivos do jogo + abrir pasta de configuracoes	Verify game files + open config folder
Arquivo corrompido causa crash/stutter. Abre o Epic Launcher e a pasta WindowsClient.	Corrupt file causes crash/stutter. Opens Epic Launcher and WindowsClient folder.
Limpeza: temporarios, logs/crashes do Fortnite, DNS (+ shaders opcional)	Cleanup: temps, Fortnite logs/crashes, DNS (+ shaders optional)
Libera espaco e remove logs. O cache de shaders do DirectX so deve ser limpo com stutter/corrupcao (recompila na 1a partida). Arquivos em uso sao pulados.	Frees space and removes logs. DirectX shader cache should only be cleaned with stutter/corruption (recompiles on 1st match). In-use files are skipped.
Sugestoes/apps em 2o plano do Windows OFF	Windows suggestions/background apps OFF
Desliga instalacao silenciosa de apps, sugestoes do menu e pesquisa Bing. So chaves de registro, nao desinstala nada.	Turns off silent app install, menu suggestions and Bing search. Registry keys only, doesn't uninstall anything.
Delivery Optimization OFF (nao enviar/receber updates de outros PCs)	Delivery Optimization OFF (don't send/receive updates from other PCs)
Evita o Windows usar sua rede/disco para distribuir atualizacoes. Ganho pequeno, principalmente em internet limitada.	Prevents Windows using your network/disk to distribute updates. Small gain, mainly on limited internet.
Ver programas que iniciam com o Windows	See programs that start with Windows
Lista o que inicia junto (Discord, Spotify, OneDrive...). Desative o que nao usa para jogar.	Lists what starts together (Discord, Spotify, OneDrive...). Disable what you don't use for gaming.
Servicos pesados: DiagTrack / Spooler / SysMain (com backup)	Heavy services: DiagTrack / Spooler / SysMain (with backup)
DiagTrack = telemetria. Spooler so se nao usa impressora. SysMain so em SSD com disco em 100%. O inicio original e guardado.	DiagTrack = telemetry. Spooler only if no printer. SysMain only on SSD with 100% disk. Original start is saved.
Pausar o Windows Update por 24 h (so enquanto for jogar)	Pause Windows Update for 24 h (only while gaming)
Mesmo mecanismo do botao "Pausar atualizacoes" do Windows. Evita download/instalacao em fundo durante a partida.	Same as Windows 'Pause updates' button. Prevents download/install in background during match.
Windows Defender: excluir SO as pastas do Fortnite	Windows Defender: exclude ONLY Fortnite folders
AVISO DE SEGURANCA: exclusao reduz a protecao nessas pastas. So as pastas do jogo (instalacao + %LOCALAPPDATA%\FortniteGame). Ganho pequeno com o Defender padrao; maior com antivirus de terceiros pesado.	SECURITY WARNING: exclusion reduces protection in those folders. Only game folders (install + %LOCALAPPDATA%\FortniteGame). Small gain with default Defender; bigger with heavy third-party antivirus.
SSD ou HD? (onde o Fortnite esta)	SSD or HDD? (where Fortnite is)
Mostra o tipo dos seus discos e o que fazer.	Shows your disk types and what to do.
Intel classico / outros (base Ultimate Performance)	Classic Intel / others (base Ultimate Performance)
Nucleos sempre acordados (sem core parking), clock minimo 100%, boost agressivo, EPP maximo desempenho. E o perfil "tudo no talo" para CPUs sem nucleos hibridos.	Cores always awake (no core parking), min clock 100%, aggressive boost, max EPP performance. The 'everything maxed out' profile for CPUs without hybrid cores.
Intel hibrido P+E (12a geracao ou mais nova) - base Balanced	Hybrid Intel P+E (12th gen or newer) - base Balanced
NAO trava o clock minimo (relatos mostram que "Alto desempenho" faz os E-cores assumirem o trabalho e gera stutter). Sem core parking, boost agressivo, EPP maximo e agendador preferindo os P-cores.	Does NOT lock min clock (reports show 'High performance' makes E-cores take over and causes stutter). No core parking, aggressive boost, max EPP, scheduler favoring P-cores.
A AMD recomenda a base Balanced para o CPPC funcionar. Aqui: boost agressivo, EPP maximo desempenho, nucleos desestacionados e clock minimo deixado ao CPPC (o Ryzen sobe em microssegundos).	AMD recommends Balanced base for CPPC to work. Here: aggressive boost, max EPP performance, cores unparked and min clock left to CPPC (Ryzen goes up in microseconds).
Ryzen X3D de 2 CCDs (7900X3D/7950X3D/9900X3D/9950X3D) - base Balanced	Ryzen X3D 2-CCD (7900X3D/7950X3D/9900X3D/9950X3D) - base Balanced
NAO mexe no core parking: o driver 3D V-Cache da AMD usa o parking para prender o jogo no CCD com cache extra (plano de Alto desempenho quebra isso). So aplica boost agressivo, EPP maximo e as economias de USB/PCIe/Wi-Fi.	Does NOT touch core parking: AMD 3D V-Cache driver uses parking to pin game to cache-extra CCD (High performance plan breaks this). Only applies aggressive boost, max EPP and USB/PCIe/Wi-Fi savings.
Estado maximo do processador	Max processor state
Sem limite de clock.	No clock limit.
Modo de boost do processador = Agressivo	Processor boost mode = Aggressive
Sobe o clock mais rapido.	Raises clock faster.
Politica de boost = maximo	Boost policy = maximum
Favorece boost sobre eficiencia.	Favors boost over efficiency.
EPP (preferencia energia/desempenho) = desempenho	EPP (energy/performance preference) = performance
Intel Speed Shift / AMD CPPC escolhem clock alto.	Intel Speed Shift / AMD CPPC choose high clock.
EPP classe 1 (nucleos eficientes) = desempenho	EPP class 1 (efficiency cores) = performance
So existe em CPUs hibridas.	Only exists on hybrid CPUs.
Resfriamento do sistema = ativo	System cooling = active
Liga a ventoinha antes de reduzir clock.	Turns on fan before lowering clock.
Dica de latencia: desempenho do processador	Latency hint: processor performance
Tarefas sensiveis a latencia recebem clock maximo.	Latency-sensitive tasks get max clock.
Estado minimo do processador = 5% (notebook: preserva o boost)	Min processor state = 5% (laptop: preserves boost)
Em notebook, clock travado no maximo esquenta e reduz o boost no jogo.	On laptop, clock locked max heats up and reduces boost in-game.
Estado minimo do processador = 100%	Min processor state = 100%
Clock nunca cai (zero rampa).	Clock never drops (zero ramp).
Nucleos minimos ativos = 100% (sem parking)	Min active cores = 100% (no parking)
Nenhum nucleo estacionado.	No cores parked.
Nucleos maximos ativos = 100%	Max active cores = 100%
Dica de latencia: desestacionar nucleos	Latency hint: unpark cores
Estado minimo do processador = 5% (deixa o HWP decidir)	Min processor state = 5% (let HWP decide)
Evita travar E-cores em clock alto.	Prevents locking E-cores at high clock.
Nucleos minimos ativos classe 1 = 100%	Min active cores class 1 = 100%
Politica de agendamento hibrido = preferir P-cores	Hybrid scheduling policy = prefer P-cores
Threads pesadas nos nucleos de desempenho.	Heavy threads on performance cores.
Politica de agendamento (tarefas curtas) = preferir P-cores	Scheduling policy (short tasks) = prefer P-cores
Estado minimo do processador = 5% (CPPC decide)	Min processor state = 5% (CPPC decides)
Recomendacao AMD: nao travar o minimo.	AMD recommendation: don't lock the minimum.
USB: suspensao seletiva = desativada	USB: selective suspend = disabled
Mouse/teclado nao dormem.	Mouse/keyboard don't sleep.
USB 3: gerenciamento de energia do link = desligado	USB 3: link power management = off
Sem latencia de saida de estado de baixa energia.	No low power state exit latency.
PCI Express: ASPM = desligado	PCI Express: ASPM = off
GPU/NVMe sem economia de link.	GPU/NVMe without link savings.
Disco rigido: nunca desligar	Hard drive: never turn off
Sem espera de spin-up.	No spin-up wait.
Adaptador sem fio: desempenho maximo	Wireless adapter: max performance
Wi-Fi sem economia (menos jitter).	Wi-Fi without power save (less jitter).
Perfil:	Profile:
Recriando o plano com a base certa para este perfil...	Recreating plan with correct base for this profile...
Nao consegui criar o plano de energia.	Could not create power plan.
Criado pelo Fortnite Otimizador - perfil	Created by Fortnite Optimizer - profile
[--] {0}  (nao existe neste Windows: ignorado)	[--] {0}  (doesn't exist on this Windows: ignored)
[X]  {0}  (powercfg recusou)	[X]  {0}  (powercfg refused)
[!]  {0}  (esperado {1}, ficou {2})	[!]  {0}  (expected {1}, got {2})
powercfg -setactive falhou:	powercfg -setactive failed:
Plano "{0}" ativo: {1} configuracao(oes) aplicada(s), {2} ignorada(s) por nao existir neste Windows, {3} com problema.	Plan "{0}" active: {1} setting(s) applied, {2} ignored (don't exist on this Windows), {3} with issues.
Plano de energia perfil	Power plan profile
Aplique o plano primeiro (item 1).	Apply the plan first (item 1).
Plano exportado:	Plan exported:
Para usar em outro PC: powercfg /import "caminho\Fortnite_Otimizador.pow" (ou pelo item "Importar"). Atencao: o plano exportado e do SEU perfil de CPU.	To use on another PC: powercfg /import "path\Fortnite_Optimizer.pow" (or via 'Import' item). Warning: exported plan is from YOUR CPU profile.
Falhou ao exportar:	Failed to export:
Importa um plano de energia (.pow) que voce ja tenha (por exemplo o exportado por este programa).	Import a power plan (.pow) you already have (for example exported by this program).
Um .pow so contem configuracoes de energia (nao executa codigo), mas importe apenas de fontes em que confia.	A .pow only contains power settings (doesn't run code), but import only from trusted sources.
Entrada de caminho indisponivel neste modo.	Path entry unavailable in this mode.
Caminho do arquivo .pow (arraste o arquivo para ca; vazio = cancelar)	Path to .pow file (drag file here; empty = cancel)
Arquivo nao encontrado ou nao e .pow.	File not found or not a .pow.
Arquivo grande demais para ser um plano de energia.	File too large to be a power plan.
powercfg nao importou:	powercfg didn't import:
Plano importado:	Plan imported:
Ativar o plano importado agora? (o original fica salvo p/ voltar)	Activate imported plan now? (original saved to return)
Ativado.	Activated.
Ultimate Performance (fallback: Alto desempenho)	Ultimate Performance (fallback: High performance)
~Notebook detectado: base Balanced (a bateria nao e afetada, so a tomada).	~Laptop detected: base Balanced (battery not affected, only AC).
-> ignorada: nao existe neste Windows	-> ignored: doesn't exist on this Windows
+Windows Power Throttling = desligado (registro PowerThrottlingOff=1)   (apps em 2o plano nao sao mais limitados)	+Windows Power Throttling = off (registry PowerThrottlingOff=1)   (background apps no longer limited)
~Nao inclui o modo "CPU sempre em C0" (item extremo separado) nem mexe em suspensao/tela (voce mantem os seus tempos).	~Doesn't include 'CPU always in C0' mode (separate extreme item) or touch suspend/screen (you keep your times).
O QUE O PLANO CONFIGURA	WHAT THE PLAN CONFIGURES
APLICAR o plano recomendado para o meu PC	APPLY the recommended plan for my PC
Seu plano atual NAO e alterado: o otimizador cria o plano "Fortnite Otimizador" e o Desfazer volta ao anterior.	Your current plan is NOT changed: optimizer creates 'Fortnite Optimizer' plan and Undo returns to previous.
Escolher outro perfil de CPU (manual)	Choose another CPU profile (manual)
Classico, Intel hibrido, Ryzen ou Ryzen X3D de 2 CCDs. Util se a deteccao errar ou se voce vai exportar o plano p/ outro PC.	Classic, Hybrid Intel, Ryzen or Ryzen X3D 2-CCD. Useful if detection fails or you'll export plan to another PC.
Ver tudo que este plano configura (com valores e motivos)	See everything this plan configures (with values and reasons)
Lista cada configuracao, o valor e se ela existe neste Windows. Nada e alterado.	Lists each setting, its value and if it exists on this Windows. Nothing changed.
Exportar o plano para arquivo .pow (compartilhar)	Export plan to .pow file (share)
Gera Fortnite_Tools\Fortnite_Otimizador.pow com powercfg /export.	Generates Fortnite_Tools\Fortnite_Optimizer.pow with powercfg /export.
Importar um plano .pow	Import a .pow plan
Importa um .pow que voce escolher (o exportado por este programa ou outro em que confia).	Import a .pow you choose (exported by this program or one you trust).
Voltar ao plano de energia original	Return to original power plan
Reativa o plano que estava em uso antes.	Reactivates the plan that was in use before.
PLANO DE ENERGIA	POWER PLAN
Perfil selecionado:	Selected profile:
Aplicar o perfil "	Apply profile "
" agora?	" now?
PERFIL DE CPU	CPU PROFILE
Detectado:	Detected:
nao consegui criar plano temporario	could not create temporary plan
, ficou	, got
Otimizacoes para jogos em janela (modelo FLIP no DX10/11)	Optimizations for windowed games (FLIP model on DX10/11)
Configuracao oficial do Windows 11: jogos DirectX 10/11 em janela ou sem borda passam a apresentar quadros pelo modelo "flip", que tem menos latencia e libera VRR. HONESTO: no Fortnite atual (DirectX 12 e Modo Desempenho, que virou DX12 no patch 37.00) NAO muda nada; vale para outros jogos DX11 e para quem ainda usa DX11. Preserva os outros ajustes da mesma chave (Auto HDR, VRR).	Official Windows 11 setting: DirectX 10/11 games windowed or borderless now present frames via 'flip' model, with lower latency and freeing VRR. HONEST: on current Fortnite (DirectX 12 and Performance Mode, which became DX12 in patch 37.00) it changes nothing; applies to other DX11 games and DX11 users. Preserves other settings on same key (Auto HDR, VRR).
NVIDIA: travar a GPU no P0 (DisableDynamicPstate) - clock maximo sempre	NVIDIA: lock GPU at P0 (DisableDynamicPstate) - max clock always
Registro do driver que impede a GPU de baixar o clock, ate no desktop. Mais agressivo que "Preferir desempenho maximo" (que ja vem no perfil do Fortnite). Ganho de latencia real e pequeno (o Reflex "Ligado + Impulso" faz quase o mesmo so durante o jogo). Custo: +20 a 40 W parado, mais calor e ventoinha. So desktop. Precisa reiniciar.	Driver registry that prevents GPU from lowering clock, even on desktop. More aggressive than 'Prefer maximum performance' (which comes in Fortnite profile). Real latency gain is small (Reflex 'On + Boost' does almost the same just during gameplay). Cost: +20 to 40 W idle, more heat and fan. Desktop only. Needs restart.
Mitigacoes Spectre/Meltdown OFF  -  REDUZ SEGURANCA	Spectre/Meltdown mitigations OFF  -  REDUCES SECURITY
Desliga protecoes do kernel contra ataques de execucao especulativa (FeatureSettingsOverride=3). Ganho medido so em CPUs antigas (Intel ate a 8a/9a geracao, Ryzen 1000/2000), e mais em disco/rede do que em FPS; em CPU recente (Intel 12a+ / Ryzen 5000+) o ganho e praticamente zero. Custo: um programa malicioso pode ler memoria de outro processo. Nao recomendado para PC de uso geral. Reversivel.	Disables kernel protections against speculative execution attacks (FeatureSettingsOverride=3). Measured gain only on old CPUs (Intel up to 8th/9th gen, Ryzen 1000/2000), more on disk/network than FPS; on recent CPU (Intel 12th+ / Ryzen 5000+) gain is nearly zero. Cost: malicious program can read another process' memory. Not recommended for general-use PC. Reversible.
Discord (desligue o overlay em Configuracoes > Overlay do jogo)	Discord (turn off overlay at Settings > Game Overlay)
Steam (overlay e gravacao desligados se nao usar)	Steam (overlay and recording off if not using)
Medal.tv (grava em segundo plano)	Medal.tv (records in background)
Driver de CHIPSET da AMD nao encontrado: sem ele o "nucleo preferido" (CPPC) do Windows nao funciona direito. Baixe em amd.com/support (chipset da sua placa-mae).	AMD Chipset driver not found: without it Windows 'preferred core' (CPPC) doesn't work right. Download from amd.com/support (your motherboard's chipset).
Ryzen X3D de 2 CCDs sem o servico "AMD 3D V-Cache Performance Optimizer": instale/atualize o chipset da AMD, senao o jogo pode rodar no CCD sem cache.	Ryzen X3D 2-CCD without 'AMD 3D V-Cache Performance Optimizer' service: install/update AMD chipset, else game may run on cache-less CCD.
Xbox Game Bar ausente: no X3D de 2 CCDs ela ajuda o driver da AMD a detectar o jogo. Reinstale pelo menu Restaurar.	Xbox Game Bar missing: on X3D 2-CCD it helps AMD driver detect game. Reinstall via Restore menu.
fTPM da AMD ativo com BIOS de {0:dd/MM/yyyy}: BIOS anteriores ao AGESA 1.2.0.7 causam travadas de 1-2 s (audio e mouse congelam). Atualize a BIOS.	AMD fTPM active with BIOS from {0:dd/MM/yyyy}: BIOS before AGESA 1.2.0.7 cause 1-2 s freezes (audio and mouse freeze). Update BIOS.
Intel 13a/14a geracao com microcode 0x{0:X} (antigo). A Intel corrigiu a degradacao por voltagem no 0x12B/0x12F: atualize a BIOS e selecione "Intel Default Settings".	Intel 13th/14th gen with microcode 0x{0:X} (old). Intel fixed voltage degradation in 0x12B/0x12F: update BIOS and select 'Intel Default Settings'.
Intel 13a/14a geracao: confirme BIOS com microcode 0x12B ou mais novo (correcao oficial de instabilidade).	Intel 13th/14th gen: confirm BIOS with microcode 0x12B or newer (official instability fix).
Notebook com duas GPUs: se tiver MUX switch / "somente GPU dedicada" no software do fabricante, ligue para jogar. Passar a imagem pela integrada adiciona latencia e tira FPS.	Laptop with two GPUs: if you have MUX switch / 'dedicated GPU only' in manufacturer software, turn on to game. Passing image through integrated adds latency and kills FPS.
Abertos agora (overlays/RGB/gravacao somam custo):	Open now (overlays/RGB/recording add cost):
. Feche o que nao usa durante a partida.	. Close what you don't use during match.
+Modo de janela: TELA CHEIA. Menor latencia e sem passar pelo compositor.	+Window mode: FULLSCREEN. Lower latency and no compositor pass.
+VSync: DESLIGADO no jogo (ligado adiciona 1 a 2 quadros de atraso). Excecao: G-SYNC/FreeSync, ver guia da sua GPU.	+VSync: OFF in-game (on adds 1-2 frames delay). Exception: G-SYNC/FreeSync, see your GPU guide.
+Limite de FPS: ilimitado, ou 3 abaixo do Hz se usa G-SYNC/FreeSync. Nunca muito abaixo da capacidade do PC "por estabilidade": FPS baixo = mais atraso.	+FPS cap: unlimited, or 3 below Hz if using G-SYNC/FreeSync. Never much below PC capability 'for stability': low FPS = more delay.
+Taxa de atualizacao: o MAXIMO do monitor (item "Taxa de atualizacao" no menu Input Lag).	+Refresh rate: monitor's MAXIMUM (item 'Refresh rate' in Input Lag menu).
+Desde o patch 37.00 (ago/2025) o Modo DESEMPENHO roda em DirectX 12 e substituiu o antigo Desempenho DX11. E o que da mais FPS e o frametime mais estavel em PC fraco, notebook e CPU hibrida.	+Since patch 37.00 (Aug/2025) PERFORMANCE Mode runs on DirectX 12 and replaced old Performance DX11. It gives most FPS and stable frametime on weak PC, laptop and hybrid CPU.
+DirectX 12 com tudo em Baixo: para GPU recente que quer um pouco mais de imagem. Distribui melhor o trabalho entre os nucleos que o DX11 antigo.	+DirectX 12 with everything Low: for recent GPU that wants a bit more image. Better distributes work across cores than old DX11.
~Na 1a partida apos update/driver novo o jogo compila shaders: ha engasgos que somem depois. Deixe o jogo terminar de compilar no lobby.	~On 1st match after update/new driver game compiles shaders: there are stutters that go away. Let game finish compiling in lobby.
+Resolucao 3D: 100%. Se precisar de FPS, baixe de 10 em 10.	+3D resolution: 100%. If you need FPS, lower in steps of 10.
+Sombras, efeitos, pos-processamento, texturas: Baixo. Motion blur, Ray Tracing, Nanite, Lumen/GI e Reflexos: DESLIGADOS.	+Shadows, effects, post-processing, textures: Low. Motion blur, Ray Tracing, Nanite, Lumen/GI and Reflections: OFF.
~Upscaling (DLSS/FSR/XeSS/TSR): renderiza em resolucao menor. Se a GPU e o gargalo, mais FPS = menos latencia; o TSR custa alguns ms por quadro, prefira DLSS/FSR/XeSS se tiver.	~Upscaling (DLSS/FSR/XeSS/TSR): renders at lower resolution. If GPU is bottleneck, more FPS = less latency; TSR costs some ms per frame, prefer DLSS/FSR/XeSS if available.
!Frame Generation (DLSS FG, FSR FG, AFMF): ADICIONA latencia (insere quadro interpolado). Desligue no competitivo.	!Frame Generation (DLSS FG, FSR FG, AFMF): ADDS latency (inserts interpolated frame). Turn off in competitive.
+Mostrar FPS: ligado.	+Show FPS: on.
#LATENCIA POR MARCA DE GPU (o que o Fortnite suporta de verdade)	#LATENCY BY GPU BRAND (what Fortnite actually supports)
+NVIDIA Reflex: "Ligado + Impulso". Ligado ja remove a fila de renderizacao; o Impulso tambem impede a GPU de baixar o clock entre quadros (ganho extra quando a GPU NAO esta em 99%, ex.: notebook, menus, FPS travado).	+NVIDIA Reflex: "On + Boost". On already removes the render queue; Boost also prevents the GPU from lowering the clock between frames (extra gain when the GPU is NOT at 99%, e.g.: laptop, menus, locked FPS).
+Com Reflex ligado, o "Modo de baixa latencia" do painel NVIDIA e ignorado (nao faz mal deixar).	+With Reflex on, the "Low Latency Mode" in the NVIDIA panel is ignored (no harm in leaving it on).
!AMD Anti-Lag 2: o Fortnite NAO tem (lista oficial da AMD so traz CS2, Dota 2 e Ghost of Tsushima). O Anti-Lag classico do driver so funciona em DX11, e o Fortnite atual e DX12.	!AMD Anti-Lag 2: Fortnite does NOT have it (AMD's official list only has CS2, Dota 2, and Ghost of Tsushima). The classic Anti-Lag from the driver only works in DX11, and current Fortnite is DX12.
!Intel XeLL (Xe Low Latency): sem confirmacao oficial no Fortnite. Nao conte com ele.	!Intel XeLL (Xe Low Latency): no official confirmation on Fortnite. Don't rely on it.
#COMO SABER SE AJUDOU	#HOW TO KNOW IF IT HELPED
~Nao confie em sensacao. Use o CapFrameX (menu Programas) e compare FPS medio, 1% low e frametime antes/depois de cada mudanca.	~Don't rely on feeling. Use CapFrameX (Programs menu) and compare average FPS, 1% low, and frametime before/after each change.
#O QUE TEM MAIS IMPACTO QUE QUALQUER TWEAK DE REGISTRO	#WHAT HAS MORE IMPACT THAN ANY REGISTRY TWEAK
+Use o Hz MAXIMO (60 Hz = 16,7 ms entre quadros; 144 Hz = 6,9 ms; 240 Hz = 4,2 ms).	+Use the MAXIMUM Hz (60 Hz = 16.7 ms between frames; 144 Hz = 6.9 ms; 240 Hz = 4.2 ms).
+Cabo DisplayPort (HDMI antigo limita o Hz). Overdrive MEDIO no menu do monitor: alto demais gera rastro invertido (so visual).	+DisplayPort cable (old HDMI limits Hz). MEDIUM Overdrive in the monitor menu: too high creates inverse ghosting (visual only).
~ULMB/strobing (piscar o backlight) reduz o BORRAO de movimento, nao a latencia de clique-a-foton. Nao combine com overdrive alto.	~ULMB/strobing (flickering the backlight) reduces motion blur, not click-to-photon latency. Don't combine with high overdrive.
#Mouse e teclado	#Mouse and keyboard
+Polling 1000 Hz. 4000/8000 Hz so com CPU forte, porta USB direta da placa-mae (traseira), e cobram CPU.	+Polling 1000 Hz. 4000/8000 Hz only with strong CPU, direct USB port from motherboard (rear), and cost CPU.
+DPI fixo (400 a 1600) e sensibilidade no jogo. Sem hub USB. Sem fio: dongle 2,4 GHz perto, nunca Bluetooth.	+Fixed DPI (400 to 1600) and in-game sensitivity. No USB hub. Wireless: 2.4 GHz dongle nearby, never Bluetooth.
#Memoria RAM	#RAM Memory
+2 pentes (dual channel) com XMP/EXPO LIGADO. Pente unico ou RAM em velocidade JEDEC (2133/2400 DDR4, 4800 DDR5) derruba o 1% low; com GPU integrada a perda chega a 40-60%.	+2 sticks (dual channel) with XMP/EXPO ON. Single stick or RAM at JEDEC speed (2133/2400 DDR4, 4800 DDR5) tanks the 1% low; with integrated GPU the loss reaches 40-60%.
#Notebook	#Laptop
+Na tomada, sempre. Se tiver MUX switch / "GPU dedicada somente" / Advanced Optimus no software do fabricante (Armoury Crate, MSI Center, Legion Vantage...), ligue para jogar: passar a imagem pela integrada adiciona latencia e tira FPS.	+Plugged in, always. If you have MUX switch / "Dedicated GPU only" / Advanced Optimus in the manufacturer's software (Armoury Crate, MSI Center, Legion Vantage...), enable to play: routing the image through the integrated adds latency and costs FPS.
+Windows 11 "Taxa de atualizacao dinamica": troque para o Hz maximo fixo (Configuracoes > Sistema > Tela > Tela avancada), senao a tela pode cair para 60 Hz.	+Windows 11 "Dynamic refresh rate": change to fixed maximum Hz (Settings > System > Display > Advanced display), or the screen may drop to 60 Hz.
~Intel: "Panel Self Refresh" (Intel Graphics Software > Energia) pode dar travadinha no mouse quando a tela "acorda". Desligue jogando na tomada.	~Intel: "Panel Self Refresh" (Intel Graphics Software > Power) can cause mouse stuttering when the screen "wakes". Disable when playing plugged in.
#Programas em segundo plano	#Background programs
+Cada overlay custa pouco sozinho, mas soma: Discord (overlay), Steam (overlay), gravadores (Medal, OBS, Overwolf) e suites RGB (Armoury Crate, iCUE, Synapse, SignalRGB). Feche o que nao usa. O Diagnostico lista os que estao abertos.	+Each overlay costs little on its own, but adds up: Discord (overlay), Steam (overlay), recorders (Medal, OBS, Overwolf), and RGB suites (Armoury Crate, iCUE, Synapse, SignalRGB). Close what you don't use. Diagnostics lists the ones that are open.
#Armazenamento e temperatura	#Storage and temperature
+Fortnite em SSD. Throttling termico causa stutter: limpe a poeira, confira a pasta termica, veja temperaturas no HWiNFO.	+Fortnite on SSD. Thermal throttling causes stutter: clean dust, check thermal paste, check temperatures in HWiNFO.
#TODOS OS PCs	#ALL PCs
+XMP/EXPO LIGADO (a RAM vem rodando abaixo da velocidade anunciada).	+XMP/EXPO ON (RAM comes running below advertised speed).
+Resizable BAR ligado se a GPU suportar (RTX 30+, RX 6000+, Intel Arc; na Arc e praticamente obrigatorio).	+Resizable BAR on if your GPU supports it (RTX 30+, RX 6000+, Intel Arc; on Arc it's practically mandatory).
+BIOS atualizada. Anote o valor original de tudo que mudar; nomes variam por fabricante.	+BIOS updated. Note the original value of everything you change; names vary by manufacturer.
!13a e 14a geracao (i5/i7/i9 13xxx/14xxx desktop): atualize a BIOS para microcode 0x12B ou mais novo e escolha "Intel Default Settings". E a correcao oficial da Intel para degradacao por voltagem (travamentos que parecem stutter). O Diagnostico confere seu microcode.	!13th and 14th generation (i5/i7/i9 13xxx/14xxx desktop): update BIOS to microcode 0x12B or newer and choose "Intel Default Settings". It's Intel's official fix for voltage degradation (stutters that look like freezes). Diagnostics checks your microcode.
+Core Ultra 200S (Arrow Lake): Windows e BIOS atualizados corrigiram a latencia de memoria do lancamento. O perfil "200S Boost" e opcional (overclock oficial; aumenta limites).	+Core Ultra 200S (Arrow Lake): updated Windows and BIOS fixed the launch memory latency. The "200S Boost" profile is optional (official overclock; raises limits).
+Turbo Boost e Speed Shift (HWP) ligados. Turbo Boost Max 3.0: mantenha o driver/servico (manda o jogo para os nucleos mais rapidos).	+Turbo Boost and Speed Shift (HWP) on. Turbo Boost Max 3.0: keep the driver/service (sends the game to the fastest cores).
~12a geracao ou mais nova (nucleos P + E): o Windows as vezes poe a thread do jogo num E-core. Se tiver stutter: algumas placas tem "Legacy Game Compatibility Mode" (Scroll Lock liga/desliga os E-cores) ou use o Process Lasso para prender o Fortnite nos P-cores.	~12th generation or newer (P + E cores): Windows sometimes puts the game thread on an E-core. If you get stutter: some boards have "Legacy Game Compatibility Mode" (Scroll Lock toggles E-cores) or use Process Lasso to pin Fortnite to P-cores.
~C-States: padrao (ligado) e o mais equilibrado. Desligar tira o atraso de despertar, mas esquenta; evidencia de ganho media/fraca. Meca com o LatencyMon.	~C-States: default (on) is the most balanced. Disabling removes wake latency but heats up; evidence of gain is medium/weak. Measure with LatencyMon.
~Hyper-Threading: manter ligado, salvo se voce mediu ganho desligando.	~Hyper-Threading: keep on unless you measured gain from disabling.
+EXPO ligado (se a placa/kit tiver "EXPO Ultra Low Latency", melhor ainda). Resizable BAR (SAM) ligado.	+EXPO on (if your board/kit has "EXPO Ultra Low Latency", even better). Resizable BAR (SAM) on.
+CPPC e "CPPC Preferred Cores" ligados + driver de CHIPSET da AMD instalado (sem ele o nucleo preferido nao funciona). O Diagnostico confere.	+CPPC and "CPPC Preferred Cores" on + AMD CHIPSET driver installed (without it preferred core doesn't work). Diagnostics checks.
!fTPM: BIOS com AGESA anterior ao 1.2.0.7 causa travadas de 1-2 s (audio e mouse congelam). Atualize a BIOS.	!fTPM: BIOS with AGESA prior to 1.2.0.7 causes 1-2 s hangs (audio and mouse freeze). Update BIOS.
+AM5 com DDR5-6000: FCLK ~2000 MHz e UCLK = MCLK (1:1). A regra antiga "tudo 1:1:1" e do AM4/DDR4.	+AM5 with DDR5-6000: FCLK ~2000 MHz and UCLK = MCLK (1:1). The old rule "all 1:1:1" is from AM4/DDR4.
+PBO ligado; Curve Optimizer negativo (com teste de estabilidade) da mais boost sustentado.	+PBO on; negative Curve Optimizer (with stability testing) gives more sustained boost.
~Global C-State Control: deixe o padrao (Auto/Enabled). Desligar tem resultado misto e reduz o boost.	~Global C-State Control: leave at default (Auto/Enabled). Disabling has mixed results and reduces boost.
~SMT: manter ligado. Testes controlados no Fortnite nao mostram ganho desligando.	~SMT: keep on. Controlled tests in Fortnite show no gain from disabling.
~Ryzen X3D com 2 CCDs (7900X3D/7950X3D/9900X3D/9950X3D): Game Mode e Xbox Game Bar ATIVOS + servico "AMD 3D V-Cache Performance Optimizer" (vem com o chipset). Este otimizador respeita isso sozinho.	~Ryzen X3D with 2 CCDs (7900X3D/7950X3D/9900X3D/9950X3D): Game Mode and Xbox Game Bar ACTIVE + "AMD 3D V-Cache Performance Optimizer" service (comes with chipset). This optimizer respects that on its own.
#NO JOGO (mais importante que o painel)	#IN-GAME (more important than the panel)
+NVIDIA Reflex: "Ligado + Impulso" (GTX 900 ou mais nova). Com Reflex, o limitador automatico e a fila ficam por conta dele.	+NVIDIA Reflex: "On + Boost" (GTX 900 or newer). With Reflex, the automatic limiter and queue are handled by it.
#PAINEL DE CONTROLE NVIDIA > Gerenciar config. 3D > Configuracoes de programa > Fortnite	#NVIDIA CONTROL PANEL > Manage 3D settings > Program settings > Fortnite
+Modo de gerenciamento de energia: Preferir desempenho maximo.	+Power management mode: Prefer maximum performance.
+Modo de baixa latencia: Ultra (vale para jogos SEM Reflex; no Fortnite o Reflex assume).	+Low latency mode: Ultra (applies to games WITHOUT Reflex; in Fortnite Reflex takes over).
+Filtragem de textura - qualidade: Alto desempenho.	+Texture filtering - quality: High performance.
+Otimizacao com threads: Automatico (so tem efeito em DX11/OpenGL; o Fortnite atual e DX12).	+Thread optimization: Automatic (only affects DX11/OpenGL; current Fortnite is DX12).
+Cache de shader (Configuracoes globais): padrao do driver ou Ilimitado em SSD. Evita engasgo de recompilacao; nao muda latencia.	+Shader cache (Global settings): driver default or Unlimited on SSD. Avoids recompilation stutter; doesn't change latency.
#G-SYNC (se o monitor tem)	#G-SYNC (if your monitor has it)
+Receita Blur Busters: G-SYNC ligado + V-SYNC LIGADO no painel (desligado no jogo) + Reflex ligado (limita sozinho uns FPS abaixo do Hz). Sem tearing e com latencia quase igual a FPS livre.	+Blur Busters recipe: G-SYNC on + V-SYNC ON in panel (off in-game) + Reflex on (limits FPS slightly below Hz on its own). No tearing and latency almost equal to free FPS.
~Latencia absoluta minima: sem G-SYNC, V-SYNC desligado e FPS livre (aceita tearing).	~Absolute minimum latency: no G-SYNC, V-SYNC off, free FPS (accepts tearing).
#O item "Perfil de baixa latencia" (menu GPU) aplica o painel sozinho, via NVIDIA Profile Inspector.	#The "Low latency profile" item (GPU menu) applies the panel automatically via NVIDIA Profile Inspector.
#APP NVIDIA	#NVIDIA APP
+Overlay, Instant Replay e gravacao em segundo plano: DESLIGADOS.	+Overlay, Instant Replay, and background recording: OFF.
+Stutter/erros: DDU no Modo Seguro + driver Game Ready recente (menu Programas). NVCleanstall instala so o driver, sem extras.	+Stutter/errors: DDU in Safe Mode + recent Game Ready driver (Programs menu). NVCleanstall installs driver only, no extras.
~Frame Generation (RTX 40/50) exige HAGS ligado e aumenta a latencia: nao use no competitivo.	~Frame Generation (RTX 40/50) requires HAGS on and increases latency: don't use in competitive.
~Forcar Resizable BAR em jogo fora da lista (flags do Profile Inspector) tem efeito variavel: as vezes nada, raramente instavel. Nao faz parte do perfil.	~Forcing Resizable BAR on games not in the list (Profile Inspector flags) has variable effect: sometimes nothing, rarely unstable. Not part of the profile.
#O QUE FUNCIONA NO FORTNITE	#WHAT WORKS ON FORTNITE
!Anti-Lag 2: o Fortnite NAO suporta (precisa integracao no jogo; lista oficial da AMD: CS2, Dota 2, Ghost of Tsushima).	!Anti-Lag 2: Fortnite does NOT support it (needs in-game integration; AMD's official list: CS2, Dota 2, Ghost of Tsushima).
~Anti-Lag (classico, do driver): so age em DX11. Com o Fortnite em DX12/Modo Desempenho ele nao faz efeito; pode deixar ligado sem problema.	~Anti-Lag (classic, from driver): only works in DX11. With Fortnite in DX12/Performance Mode it has no effect; you can leave it on safely.
!Nunca use Anti-Lag+ (foi removido dos drivers apos banimentos em outros jogos).	!Never use Anti-Lag+ (it was removed from drivers after bans in other games).
#AMD SOFTWARE: ADRENALIN > Jogos > Fortnite	#AMD SOFTWARE: ADRENALIN > Games > Fortnite
+Radeon Chill: DESLIGADO (quando a acao comeca, a subida de FPS atrasa justo na hora que importa).	+Radeon Chill: OFF (when action starts, the FPS ramp-up lags right when it matters).
+Radeon Boost e HYPR-RX: DESLIGADOS (o Boost muda a resolucao durante o movimento).	+Radeon Boost and HYPR-RX: OFF (Boost changes resolution during motion).
+Aguardar atualizacao vertical: "Desligado, a menos que o aplicativo especifique".	+Wait for vertical refresh: "Off unless the application specifies".
+Enhanced Sync: DESLIGADO se voce usa FreeSync + limite de FPS (o normal). So faz sentido sem FreeSync e com FPS acima do Hz.	+Enhanced Sync: OFF if you use FreeSync + FPS limit (the usual). Only makes sense without FreeSync and with FPS above Hz.
+FreeSync ligado + limite de FPS 3 abaixo do Hz (no jogo).	+FreeSync on + FPS limit 3 below Hz (in-game).
+Frame Rate Target Control: DESLIGADO (use o limitador do jogo).	+Frame Rate Target Control: OFF (use the in-game limiter).
+AFMF / Fluid Motion Frames: DESLIGADO (adiciona latencia).	+AFMF / Fluid Motion Frames: OFF (adds latency).
+Filtragem de textura: Desempenho. Cache de shader: Otimizado pela AMD. Resetar o cache so se tiver engasgos depois de trocar driver.	+Texture filtering: Performance. Shader cache: Optimized by AMD. Reset cache only if you have stutter after driver change.
+GPU Scaling LIGADO e Scaling Mode Full Panel se usar resolucao esticada.	+GPU Scaling ON and Scaling Mode Full Panel if using stretched resolution.
~A AMD nao tem API/linha de comando oficial para essas opcoes. O "FlipQueueSize" por registro circula em guias, mas drivers atuais podem ignorar: nao aplicamos o que nao da para confirmar.	~AMD has no official API/command line for these options. "FlipQueueSize" via registry circulates in guides, but current drivers may ignore it: we don't apply what we can't confirm.
+Driver: Adrenalin recente. Se trocou de marca de GPU, use DDU antes.	+Driver: recent Adrenalin. If you switched GPU brands, use DDU first.
#INTEL (graficos integrados UHD/Iris/Arc integrado e placas Arc)	#INTEL (integrated graphics UHD/Iris/integrated Arc and Arc boards)
+Graficos integrados: use o Modo DESEMPENHO do Fortnite (o mais leve).	+Integrated graphics: use Fortnite's PERFORMANCE Mode (the lightest).
+A iGPU usa a RAM do sistema: DUAL CHANNEL e com XMP e a mudanca de maior impacto (single channel corta 40-60% do desempenho).	+The iGPU uses system RAM: DUAL CHANNEL with XMP is the biggest impact change (single channel cuts 40-60% of performance).
+Placas Arc (A/B): Resizable BAR LIGADO na BIOS. A Intel diz que e praticamente obrigatorio.	+Arc boards (A/B): Resizable BAR ON in BIOS. Intel says it's practically mandatory.
+Intel Graphics Software: modo de energia desempenho maximo; sync desligado.	+Intel Graphics Software: power mode maximum performance; sync off.
!"Baixa latencia" (XeLL) so age se o jogo integrar o XeLL; no Fortnite nao ha confirmacao.	!"Low latency" (XeLL) only works if the game integrates XeLL; no confirmation on Fortnite.
~Notebook: Panel Self Refresh DESLIGADO na tomada (Intel Graphics Software > Sistema > Energia): pode causar travadinhas.	~Laptop: Panel Self Refresh OFF when plugged in (Intel Graphics Software > System > Power): can cause stutters.
+Feche navegadores/overlays: a iGPU divide calor e memoria com a CPU.	+Close browsers/overlays: the iGPU shares heat and memory with the CPU.
~Notebook: na tomada e com o exe do Fortnite marcado como "Alto desempenho" (item no menu Input Lag).	~Laptop: plugged in and with Fortnite exe marked as "High performance" (item in Input Lag menu).
#O QUE REALMENTE BAIXA O PING	#WHAT REALLY LOWERS PING
+Cabo Ethernet (Cat5e ou melhor) direto no roteador.	+Ethernet cable (Cat5e or better) directly to the router.
+Servidor certo: no Fortnite, Configuracoes > Jogo > Regiao de matchmaking = a mais proxima (Brasil).	+Right server: in Fortnite, Settings > Game > Matchmaking region = the closest one (Brazil).
+Nao baixar/streamar junto (bufferbloat). Se o roteador tiver SQM/QoS (fq_codel/cake), ligue; ou limite a banda a ~90%.	+Don't download/stream together (bufferbloat). If your router has SQM/QoS (fq_codel/cake), enable it; or limit bandwidth to ~90%.
+Reinicie o roteador de vez em quando e mantenha o firmware atualizado.	+Restart the router occasionally and keep firmware updated.
#SE PRECISA USAR WI-FI	#IF YOU NEED TO USE WI-FI
+Banda 5 GHz ou 6 GHz (Wi-Fi 6E), perto do roteador e sem paredes; canal limpo.	+Band 5 GHz or 6 GHz (Wi-Fi 6E), near the router and no walls; clean channel.
+Roaming do adaptador no minimo e economia de energia do adaptador em desempenho maximo (item "Adaptador de rede").	+Adapter roaming at minimum and adapter power saving on maximum performance (item "Network adapter").
+Feche apps que usam rede e desligue VPN durante a partida.	+Close apps that use network and disable VPN during the match.
#COMO MEDIR	#HOW TO MEASURE
~No Diagnostico ha um teste de ping/jitter para os servidores da Epic (ICMP; o jogo usa UDP, entao serve como base). Jitter abaixo de 10 ms e bom.	~In Diagnostics there's a ping/jitter test for Epic's servers (ICMP; the game uses UDP so it's a baseline). Jitter below 10 ms is good.
#O QUE TEM POUCO OU NENHUM EFEITO	#WHAT HAS LITTLE OR NO EFFECT
~Nagle, reserva de QoS de 20% e NetworkThrottlingIndex: o gameplay e UDP; ganhos pequenos ou nulos. Estao no menu como opcionais e reversiveis.	~Nagle, 20% QoS reserve, and NetworkThrottlingIndex: gameplay is UDP; small or no gains. They're in the menu as optional and reversible.
#MITOS E PLACEBO (circulam em "packs de otimizacao")	#MYTHS AND PLACEBO (circulate in "optimization packs")
~Nada aqui e aplicado pelo otimizador. A lista existe para voce nao perder tempo nem seguranca.	~Nothing here is applied by the optimizer. The list exists so you don't waste time or security.
!DisablePagingExecutive=1: afeta um grupo minusculo de drivers; com pouca RAM pode piorar.	!DisablePagingExecutive=1: affects a tiny group of drivers; with little RAM it can make it worse.
!LargeSystemCache=1: feito para servidor de arquivos. A propria Microsoft desaconselha em PC de jogo.	!LargeSystemCache=1: made for file server. Microsoft itself advises against it on gaming PC.
!SvcHostSplitThresholdInKB: muda o isolamento de servicos, nao latencia.	!SvcHostSplitThresholdInKB: changes service isolation, not latency.
!Desligar a compressao de memoria (MMAgent): teste controlado nao achou ganho; com 8-16 GB pode piorar.	!Disable memory compression (MMAgent): controlled test found no gain; with 8-16 GB it can make it worse.
!useplatformtick / useplatformclock (HPET forcado): os tweaks de timer com mais relatos de PIORAR input lag. O otimizador nunca liga; o BCDEdit avancado so REMOVE o useplatformclock se alguem forcou.	!useplatformtick / useplatformclock (forced HPET): timer tweaks with most reports of WORSENING input lag. The optimizer never enables it; advanced BCDEdit only REMOVES useplatformclock if someone forced it.
!IRQ priority / "IRQ8Priority": chave sem efeito no Windows moderno.	!IRQ priority / "IRQ8Priority": key with no effect on modern Windows.
!Desligar SMT/Hyper-Threading "por latencia": no Fortnite a diferenca fica dentro da margem de erro.	!Disable SMT/Hyper-Threading "for latency": on Fortnite the difference is within the margin of error.
!Desligar mitigacoes Spectre em CPU recente: ganho ~0 e perda real de seguranca (em CPU antiga ha algum ganho; item de risco no menu CPU).	!Disable Spectre mitigations on recent CPU: ~0 gain and real security loss (on older CPU there's some gain; risk item in CPU menu).
!Overclock de ring/uncore "para FPS": reduz latencia de cache no papel, quase nada no jogo, e aumenta o risco de instabilidade.	!Ring/uncore overclock "for FPS": reduces cache latency on paper, almost nothing in-game, and increases instability risk.
!Desligar HDCP ou telemetria da NVIDIA: zero efeito no jogo (HDCP so afeta video protegido).	!Disable HDCP or NVIDIA telemetry: zero effect on game (HDCP only affects protected video).
!Desligar ULPS numa GPU AMD unica: so importa em CrossFire ou notebook hibrido.	!Disable ULPS on a single AMD GPU: only matters in CrossFire or hybrid laptop.
!"Threaded Optimization sempre ON": resultado misto, pode piorar frametime em jogo leve.	!"Threaded Optimization always ON": mixed results, can worsen frametime in light games.
!Limitar FPS muito abaixo do que o PC aguenta "por consistencia": aumenta a latencia. Limite so 3 abaixo do Hz (com VRR) ou use o Reflex.	!Limit FPS way below what your PC can handle "for consistency": increases latency. Limit only 3 below Hz (with VRR) or use Reflex.
!DisableDynamicPstate "obrigatorio": quase igual ao "Preferir desempenho maximo" no jogo; so aumenta consumo parado (opcional no menu GPU).	!DisableDynamicPstate "mandatory": almost the same as "Prefer maximum performance" in-game; only increases idle power draw (optional in GPU menu).
#REDE	#NETWORK
!"Liberar os 20% de banda reservada do QoS": o Windows nao reserva banda assim para jogos.	!"Free up the 20% QoS reserved bandwidth": Windows doesn't reserve bandwidth like that for games.
!TCP tweaks para ping in-game: o Fortnite joga por UDP; TCP so pesa em login/loja/downloads.	!TCP tweaks for in-game ping: Fortnite plays via UDP; TCP only matters for login/shop/downloads.
GUIA IN-GAME FORTNITE	IN-GAME FORTNITE GUIDE
GUIA DE HARDWARE (impacto real)	HARDWARE GUIDE (real impact)
GUIA DE BIOS (Intel / AMD Ryzen)	BIOS GUIDE (Intel / AMD Ryzen)
GUIA NVIDIA	NVIDIA GUIDE
GUIA AMD RADEON	AMD RADEON GUIDE
GUIA INTEL GRAFICOS	INTEL GRAPHICS GUIDE
GUIA DE REDE (cabo e Wi-Fi)	NETWORK GUIDE (cable and Wi-Fi)
MITOS E PLACEBO	MYTHS AND PLACEBO
Erro inesperado:	Unexpected error:
[GUIA]	[GUIDE]
[SEGURO]	[SAFE]
[AVANCADO]	[ADVANCED]
[RISCO ALTO]	[HIGH RISK]
Evidencia:	Evidence:
[precisa REINICIAR]	[needs RESTART]
(Nao se aplica ao hardware detectado neste PC - marque "Sim" na confirmacao se quiser forcar.)	(Does not apply to the hardware detected on this PC - mark "Yes" in the confirmation if you want to force it.)
Nao ha valor original salvo por esta versao (foi aplicado por outra versao ou por voce?). Use Restaurar > backups do v1.5.	No original value saved by this version (was it applied by another version or by you?). Use Restore > v1.5 backups.
Valor original restaurado.	Original value restored.
Este item nao tem desfazer proprio.	This item has no undo of its own.
Este item e para outro hardware. Detectado aqui:	This item is for different hardware. Detected here:
Aplicar mesmo assim?	Apply anyway?
Ja esta aplicado. Desfazer (voltar ao valor original)?	Already applied. Undo (go back to original value)?
Aplicar agora?	Apply now?
Aplicado.	Applied.
Nao foi possivel aplicar tudo (veja acima).	Could not apply everything (see above).
Reinicie o PC para este item valer.	Restart the PC for this item to take effect.
== SEGUROS (recomendados) ==	== SAFE (recommended) ==
== AVANCADOS (efeito moderado / opcionais) ==	== ADVANCED (moderate effect / optional) ==
== RISCO ALTO / EXPERIMENTAIS (so se souber o que faz) ==	== HIGH RISK / EXPERIMENTAL (only if you know what you're doing) ==
== GUIAS ==	== GUIDES ==
Volta ao menu principal.	Back to main menu.
Guia: configuracao dentro do jogo (Fortnite)	Guide: in-game configuration (Fortnite)
Guia: hardware fisico (monitor, mouse, rede, RAM)	Guide: physical hardware (monitor, mouse, network, RAM)
Guia: BIOS (Intel e AMD Ryzen)	Guide: BIOS (Intel and AMD Ryzen)
Guia: NVIDIA (Painel de Controle / App / Reflex)	Guide: NVIDIA (Control Panel / App / Reflex)
Guia: AMD Radeon (Adrenalin)	Guide: AMD Radeon (Adrenalin)
Guia: Intel graficos (iGPU / Arc)	Guide: Intel graphics (iGPU / Arc)
Guia: rede (cabo e Wi-Fi)	Guide: network (cable and Wi-Fi)
Guia: MITOS e placebo (o que NAO fazer)	Guide: MYTHS and placebo (what NOT to do)
Texto de referencia, nao altera nada no PC.	Reference text, changes nothing on the PC.
== SUA GPU:	== YOUR GPU:
== NVIDIA (automatizado) ==	== NVIDIA (automated) ==
== AMD RADEON (guia: a AMD nao tem API oficial p/ automatizar) ==	== AMD RADEON (guide: AMD has no official API to automate) ==
== INTEL GRAFICOS ==	== INTEL GRAPHICS ==
== TODAS AS MARCAS ==	== ALL BRANDS ==
Cada item traz a etiqueta da marca. Itens de outra marca aparecem apagados.	Each item has the brand tag. Items from other brands appear grayed out.
Referencia por marca e por tipo de hardware. Nao altera nada.	Reference by brand and hardware type. Changes nothing.
nome nao resolve	name does not resolve
sem resposta ICMP (o jogo usa UDP; pode estar bloqueado)	no ICMP response (the game uses UDP; may be blocked)
TESTE DE PING / JITTER (servidores da Epic)	PING / JITTER TEST (Epic's servers)
ICMP e uma base aproximada (o jogo usa UDP). Bom: ping BR abaixo de 30 ms, jitter abaixo de 10 ms, perda 0%.	ICMP is an approximate baseline (the game uses UDP). Good: BR ping below 30 ms, jitter below 10 ms, 0% loss.
Brasil	Brazil
NA-Leste	NA-East
NA-Oeste	NA-West
Europa	Europe
Oriente Medio	Middle East
Regiao	Region
Voce esta no Wi-Fi: espere jitter maior que no cabo. Se possivel, teste com Ethernet.	You are on Wi-Fi: expect higher jitter than on cable. If possible, test with Ethernet.
DIAGNOSTICO DO SISTEMA	SYSTEM DIAGNOSTICS
SISTEMA   {0} {1} (build {2}) | notebook: {3}	SYSTEM   {0} {1} (build {2}) | laptop: {3}
GPU       nao detectada	GPU       not detected
| hibrida P+E	| hybrid P+E
CPU       {0}  [{1}]  {2} nucleos / {3} threads{4}	CPU       {0}  [{1}]  {2} cores / {3} threads{4}
MEMORIA   {0} GB {1} @ {2} MT/s  ({3} pente(s))	MEMORY   {0} GB {1} @ {2} MT/s  ({3} stick(s))
REDE      {0}: {1}  ({2})  {3}	NETWORK      {0}: {1}  ({2})  {3}
TELA      {0}x{1} @ {2} Hz  (maximo oferecido nesta resolucao: {3} Hz)	DISPLAY      {0}x{1} @ {2} Hz  (maximum offered at this resolution: {3} Hz)
FORTNITE  instalacao nao encontrada	FORTNITE  installation not found
POWER     plano ativo:	POWER     active plan:
O QUE CHAMA ATENCAO NO SEU PC:	WHAT STANDS OUT ON YOUR PC:
Tela em {0} Hz mas o Windows oferece {1} Hz: use "Taxa de atualizacao no MAXIMO" (menu Input Lag).	Display at {0} Hz but Windows offers {1} Hz: use "Refresh rate at MAXIMUM" (Input Lag menu).
Apenas 1 pente de RAM = single channel (perde desempenho, muito pior com GPU integrada).	Only 1 RAM stick = single channel (loses performance, much worse with integrated GPU).
Sua RAM roda a {0} MT/s (velocidade padrao JEDEC). Se o kit e mais rapido, ligue o XMP/EXPO na BIOS.	Your RAM runs at {0} MT/s (JEDEC standard speed). If the kit is faster, enable XMP/EXPO in BIOS.
Voce joga no Wi-Fi: cabo Ethernet e o maior ganho possivel de estabilidade (menos jitter).	You play on Wi-Fi: Ethernet cable is the biggest possible stability gain (less jitter).
Notebook: use na tomada e confirme que o Fortnite roda na GPU dedicada.	Laptop: use plugged in and confirm Fortnite runs on the dedicated GPU.
Mais de uma GPU: garanta que o jogo usa a dedicada (item "Fortnite sempre na GPU de alto desempenho").	Multiple GPUs: ensure the game uses the dedicated one (item "Fortnite always on high-performance GPU").
VBS/Integridade de memoria esta ATIVA (custa FPS em alguns jogos; e uma troca com seguranca).	VBS/Memory Integrity is ACTIVE (costs FPS on some games; it's a trade-off with security).
HAGS (agendamento por hardware):	HAGS (hardware scheduling):
Nada de errado saltou aos olhos.	Nothing obviously wrong stands out.
TIMER DO WINDOWS	WINDOWS TIMER
Task de timer forcado:	Forced timer task:
ATIVA	ACTIVE
nao definido	not set
#Estado de cada otimizacao neste PC (ON = aplicada, OFF = nao aplicada, - = nao se aplica ao hardware)	#Status of each optimization on this PC (ON = applied, OFF = not applied, - = doesn't apply to hardware)
ESTADO DAS OTIMIZACOES	OPTIMIZATION STATUS
Resumo do hardware e alertas do seu PC	Summary of hardware and alerts on your PC
GPU, CPU, RAM, rede, tela, Fortnite e o que chama atencao (RAM em velocidade baixa, Wi-Fi, Hz abaixo do maximo...).	GPU, CPU, RAM, network, display, Fortnite and what stands out (RAM at low speed, Wi-Fi, Hz below maximum...).
Estado de todas as otimizacoes (ON / OFF)	Status of all optimizations (ON / OFF)
Confere o que ja esta aplicado agora, lendo o sistema.	Checks what's already applied now by reading the system.
Teste de ping e jitter (servidores da Epic)	Ping and jitter test (Epic's servers)
Mede ping, jitter e perda para as regioes da Epic (ICMP).	Measures ping, jitter, and loss for Epic's regions (ICMP).
Medir o timer do Windows (Sleep 1 ms)	Measure Windows timer (Sleep 1 ms)
Mostra a resolucao do timer e o quanto Sleep(1) realmente demora.	Shows timer resolution and how long Sleep(1) actually takes.
Criando ponto de restauracao (pode levar ~30 s; ok se falhar)...	Creating restore point (may take ~30 s; ok if it fails)...
O Windows so cria 1 ponto a cada 24 h; seguimos com os backups proprios.	Windows only creates 1 point every 24 h; we continue with our own backups.
Ponto de restauracao criado.	Restore point created.
Ponto de restauracao nao criado (Protecao do Sistema desligada?). Seguimos com os backups proprios.	Restore point not created (System Protection off?). We continue with our own backups.
APLICAR TUDO SEGURO	APPLY ALL SAFE
APLICAR SEGURO + AVANCADO	APPLY SAFE + ADVANCED
Para o SEU hardware (	For YOUR hardware (
[ja aplicado]	[already applied]
[aplicar]	[apply]
Nao entram (fazem perguntas, derrubam a rede ou sao de risco alto): HAGS, LSO, Win32PrioritySeparation, congelar INI, pausar Update, exclusoes do Defender, VBS, MPO, BCDEdit, HID, C0, GPU travada no P0, Spectre.	Do not include (ask questions, break network or are high risk): HAGS, LSO, Win32PrioritySeparation, freeze INI, pause Update, Defender exclusions, VBS, MPO, BCDEdit, HID, C0, GPU stuck at P0, Spectre.
Nada a fazer: tudo ja esta aplicado.	Nothing to do: everything is already applied.
Aplicar {0} otimizacao(oes)? Cada uma guarda o original antes (desfaz em Restaurar).	Apply {0} optimization(s)? Each one saves the original first (undo in Restore).
Concluido: {0} aplicada(s), {1} com falha.	Done: {0} applied, {1} failed.
REINICIE o PC. Depois: Fortnite > preset de performance (INI) e o guia in-game.	RESTART the PC. Then: Fortnite > performance preset (INI) and the in-game guide.
Bulk nivel {0}: {1} ok, {2} falhas	Bulk level {0}: {1} ok, {2} failures
Aplicar TUDO SEGURO (nivel 1) para o meu hardware	Apply ALL SAFE (level 1) for my hardware
So os itens marcados [SEGURO], filtrados pelo seu hardware (NVIDIA/AMD/Intel, Ryzen, Wi-Fi...). Cria ponto de restauracao e guarda o valor original de tudo.	Only items marked [SAFE], filtered by your hardware (NVIDIA/AMD/Intel, Ryzen, Wi-Fi...). Creates restore point and saves the original value of everything.
Aplicar SEGURO + AVANCADO (niveis 1 e 2)	Apply SAFE + ADVANCED (levels 1 and 2)
Inclui os de efeito moderado (prioridade fixa do jogo, timer forcado, USB, rede...). Nunca inclui os de risco alto nem os que derrubam a rede.	Includes moderate-effect ones (fixed game priority, forced timer, USB, network...). Never includes high-risk or network-breaking ones.
Nenhum backup do v1.5 encontrado.	No v1.5 backup found.
Backups do v1.5: {0} arquivo(s) .reg, {1} chave(s) criada(s).	v1.5 backups: {0} .reg file(s), {1} key(s) created.
Importado:	Imported:
Tipo de inicio dos servicos restaurado.	Service startup type restored.
Backups antigos movidos para a subpasta "v1.5_restaurado".	Old backups moved to "v1.5_restored" subfolder.
Desfazendo (nesta ordem): itens desta versao, depois backups do v1.5.	Undoing (in this order): items from this version, then v1.5 backups.
{0} valor(es) de registro restaurado(s).	{0} registry value(s) restored.
Restaurar tudo	Restore all
Pronto. REINICIE o PC para tudo voltar a valer.	Done. RESTART the PC for everything to take effect.
Restaurado:	Restored:
Nenhum .bak dos INIs do Fortnite encontrado.	No .bak of Fortnite INIs found.
DESFAZER TUDO (esta versao + backups do v1.5)	UNDO EVERYTHING (this version + v1.5 backups)
Restaura cada valor de registro ao original exato, plano de energia, rede (DNS/TCP/adaptador/LSO/tuneis), USB, BCDEdit, timer forcado, audio, Defender e INIs. Depois aplica os backups .reg do v1.5 (se existirem). Reinicie depois.	Restores each registry value to the exact original, power plan, network (DNS/TCP/adapter/LSO/tunnels), USB, BCDEdit, forced timer, audio, Defender, and INIs. Then applies v1.5 .reg backups (if any exist). Restart afterwards.
So os backups do v1.5 (arquivos .reg antigos)	Only v1.5 backups (old .reg files)
Reimporta os .reg, apaga valores/chaves que o v1.5 criou e volta o plano de energia e os servicos.	Re-imports .reg files, deletes values/keys that v1.5 created, and restores the power plan and services.
INIs do Fortnite (GameUserSettings.ini / Engine.ini)	Fortnite INIs (GameUserSettings.ini / Engine.ini)
Volta os arquivos ao .bak feito na 1a alteracao.	Returns files to the .bak made at first change.
So o plano de energia	Only the power plan
Reativa o plano que estava ativo antes do "Fortnite Otimizador".	Reactivates the plan that was active before "Fortnite Optimizer".
Resolucao nativa (Windows + Fortnite)	Native resolution (Windows + Fortnite)
Volta a resolucao salva antes dos presets esticados.	Restores resolution saved before stretched presets.
Reinstalar a Xbox Game Bar (versoes antigas desinstalavam)	Reinstall Xbox Game Bar (old versions uninstalled it)
Abre a pagina da Game Bar na Microsoft Store.	Opens the Game Bar page on Microsoft Store.
Resetar TODOS os planos de energia p/ o padrao de fabrica	Reset ALL power plans to factory default
Apaga planos personalizados (inclusive o "Fortnite Otimizador"). Destrutivo.	Deletes custom plans (including "Fortnite Optimizer"). Destructive.
Abrir a pasta de backups	Open backups folder
RESTAURAR / DESFAZER	RESTORE / UNDO
Backups em:	Backups at:
Desfazer TUDO que este otimizador (e o v1.5) alterou?	Undo EVERYTHING this optimizer (and v1.5) changed?
Aplicar os backups .reg do v1.5?	Apply v1.5 .reg backups?
Sem resolucao nativa salva.	No native resolution saved.
abrir Store	open Store
Isto APAGA planos de energia personalizados. Continuar?	This DELETES custom power plans. Continue?
Planos de fabrica.	Factory plans.
abrir pasta	open folder
Diagnostico (hardware, alertas, ping, timer)	Diagnostics (hardware, alerts, ping, timer)
Detecta GPU/CPU/RAM/rede/tela, avisa o que esta fora do ideal (Hz abaixo do maximo, RAM lenta, Wi-Fi...) e mede ping, jitter e o timer.	Detects GPU/CPU/RAM/network/display, warns what's not ideal (Hz below maximum, slow RAM, Wi-Fi...) and measures ping, jitter, and timer.
Input Lag: tela, mouse, USB, MSI, jogo, seguranca	Input Lag: display, mouse, USB, MSI, game, security
Taxa de atualizacao maxima, Game Mode, mouse, USB/HID, MSI Mode, FSO, HAGS, audio e itens de risco (VBS, MPO, BCDEdit).	Maximum refresh rate, Game Mode, mouse, USB/HID, MSI Mode, FSO, HAGS, audio, and risk items (VBS, MPO, BCDEdit).
CPU / Energia / Timer / Prioridades	CPU / Power / Timer / Priorities
Plano de energia proprio, timer do Windows, prioridade do Fortnite, C-states. Detecta Intel x Ryzen (X3D tratado a parte).	Own power plan, Windows timer, Fortnite priority, C-states. Detects Intel vs Ryzen (X3D handled separately).
Perfil de baixa latencia via NVIDIA Profile Inspector (automatico), overlay, clock. Guias para AMD e Intel. Cada item mostra a marca.	Low latency profile via NVIDIA Profile Inspector (automatic), overlay, clock. Guides for AMD and Intel. Each item shows the brand.
Rede: Ethernet e Wi-Fi	Network: Ethernet and Wi-Fi
Adaptador (por palavra-chave do driver), DNS, TCP, tuneis, LSO, reset. Detecta se voce esta no cabo ou no Wi-Fi.	Adapter (by driver keyword), DNS, TCP, tunnels, LSO, reset. Detects if you're on cable or Wi-Fi.
Fortnite: INI, launch options, foco, resolucao esticada	Fortnite: INI, launch options, focus, stretched resolution
Preset de performance no GameUserSettings.ini, modo foco, resolucoes esticadas de pro, replays, verificar arquivos.	Performance preset in GameUserSettings.ini, focus mode, pro stretched resolutions, replays, verify files.
Sistema: limpeza, servicos, update, Defender	System: cleanup, services, update, Defender
Temporarios, apps em 2o plano, servicos pesados, pausar update, exclusoes do Defender, SSD x HD.	Temp files, background apps, heavy services, pause update, Defender exclusions, SSD vs HD.
Programas e integracoes (winget)	Programs and integrations (winget)
Instala e abre por aqui: NVIDIA Profile Inspector, CapFrameX, LatencyMon, ISLC, HWiNFO, Process Lasso, DDU, CRU...	Install and open from here: NVIDIA Profile Inspector, CapFrameX, LatencyMon, ISLC, HWiNFO, Process Lasso, DDU, CRU...
APLICAR TUDO (para o meu hardware)	APPLY ALL (for my hardware)
Aplica em lote os itens SEGUROS (ou seguros + avancados) filtrados pelo seu hardware, com ponto de restauracao e backup de cada valor.	Batch-applies SAFE items (or safe + advanced) filtered by your hardware, with restore point and backup of each value.
Guias: jogo, BIOS, hardware, por marca	Guides: game, BIOS, hardware, by brand
Texto de referencia: configuracao in-game, BIOS Intel/Ryzen, NVIDIA/AMD/Intel, rede, hardware fisico.	Reference text: in-game config, BIOS Intel/Ryzen, NVIDIA/AMD/Intel, network, physical hardware.
Restaurar / desfazer	Restore / undo
Volta tudo ao original: valores de registro exatos, energia, rede, INIs, e os backups da versao 1.5.	Restores everything to original: exact registry values, power, network, INIs, and v1.5 backups.
Sair	Exit
[!] REINICIO PENDENTE	[!] RESTART PENDING
MENU PRINCIPAL	MAIN MENU
Setas: mover | Enter: escolher | Esc: sair | 0-9: pular	Arrows: move | Enter: select | Esc: exit | 0-9: jump
Sair do otimizador?	Exit the optimizer?
Tela, mouse, USB, MSI, jogo e seguranca. Etiquetas mostram a que hardware cada item se aplica.	Display, mouse, USB, MSI, game, and security. Tags show which hardware each item applies to.
CPU detectada:	CPU detected:
CPU / ENERGIA / TIMER	CPU / POWER / TIMER
REDE: ETHERNET / WI-FI	NETWORK: ETHERNET / WI-FI
Conexao principal:	Main connection:
Feche o jogo antes de editar os INIs.	Close the game before editing the INIs.
Limpeza, servicos, update e Defender.	Cleanup, services, update, and Defender.
input lag no minimo	input lag to the minimum
Lendo o sistema operacional...	Reading the operating system...
Detectando GPU (NVIDIA / AMD / Intel)...	Detecting GPU (NVIDIA / AMD / Intel)...
Detectando CPU e memoria...	Detecting CPU and memory...
Detectando rede (cabo / Wi-Fi)...	Detecting network (cable / Wi-Fi)...
Lendo a taxa de atualizacao da tela...	Reading display refresh rate...
Procurando o Fortnite...	Looking for Fortnite...
Aguarde...	Please wait...
Pronto!	Ready!
Pressione qualquer tecla para iniciar...	Press any key to start...
Deteccao parcial:	Partial detection:
MODO TESTE: nada sera gravado no sistema.	TEST MODE: nothing will be saved to the system.
hardware detectado (GPU/CPU/RAM/rede/tela)	hardware detected (GPU/CPU/RAM/network/display)
catalogo: Ids unicos	catalog: unique IDs
catalogo: campos obrigatorios	catalog: required fields
catalogo: toggle tem Apply ou RegsFn; action tem Apply	catalog: toggle has Apply or RegsFn; action has Apply
catalogo: descricoes so ASCII	catalog: descriptions ASCII only
nao-ascii:	non-ascii:
regs bem formados:	well-formed regs:
estado (leitura):	status (reading):
item de menu:	menu item:
dry-run aplicar+desfazer:	dry-run apply+undo:
bulk nivel 1 tem itens	bulk level 1 has items
bulk nivel 2 > nivel 1	bulk level 2 > level 1
bulk nunca inclui risco alto / NoBulk	bulk never includes high risk / NoBulk
registro: backup exato, restore, chave criada removida	registry: exact backup, restore, created key removed
INI: preset em arquivo de teste (	INI: preset in test file (
INI: remover chave	INI: remove key
NVIDIA .nip: XML valido e IDs conferidos	NVIDIA .nip: valid XML and IDs checked
NVIDIA .nip: desserializa com as MESMAS classes do Profile Inspector	NVIDIA .nip: deserializes with the SAME classes as Profile Inspector
ajustes do adaptador: leitura sem erro	adapter settings: read without error
checks de rede (TCP/tuneis/LSO/USB): sem excecao	network checks (TCP/tunnels/LSO/USB): no exception
plano de energia: leitura	power plan: reading
MSI: alvos e estado	MSI: targets and status
timer: leitura e medicao	timer: reading and measurement
tela: modos e modo atual	display: modes and current mode
guias: todos com conteudo ASCII	guides: all with ASCII content
Bios	BIOS
Nvidia	NVIDIA
Amd	AMD
Net	Network
nao-ascii no guia	non-ASCII in guide
programas (winget): IDs e campos	programs (winget): IDs and fields
menu com setas (teclas simuladas)	menu with arrows (simulated keys)
menu: cabecalho e ignorado; Esc volta -1	menu: header is ignored; Esc returns -1
confirmacao Sim/Nao com setas	Yes/No confirmation with arrows
guias: estilo de linha valido (cores existem)	guides: valid line style (colors exist)
estilo invalido:	invalid style:
creditos aparecem em banner, menu, guia e despedida	credits appear in banner, menu, guide, and goodbye
plano: configuracoes bem formadas (todos os perfis)	plan: well-formed settings (all profiles)
duplicada em	duplicated in
plano: X3D 2 CCDs NAO mexe em core parking; classico trava minimo 100; hibrido prefere P-cores	plan: X3D 2 CCDs does NOT touch core parking; classic minimum 100 lock; hybrid prefers P-cores
plano: deteccao de perfil por CPU (simulado)	plan: profile detection by CPU (simulated)
plano: dry-run de cada perfil + exportar/detalhes	plan: dry-run of each profile + export/details
plano: configuracoes existem neste Windows (informativo)	plan: settings exist on this Windows (informational)
ausentes aqui (serao ignoradas):	absent here (will be ignored):
plano REAL (plano temporario descartavel):	REAL plan (temporary disposable plan):
ignoradas=	ignored=
problemas=	problems=
PROBLEMA:	PROBLEM:
arte: letras grandes = ANSI Shadow original (FORT, 2 primeiras linhas)	art: large letters = original ANSI Shadow (FORT, first 2 lines)
arte: N (algoritmo da sombra confere com a fonte)	art: N (shadow algorithm matches the font)
arte: sprites retangulares e cores validas	art: rectangular sprites and valid colors
sprite ruim:	bad sprite:
arte: modo Unicode gera blocos/cabecalhos sem erro (todas as telas)	art: Unicode mode generates blocks/headers without error (all screens)
arte falhou:	art failed:
DirectX: token SwapEffectUpgradeEnable preserva os outros	DirectX: SwapEffectUpgradeEnable token preserves others
diagnostico: alertas extras rodam sem excecao	diagnostics: extra alerts run without exception
NVIDIA: chaves de classe do adaptador (leitura)	NVIDIA: adapter class keys (reading)
wrap de texto	text wrap
=== {0} ok, {1} falha(s) ===	=== {0} ok, {1} failure(s) ===
Obrigado por usar o	Thanks for using
GG! Bom jogo.	GG! Have a good game.
[ERRO] Execute como ADMINISTRADOR (clique direito no .bat > Executar como administrador).	[ERROR] Run as ADMINISTRATOR (right-click .bat > Run as administrator).
Para so olhar/testar sem alterar nada, rode com o argumento -DryRun.	To only look/test without changing anything, run with the -DryRun argument.
Enter para sair	Press Enter to exit
Erro fatal:	Fatal error:
Ate mais! Se aplicou algo, REINICIE o PC.	See you! If you applied anything, RESTART the PC.
Backups e log em:	Backups and log at:
Rede	Network
(S/N)	(Y/N)
O T I M I Z A D O R	O P T I M I Z E R
Evidencia	Evidence
forte	strong
media	medium
fraca	weak
nenhuma	none
mista	mixed
ligado	on
desligado	off
nao	no
HAGS (agendamento por hardware)	HAGS (hardware-accelerated GPU scheduling)
Task de timer forcado	Forced timer task
Base do plano	Plan base
reinicie	restart
#Perfil:	#Profile:
#Configuracoes (na tomada / AC):	#Settings (plugged in / AC):
#VIDEO > TELA	#VIDEO > DISPLAY
#VIDEO > MODO DE RENDERIZACAO	#VIDEO > RENDERING MODE
#VIDEO > GRAFICOS	#VIDEO > GRAPHICS
e importar: -silentImport	and import: -silentImport
'@

# =====================================================================
#  DETECCAO DE HARDWARE  ->  $script:HW
#  Cada modulo e isolado: se um falhar, o resto continua.
# =====================================================================
$script:HW = @{
    Os = @{ Caption = 'Windows'; Build = 0; Display = ''; IsWin11 = $false }
    Gpus = @(); Gpu = $null; HasNvidia = $false; HasAmd = $false; HasIntelGpu = $false; Hybrid = $false
    Cpu = @{ Name = 'CPU'; Vendor = 'OTHER'; Cores = 0; Threads = 0; IsX3D = $false; DualCcdX3D = $false; IntelHybrid = $false }
    Ram = @{ TotalGB = 0; Speed = 0; Modules = 0; Type = '' }
    Net = @{ Name = ''; Desc = ''; Kind = 'NONE'; Link = '' }; Nics = @()
    Display = @{ W = 0; H = 0; Hz = 0; MaxHz = 0; MaxHzAny = 0 }
    Laptop = $false
    Fn = @{ Dir = $null; Exe = $null; ConfigDir = $null; Ini = $null; EngineIni = $null }
    Errors = @()
}

function Get-GpuVendor {
    param([string]$Name, [string]$Pnp)
    if ($Pnp -match 'VEN_10DE') { return 'NVIDIA' }
    if ($Pnp -match 'VEN_1002|VEN_1022') { return 'AMD' }
    if ($Pnp -match 'VEN_8086') { return 'INTEL' }
    if ($Name -match 'NVIDIA|GeForce|Quadro|RTX|GTX') { return 'NVIDIA' }
    if ($Name -match 'AMD|Radeon|ATI') { return 'AMD' }
    if ($Name -match 'Intel|UHD|Iris|Arc') { return 'INTEL' }
    return 'OTHER'
}

function Detect-Os {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $script:HW.Os.Caption = [string]$os.Caption
        $script:HW.Os.Build = [int]$os.BuildNumber
        $script:HW.Os.IsWin11 = ([int]$os.BuildNumber -ge 22000)
        $dv = Get-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
        if ($dv) { $script:HW.Os.Display = [string]$dv }
        $enc = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes)
        $lap = $false
        foreach ($c in $enc) { if (@(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) -contains [int]$c) { $lap = $true } }
        if (-not $lap -and (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) { $lap = $true }
        $script:HW.Laptop = $lap
    } catch { $script:HW.Errors += ('OS: ' + $_.Exception.Message) }
}

function Detect-Gpu {
    try {
        $list = @()
        $raw = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object {
                $_.Name -and $_.Name -notmatch 'Basic Render|Basic Display|Virtual|VMware|Hyper-V|Remote|Parsec|Citrix|Mirage|DisplayLink|Meta Virtual|VirtualBox|Oray|Sunshine|Idd'
            })
        foreach ($g in $raw) {
            $v = Get-GpuVendor -Name $g.Name -Pnp $g.PNPDeviceID
            $disc = $false
            if ($v -eq 'NVIDIA') { $disc = $true }
            elseif ($v -eq 'AMD') { $disc = ($g.Name -match 'RX|Pro|Vega 56|Vega 64|Radeon VII|R9|R7 2|HD [5-9]') -and ($g.Name -notmatch 'Radeon\(TM\) Graphics|Radeon Graphics') }
            elseif ($v -eq 'INTEL') { $disc = ($g.Name -match 'Arc') -and ($g.Name -notmatch 'Arc\(TM\) Graphics') }
            $list += @{ Name = [string]$g.Name; Vendor = $v; Driver = [string]$g.DriverVersion; Pnp = [string]$g.PNPDeviceID; Discrete = $disc }
        }
        $script:HW.Gpus = $list
        $script:HW.HasNvidia = [bool](@($list | Where-Object { $_.Vendor -eq 'NVIDIA' }).Count)
        $script:HW.HasAmd = [bool](@($list | Where-Object { $_.Vendor -eq 'AMD' }).Count)
        $script:HW.HasIntelGpu = [bool](@($list | Where-Object { $_.Vendor -eq 'INTEL' }).Count)
        $script:HW.Hybrid = ($list.Count -gt 1)
        $best = $null
        foreach ($g in $list) { if ($g.Discrete) { $best = $g; break } }
        if (-not $best -and $list.Count -gt 0) { $best = $list[0] }
        $script:HW.Gpu = $best
    } catch { $script:HW.Errors += ('GPU: ' + $_.Exception.Message) }
}

function Detect-Cpu {
    try {
        $c = @(Get-CimInstance Win32_Processor -ErrorAction Stop)[0]
        $name = ([string]$c.Name).Trim()
        $vendor = 'OTHER'
        if ($c.Manufacturer -match 'Intel') { $vendor = 'INTEL' } elseif ($c.Manufacturer -match 'AMD|Advanced Micro') { $vendor = 'AMD' }
        $script:HW.Cpu = @{
            Name = $name; Vendor = $vendor
            Cores = [int]$c.NumberOfCores; Threads = [int]$c.NumberOfLogicalProcessors
            IsX3D = [bool]($name -match 'X3D')
            DualCcdX3D = [bool]($name -match '(79|99)[05]0X3D')
            IntelHybrid = [bool]($vendor -eq 'INTEL' -and $name -match '(1[2-9]th Gen|Core\(TM\) Ultra|Core Ultra)')
        }
        $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
        if ($mods.Count -gt 0) {
            $sum = 0
            foreach ($m in $mods) { $sum += [double]$m.Capacity }
            $spd = 0
            foreach ($m in $mods) {
                $s = [int]$m.ConfiguredClockSpeed
                if ($s -le 0) { $s = [int]$m.Speed }
                if ($s -gt $spd) { $spd = $s }
            }
            $t = ''
            switch ([int]$mods[0].SMBIOSMemoryType) { 24 { $t = 'DDR3' } 26 { $t = 'DDR4' } 34 { $t = 'DDR5' } default { $t = '' } }
            $script:HW.Ram = @{ TotalGB = [math]::Round($sum / 1GB, 0); Speed = $spd; Modules = $mods.Count; Type = $t }
        }
    } catch { $script:HW.Errors += ('CPU/RAM: ' + $_.Exception.Message) }
}

function Detect-Net {
    try {
        $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
        $script:HW.Nics = $nics
        $primary = $null
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
        if ($route) { $primary = $nics | Where-Object { $_.ifIndex -eq $route.InterfaceIndex } | Select-Object -First 1 }
        if (-not $primary -and $nics.Count -gt 0) { $primary = $nics[0] }
        if ($primary) {
            $kind = 'ETH'
            if (([string]$primary.PhysicalMediaType -match '802\.11|Wireless') -or ($primary.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN|WiFi')) { $kind = 'WIFI' }
            $script:HW.Net = @{ Name = [string]$primary.Name; Desc = [string]$primary.InterfaceDescription; Kind = $kind; Link = [string]$primary.LinkSpeed; Index = [int]$primary.ifIndex; Guid = [string]$primary.InterfaceGuid }
        }
    } catch { $script:HW.Errors += ('Rede: ' + $_.Exception.Message) }
}

function Detect-Display {
    try {
        $cur = [FnoNative]::CurrentMode()
        if ($cur) {
            $script:HW.Display.W = [int]$cur[0]; $script:HW.Display.H = [int]$cur[1]; $script:HW.Display.Hz = [int]$cur[2]
            $max = 0; $maxAny = 0
            foreach ($m in [FnoNative]::AllModes()) {
                if ($m -match '^(\d+)x(\d+)@(\d+)$') {
                    $hz = [int]$Matches[3]
                    if ($hz -gt $maxAny) { $maxAny = $hz }
                    if ([int]$Matches[1] -eq [int]$cur[0] -and [int]$Matches[2] -eq [int]$cur[1] -and $hz -gt $max) { $max = $hz }
                }
            }
            $script:HW.Display.MaxHz = $max; $script:HW.Display.MaxHzAny = $maxAny
        }
    } catch { $script:HW.Errors += ('Tela: ' + $_.Exception.Message) }
}

function Find-Fortnite {
    $r = @{ Dir = $null; Exe = $null; ConfigDir = $null; Ini = $null; EngineIni = $null }
    $rel = 'FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'
    $cands = @()
    try {
        $dat = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
        if (Test-Path -LiteralPath $dat) {
            $j = Get-Content -LiteralPath $dat -Raw | ConvertFrom-Json
            $e = @($j.InstallationList | Where-Object { $_.AppName -eq 'Fortnite' })
            if ($e.Count -gt 0 -and $e[0].InstallLocation) { $cands += [string]$e[0].InstallLocation }
        }
    } catch { }
    try {
        foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            $cands += (Join-Path $d.Root 'Epic Games\Fortnite')
            $cands += (Join-Path $d.Root 'Program Files\Epic Games\Fortnite')
        }
    } catch { }
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c $rel))) { $r.Dir = $c; $r.Exe = (Join-Path $c $rel); break }
    }
    $cfg = Join-Path $env:LOCALAPPDATA 'FortniteGame\Saved\Config\WindowsClient'
    $r.ConfigDir = $cfg
    $r.Ini = Join-Path $cfg 'GameUserSettings.ini'
    $r.EngineIni = Join-Path $cfg 'Engine.ini'
    return $r
}
function Detect-Fortnite {
    try { $script:HW.Fn = Find-Fortnite } catch { $script:HW.Errors += ('Fortnite: ' + $_.Exception.Message) }
}

# ---------------------------------------------------------------------
#  Perguntas sobre o hardware (usadas pelos menus/tweaks)
# ---------------------------------------------------------------------
function Test-Tag {
    param([string]$Tag)
    $hw = $script:HW
    switch ($Tag) {
        'ALL'      { return $true }
        'NV'       { return $hw.HasNvidia }
        'AMD'      { return $hw.HasAmd }
        'INTELGPU' { return $hw.HasIntelGpu }
        'INTEL'    { return ($hw.Cpu.Vendor -eq 'INTEL') }
        'RYZEN'    { return ($hw.Cpu.Vendor -eq 'AMD') }
        'X3D'      { return $hw.Cpu.IsX3D }
        'WIFI'     { return ($hw.Net.Kind -eq 'WIFI') }
        'ETH'      { return ($hw.Net.Kind -eq 'ETH') }
        'LAPTOP'   { return $hw.Laptop }
        'DESKTOP'  { return (-not $hw.Laptop) }
        'WIN11'    { return $hw.Os.IsWin11 }
        default    { return $true }
    }
}
function Test-Applicable {
    param($Tags)
    foreach ($t in @($Tags)) { if (Test-Tag $t) { return $true } }
    return $false
}
function Get-GpuLabel {
    if ($script:HW.Gpu) { return ('{0} ({1})' -f $script:HW.Gpu.Name, $script:HW.Gpu.Vendor) }
    return (L 'GPU nao detectada')
}
function Get-HwSummaryLine {
    $g = 'GPU: ?'
    if ($script:HW.Gpu) { $g = 'GPU: ' + ($script:HW.Gpu.Name -replace 'NVIDIA |AMD |Intel\(R\) ', '') + ' [' + $script:HW.Gpu.Vendor + ']' }
    $c = 'CPU: ' + ($script:HW.Cpu.Name -replace '\(R\)|\(TM\)|CPU|Processor|@.*$', '').Trim() + ' [' + $script:HW.Cpu.Vendor + ']'
    $n = (L 'Rede') + ': ' + $script:HW.Net.Kind
    return ($g + '  |  ' + $c + '  |  ' + $n)
}

function Detect-All {
    Detect-Os; Detect-Gpu; Detect-Cpu; Detect-Net; Detect-Display; Detect-Fortnite
}

# =====================================================================
#  UI: menus com setas, confirmacao Sim/Nao, pager de texto
#  Modos: teclado real (cursor) | linear (saida redirecionada, testes)
#         | numerico (entrada redirecionada)
# =====================================================================
$script:KeyQueue = New-Object System.Collections.Queue
$script:AutoActive = $false
$script:CanCursor = $true
try { $null = [Console]::CursorTop } catch { $script:CanCursor = $false }
$script:UseKeys = $true
$script:SnapN = 0

function Initialize-Ui {
    if ($AutoKeys) {
        $script:AutoActive = $true
        foreach ($tok in ($AutoKeys -split ',')) { $t = $tok.Trim(); if ($t) { $script:KeyQueue.Enqueue($t) } }
    }
    $script:UseKeys = ($script:AutoActive -or -not [Console]::IsInputRedirected)
    if ($script:CanCursor) {
        try {
            $raw = $Host.UI.RawUI
            $ws = $raw.WindowSize
            if ($ws.Width -lt 110 -or $ws.Height -lt 42) {
                $bw = [Math]::Max($raw.BufferSize.Width, 120)
                $bh = [Math]::Max($raw.BufferSize.Height, 3000)
                $raw.BufferSize = New-Object System.Management.Automation.Host.Size($bw, $bh)
                $nw = [Math]::Min([Math]::Max($ws.Width, 120), $raw.MaxPhysicalWindowSize.Width)
                $nh = [Math]::Min([Math]::Max($ws.Height, 44), $raw.MaxPhysicalWindowSize.Height)
                $raw.WindowSize = New-Object System.Management.Automation.Host.Size($nw, $nh)
            }
            $raw.BackgroundColor = 'Black'
        } catch { }
    }
    Initialize-Glyphs
    Set-UiTitle
}
function Set-UiTitle {
    try { $Host.UI.RawUI.WindowTitle = ('{0} v{1}  -  Made by: {2}  |  Discord: {3}' -f (L 'FORTNITE OTIMIZADOR'), $script:Version, $script:CreditBy, $script:CreditDiscord) } catch { }
}

function ConvertTo-KeyInfo {
    param([string]$Tok)
    $map = @{
        'up' = @([ConsoleKey]::UpArrow, [char]0); 'down' = @([ConsoleKey]::DownArrow, [char]0)
        'left' = @([ConsoleKey]::LeftArrow, [char]0); 'right' = @([ConsoleKey]::RightArrow, [char]0)
        'home' = @([ConsoleKey]::Home, [char]0); 'end' = @([ConsoleKey]::End, [char]0)
        'pgup' = @([ConsoleKey]::PageUp, [char]0); 'pgdn' = @([ConsoleKey]::PageDown, [char]0)
        'enter' = @([ConsoleKey]::Enter, [char]13); 'esc' = @([ConsoleKey]::Escape, [char]27)
        'tab' = @([ConsoleKey]::Tab, [char]9); 'space' = @([ConsoleKey]::Spacebar, [char]32)
        'bksp' = @([ConsoleKey]::Backspace, [char]8)
    }
    $l = $Tok.ToLower()
    if ($map.ContainsKey($l)) { return (New-Object System.ConsoleKeyInfo($map[$l][1], $map[$l][0], $false, $false, $false)) }
    $c = $Tok[0]
    if ([char]::IsDigit($c)) { $key = [ConsoleKey]([int][ConsoleKey]::D0 + [int]([string]$c)) }
    else { $key = [ConsoleKey]::Parse([ConsoleKey], ([string]$c).ToUpper()) }
    return (New-Object System.ConsoleKeyInfo($c, $key, $false, $false, $false))
}

function Read-Key {
    if ($script:AutoActive) {
        while ($true) {
            if ($script:KeyQueue.Count -eq 0) {
                if ($ScreenDump -and $script:SnapN -eq 0) { Save-ScreenDump }
                throw 'AUTOKEYS_DONE'
            }
            $tok = [string]$script:KeyQueue.Dequeue()
            if ($tok -match '^wait:(\d+)$') { Start-Sleep -Seconds ([int]$Matches[1]); continue }
            if ($tok -eq 'snap') { Save-ScreenDump; continue }
            return (ConvertTo-KeyInfo $tok)
        }
    }
    return [Console]::ReadKey($true)
}

# Captura a janela REAL do console (caracteres + cores) em HTML.
# So para desenvolvimento: -AutoKeys "...,snap,..." -ScreenDump caminho
function Save-ScreenDump {
    if (-not $ScreenDump) { return }
    $script:SnapN++
    try {
        $raw = $Host.UI.RawUI
        $wp = $raw.WindowPosition
        $ws = $raw.WindowSize
        $rect = New-Object System.Management.Automation.Host.Rectangle($wp.X, $wp.Y, ($wp.X + $ws.Width - 1), ($wp.Y + $ws.Height - 1))
        $buf = $raw.GetBufferContents($rect)
        $pal = @{ Black = '#0C0C0C'; DarkBlue = '#0037DA'; DarkGreen = '#13A10E'; DarkCyan = '#3A96DD'; DarkRed = '#C50F1F'; DarkMagenta = '#881798'; DarkYellow = '#C19C00'; Gray = '#CCCCCC'
            DarkGray = '#767676'; Blue = '#3B78FF'; Green = '#16C60C'; Cyan = '#61D6D6'; Red = '#E74856'; Magenta = '#B4009E'; Yellow = '#F9F1A5'; White = '#F2F2F2' }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('<html><head><meta charset="utf-8"><style>body{background:#0C0C0C;margin:6px}pre{font:15px/15px Consolas,monospace;margin:0}</style></head><body><pre>')
        for ($y = 0; $y -lt $buf.GetLength(0); $y++) {
            $cur = ''; $run = New-Object System.Text.StringBuilder
            for ($x = 0; $x -lt $buf.GetLength(1); $x++) {
                $cell = $buf[$y, $x]
                $st = 'color:' + $pal[[string]$cell.ForegroundColor] + ';background:' + $pal[[string]$cell.BackgroundColor]
                if ($st -ne $cur) {
                    if ($run.Length) { [void]$sb.Append('<span style="' + $cur + '">' + $run.ToString() + '</span>'); [void]$run.Clear() }
                    $cur = $st
                }
                $ch = [string]$cell.Character
                if ($ch -eq '<') { $ch = '&lt;' } elseif ($ch -eq '>') { $ch = '&gt;' } elseif ($ch -eq '&') { $ch = '&amp;' } elseif ([int][char]$cell.Character -eq 0) { $ch = ' ' }
                [void]$run.Append($ch)
            }
            if ($run.Length) { [void]$sb.Append('<span style="' + $cur + '">' + $run.ToString() + '</span>') }
            [void]$sb.Append("`n")
        }
        [void]$sb.Append('</pre></body></html>')
        [IO.File]::WriteAllText(($ScreenDump + '_' + $script:SnapN + '.html'), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function Get-UiWidth {
    $w = 100
    try { $w = $Host.UI.RawUI.WindowSize.Width - 1 } catch { }
    return [Math]::Min([Math]::Max($w, 60), 118)
}
function Get-UiHeight {
    $h = 40
    try { $h = $Host.UI.RawUI.WindowSize.Height } catch { }
    return [Math]::Max($h, 24)
}
function Clear-Screen { try { Clear-Host } catch { } }
function Clear-Ui {
    if ($script:CanCursor) { Clear-Screen } else { Say ('-' * 60) 'DarkGray' }
}
function Set-Cur {
    param([int]$X, [int]$Y)
    try { [Console]::SetCursorPosition($X, $Y) } catch { }
}
function Fit {
    param([string]$T, [int]$W)
    if ($null -eq $T) { $T = '' }
    if ($W -le 0) { return '' }
    if ($T.Length -gt $W) { return $T.Substring(0, [Math]::Max(0, $W - 1)) + '~' }
    return $T.PadRight($W)
}

# ---------------------------------------------------------------------
#  Creditos (aparecem na borda de toda tela)
# ---------------------------------------------------------------------
$script:CreditBy = 'Lina'
$script:CreditDiscord = 'kali_linax'
function Get-CreditSegs {
    return @(
        @{ T = ' Made by: '; F = 'Magenta' }, @{ T = $script:CreditBy; F = 'Yellow' },
        @{ T = (' ' + $script:G.SV + ' '); F = 'DarkGray' },
        @{ T = 'Discord: '; F = 'Cyan' }, @{ T = $script:CreditDiscord; F = 'Green' }, @{ T = ' '; F = 'Gray' })
}
function Write-Credits {
    param([int]$W)
    $segs = New-Object System.Collections.ArrayList
    $c = @(Get-CreditSegs)
    $len = (Get-SegWidth $c) + 4
    Add-Seg $segs (' ' * [Math]::Max(0, [int](($W - $len) / 2)))
    Add-Seg $segs ($script:G.Dia + ' ') 'DarkYellow'
    foreach ($s in $c) { Add-Seg $segs $s.T $s.F }
    Add-Seg $segs (' ' + $script:G.Dia) 'DarkYellow'
    Write-SegLine $segs $W
}

# Moldura de cabecalho:
#  +==[ FORTNITE OTIMIZADOR v2.1 ]=========[ Made by: Lina | Discord: kali_linax ]==+
#  | > TITULO                                                         [MODO TESTE] |
#  |   subtitulo                                                                   |
#  +==============================================================================+
function Write-HeaderFrame {
    param([int]$W, [string]$Title, [string]$Sub = '')
    $g = $script:G
    $fc = 'DarkCyan'
    $n = 0
    $Title = L $Title
    $Sub = L $Sub
    $cred = @(Get-CreditSegs)
    $credW = Get-SegWidth $cred
    $brand = @(@{ T = (' ' + (L 'FORTNITE OTIMIZADOR') + ' '); F = 'White' }, @{ T = ('v' + $script:Version + ' '); F = 'Yellow' })
    $brandW = Get-SegWidth $brand
    $top = New-Object System.Collections.ArrayList
    $fill = $W - 10 - $brandW - $credW
    $credOnTop = $true
    if ($fill -ge 2) {
        Add-Seg $top ($g.DTL + $g.DH + $g.DH + $g.LabL) $fc
        foreach ($s in $brand) { Add-Seg $top $s.T $s.F }
        Add-Seg $top ($g.LabR + ($g.DH * $fill) + $g.LabL) $fc
    } elseif (($W - 6 - $credW) -ge 1) {
        Add-Seg $top ($g.DTL + ($g.DH * ($W - 6 - $credW)) + $g.LabL) $fc
    } else { $credOnTop = $false }
    if ($credOnTop) {
        foreach ($s in $cred) { Add-Seg $top $s.T $s.F }
        Add-Seg $top ($g.LabR + $g.DH + $g.DH + $g.DTR) $fc
    } else {
        Add-Seg $top ($g.DTL + ($g.DH * ($W - 2)) + $g.DTR) $fc
    }
    Write-SegLine $top; $n++
    # titulo
    $tag = ''
    if ($script:Dry -and $env:FNO_SHOT -ne '1') { $tag = (L '[MODO TESTE - nada e gravado]') + ' ' }
    $tw = $W - 5 - $tag.Length - 1
    Write-Host $g.DV -NoNewline -ForegroundColor $fc
    Write-Host (' ' + $g.Ptr + ' ') -NoNewline -ForegroundColor Magenta
    Write-Host (Fit $Title $tw) -NoNewline -ForegroundColor Yellow
    Write-Host $tag -NoNewline -ForegroundColor DarkYellow
    Write-Host $g.DV -ForegroundColor $fc
    $n++
    if ($Sub) {
        Write-Host $g.DV -NoNewline -ForegroundColor $fc
        Write-Host ('   ' + (Fit $Sub ($W - 5))) -NoNewline -ForegroundColor Gray
        Write-Host $g.DV -ForegroundColor $fc
        $n++
    }
    Write-Host ($g.DBL + ($g.DH * ($W - 2)) + $g.DBR) -ForegroundColor $fc
    $n++
    if (-not $credOnTop) { Write-Credits $W; $n++ }
    return $n
}

function Show-Banner {
    param([string]$Title, [string]$Sub = '', [string]$Art = '')
    $w = Get-UiWidth
    $a = Get-ArtBlock $Art $w
    if ($a) { [void](Write-Block $a) }
    [void](Write-HeaderFrame $w $Title $Sub)
}

# ---------------------------------------------------------------------
#  Badges (etiquetas coloridas)
# ---------------------------------------------------------------------
function New-Badge { param([string]$T, [string]$C = 'Gray') @{ T = $T; C = $C } }
function Get-TagBadges {
    param($Tags)
    $b = @()
    foreach ($t in @($Tags)) {
        switch ($t) {
            'ALL'      { $b += New-Badge '[TODOS]' 'Gray' }
            'NV'       { $b += New-Badge '[NVIDIA]' 'Green' }
            'AMD'      { $b += New-Badge '[AMD GPU]' 'Red' }
            'INTELGPU' { $b += New-Badge '[INTEL GPU]' 'Blue' }
            'INTEL'    { $b += New-Badge '[INTEL CPU]' 'Blue' }
            'RYZEN'    { $b += New-Badge '[RYZEN]' 'Red' }
            'X3D'      { $b += New-Badge '[X3D]' 'Red' }
            'WIFI'     { $b += New-Badge '[WI-FI]' 'Magenta' }
            'ETH'      { $b += New-Badge '[CABO]' 'Magenta' }
            'LAPTOP'   { $b += New-Badge '[NOTEBOOK]' 'Yellow' }
            'DESKTOP'  { $b += New-Badge '[DESKTOP]' 'Gray' }
            'WIN11'    { $b += New-Badge '[WIN11]' 'Gray' }
        }
    }
    return $b
}

# ---------------------------------------------------------------------
#  MENU com setas
#  Items: hashtables { Label; Desc; Badges; State; Na; Header }
#  Retorna o indice escolhido ou -1 (Esc)
# ---------------------------------------------------------------------
function Get-NextSel {
    param($Items, [int]$From, [int]$Dir)
    $n = $Items.Count
    if ($n -eq 0) { return 0 }
    $i = $From
    for ($c = 0; $c -lt $n; $c++) {
        if ($i -lt 0) { $i = $n - 1 }
        if ($i -ge $n) { $i = 0 }
        if (-not $Items[$i].Header) { return $i }
        $i += $Dir
    }
    return $From
}
function Get-HeaderLabel { param([string]$L) return ($L.Trim().Trim('=').Trim()) }
function Write-ListHeader {
    param([string]$Label, [int]$W)
    $g = $script:G
    $lab = Fit (Get-HeaderLabel $Label) ($W - 8)
    $lab = $lab.TrimEnd()
    Write-Host (' ' + $g.SH + $g.SH + ' ') -NoNewline -ForegroundColor DarkYellow
    Write-Host $lab -NoNewline -ForegroundColor Yellow
    Write-Host (' ' + ($g.SH * [Math]::Max(0, $W - 6 - $lab.Length))) -ForegroundColor DarkYellow
}
function Write-KeyHints {
    param([string]$Text, [int]$W)
    $segs = New-Object System.Collections.ArrayList
    Add-Seg $segs ' '
    $Text = L $Text
    foreach ($p in ($Text -split '\|')) {
        $kv = $p.Trim() -split ':', 2
        if ($kv.Count -eq 2) {
            $k = $kv[0].Trim()
            if (($k -eq 'Setas' -or $k -eq 'Arrows') -and $script:Fancy) { $k = $script:G.ArU + $script:G.ArD }
            Add-Seg $segs (' ' + $k + ' ') 'Black' 'DarkCyan'
            Add-Seg $segs (' ' + $kv[1].Trim() + '   ') 'Gray'
        } else { Add-Seg $segs ($p.Trim() + '   ') 'Gray' }
    }
    if ((Get-SegWidth $segs) -gt $W) { Say (Fit (' ' + $Text) $W) 'DarkGray'; return }
    Write-SegLine $segs $W
}

function Show-Menu {
    param([string]$Title, [string]$Sub = '', $Items, [int]$Selected = 0, [string]$Foot = '', [string]$Art = '')
    $items = @(foreach ($it0 in @($Items)) { Get-LocItem $it0 })
    $n = $items.Count
    if ($n -eq 0) { return -1 }
    $g = $script:G
    # numeracao dos itens selecionaveis
    $numOf = @{}
    $byNum = @{}
    $k = 0
    for ($i = 0; $i -lt $n; $i++) { if (-not $items[$i].Header) { $k++; $numOf[$i] = $k; $byNum[$k] = $i } }

    # --- modo numerico (entrada redirecionada) ---
    if (-not $script:UseKeys) {
        Clear-Ui
        Show-Banner $Title $Sub
        for ($i = 0; $i -lt $n; $i++) {
            if ($items[$i].Header) { Say (' -- ' + (Get-HeaderLabel $items[$i].Label) + ' --') 'Yellow' } else { Say ('  {0,2}) {1}' -f $numOf[$i], $items[$i].Label) 'Gray' }
        }
        $ans = Read-Host (L '  Numero (vazio = voltar)')
        if (-not $ans) { return -1 }
        $v = 0
        if ([int]::TryParse($ans, [ref]$v) -and $byNum.ContainsKey($v)) { return $byNum[$v] }
        return -1
    }

    $sel = Get-NextSel $items ([Math]::Min([Math]::Max($Selected, 0), $n - 1)) 1
    $off = 0
    $numBuf = ''
    $numClock = [Diagnostics.Stopwatch]::StartNew()
    $lastW = -1; $lastH = -1
    $first = $true
    $bodyTop = 0
    $hid = $false
    if ($script:CanCursor) { try { [Console]::CursorVisible = $false; $hid = $true } catch { } }
    try {
        while ($true) {
            $w = Get-UiWidth
            $h = Get-UiHeight
            $descH = 4
            if ($h -ge 40) { $descH = 6 }
            $detailH = $descH + 3
            $frameH = 3
            if ($Sub) { $frameH = 4 }
            # arte grande se couber; senao a compacta; senao nenhuma
            $maxArt = $h - $frameH - 1 - $detailH - 2 - [Math]::Min($n, 12)
            $artBlk = Get-ArtBlock $Art $w $maxArt
            $artH = 0
            if ($artBlk) { $artH = $artBlk.Lines.Count }
            $rows = [Math]::Max(4, $h - $artH - $frameH - 1 - $detailH - 2)
            if ($rows -gt $n) { $rows = $n }
            if ($sel -lt $off) { $off = $sel }
            if ($sel -ge ($off + $rows)) { $off = $sel - $rows + 1 }
            if ($off -lt 0) { $off = 0 }
            # se o item acima do selecionado for um cabecalho, mostra ele junto
            if ($off -gt 0 -and $off -eq $sel -and $items[$off - 1].Header) { $off-- }

            $drawHead = $true
            if ($script:CanCursor) {
                if ($first -or $w -ne $lastW -or $h -ne $lastH) { Clear-Screen; $first = $false }
                elseif ($bodyTop -gt 0) { $drawHead = $false }
                $lastW = $w; $lastH = $h
                if ($drawHead) { Set-Cur 0 0 } else { Set-Cur 0 $bodyTop }
            } else {
                Say ('-' * 60) 'DarkGray'
            }

            # cabecalho (arte + moldura com creditos) - so redesenha quando precisa
            if ($drawHead) {
                $hl = 0
                if ($artBlk) { $hl += (Write-Block $artBlk $w) }
                $hl += (Write-HeaderFrame $w $Title $Sub)
                $bodyTop = $hl
            }

            # lista
            for ($r = 0; $r -lt $rows; $r++) {
                $i = $off + $r
                if ($i -ge $n) { Say (Fit '' $w) 'Gray'; continue }
                $it = $items[$i]
                if ($it.Header) { Write-ListHeader $it.Label $w; continue }
                $isSel = ($i -eq $sel)
                $ptr = '   '
                if ($isSel) { $ptr = ' ' + $g.Ptr + ' ' }
                $st = '     '
                if ($it.State -eq 'ON') { $st = '[ON ]' } elseif ($it.State -eq 'OFF') { $st = '[OFF]' } elseif ($it.State -eq 'NA') { $st = '[ - ]' }
                $num = ('{0,2}. ' -f $numOf[$i])
                $bt = ''
                foreach ($b in @($it.Badges)) { $bt = $bt + ' ' + $b.T }
                $labMax = $w - 3 - 5 - 1 - 4 - $bt.Length - 1
                if ($labMax -lt 12) { $bt = ''; $labMax = $w - 3 - 5 - 1 - 4 - 1 }
                $lab = Fit $it.Label $labMax
                if ($isSel) {
                    Write-Host $ptr -NoNewline -ForegroundColor DarkBlue -BackgroundColor Cyan
                    Write-Host (Fit ($st + ' ' + $num + $lab + $bt) ($w - 3)) -ForegroundColor Black -BackgroundColor Cyan
                } else {
                    $fg = 'Gray'
                    if ($it.Na) { $fg = 'DarkGray' }
                    Write-Host $ptr -NoNewline
                    $stc = 'DarkGray'
                    if ($it.State -eq 'ON') { $stc = 'Green' } elseif ($it.State -eq 'OFF') { $stc = 'DarkYellow' }
                    Write-Host $st -NoNewline -ForegroundColor $stc
                    Write-Host (' ' + $num) -NoNewline -ForegroundColor DarkGray
                    Write-Host $lab -NoNewline -ForegroundColor $fg
                    $used = $ptr.Length + $st.Length + 1 + $num.Length + $lab.Length
                    if ($bt) {
                        foreach ($b in @($it.Badges)) {
                            $c = $b.C
                            if ($it.Na) { $c = 'DarkGray' }
                            Write-Host (' ' + $b.T) -NoNewline -ForegroundColor $c
                            $used += 1 + $b.T.Length
                        }
                    }
                    Write-Host (' ' * [Math]::Max(0, $w - $used))
                }
            }
            # indicador de rolagem
            $more = ''
            if ($off -gt 0) { $more = $g.TriU + ' ' + (L 'mais acima') + '   ' }
            if (($off + $rows) -lt $n) { $more = $more + $g.TriD + ' ' + (L 'mais abaixo') }
            $pos = ''
            if ($byNum.Count -gt 0 -and $numOf.ContainsKey($sel)) { $pos = ((L 'item {0}/{1}') -f $numOf[$sel], $byNum.Count) }
            Say (Fit ('  ' + $more.PadRight(30) + $pos) $w) 'DarkGray'

            # detalhe do item selecionado (caixa)
            $cur = $items[$sel]
            $lab = Fit ([string]$cur.Label) ($w - 8)
            $lab = $lab.TrimEnd()
            Write-Host (' ' + $g.STL + $g.SH + ' ') -NoNewline -ForegroundColor DarkCyan
            Write-Host $lab -NoNewline -ForegroundColor White
            Write-Host (' ' + ($g.SH * [Math]::Max(0, $w - 6 - $lab.Length)) + $g.STR) -ForegroundColor DarkCyan
            Write-Host (' ' + $g.SV + ' ') -NoNewline -ForegroundColor DarkCyan
            $used = 3
            $bsrc = @($cur.Badges)
            if ($cur.DBadges) { $bsrc = @($cur.DBadges) }
            foreach ($b in $bsrc) {
                if (-not $b) { continue }
                if ($used + $b.T.Length + 1 -gt $w - 2) { break }
                Write-Host ($b.T + ' ') -NoNewline -ForegroundColor $b.C; $used += $b.T.Length + 1
            }
            if ($cur.Meta) {
                $mt = Fit ([string]$cur.Meta) ([Math]::Max(0, $w - 2 - $used))
                Write-Host $mt -NoNewline -ForegroundColor DarkCyan; $used += $mt.Length
            }
            Write-Host (' ' * [Math]::Max(0, $w - 1 - $used)) -NoNewline
            Write-Host $g.SV -ForegroundColor DarkCyan
            $wrapped = @(Wrap-Text ([string]$cur.Desc) ($w - 7))
            for ($d = 0; $d -lt $descH; $d++) {
                $txt = ''
                if ($d -lt $wrapped.Count) { $txt = $wrapped[$d] }
                if ($d -eq ($descH - 1) -and $wrapped.Count -gt $descH) { $txt = (Fit $txt ($w - 16)).TrimEnd() + ' (...)' }
                Write-Host (' ' + $g.SV + '  ') -NoNewline -ForegroundColor DarkCyan
                Write-Host (Fit $txt ($w - 5)) -NoNewline -ForegroundColor Gray
                Write-Host $g.SV -ForegroundColor DarkCyan
            }
            Write-Host (' ' + $g.SBL + ($g.SH * ($w - 3)) + $g.SBR) -ForegroundColor DarkCyan

            $hint = 'Setas: mover | Enter: escolher | Esc: voltar | 0-9: pular'
            if ($Foot) { $hint = $Foot }
            Write-KeyHints $hint $w

            # teclado
            $key = Read-Key
            switch ($key.Key) {
                'UpArrow'   { $sel = Get-NextSel $items ($sel - 1) -1; $numBuf = '' }
                'DownArrow' { $sel = Get-NextSel $items ($sel + 1) 1; $numBuf = '' }
                'Home'      { $sel = Get-NextSel $items 0 1; $numBuf = '' }
                'End'       { $sel = Get-NextSel $items ($n - 1) -1; $numBuf = '' }
                'PageUp'    { $sel = Get-NextSel $items ([Math]::Max(0, $sel - $rows)) 1; $numBuf = '' }
                'PageDown'  { $sel = Get-NextSel $items ([Math]::Min($n - 1, $sel + $rows)) -1; $numBuf = '' }
                'Enter'     { return $sel }
                'Escape'    { return -1 }
                'Backspace' { return -1 }
                default {
                    $ch = $key.KeyChar
                    if ([char]::IsDigit($ch)) {
                        if ($numClock.ElapsedMilliseconds -gt 900) { $numBuf = '' }
                        $numClock.Reset(); $numClock.Start()
                        $try = $numBuf + [string]$ch
                        $v = [int]$try
                        if ($byNum.ContainsKey($v)) { $numBuf = $try; $sel = $byNum[$v] }
                        else {
                            $v2 = [int][string]$ch
                            if ($byNum.ContainsKey($v2)) { $numBuf = [string]$ch; $sel = $byNum[$v2] } else { $numBuf = '' }
                        }
                    } elseif ($ch -eq 'q' -or $ch -eq 'Q') { return -1 }
                }
            }
        }
    } finally {
        if ($hid) { try { [Console]::CursorVisible = $true } catch { } }
    }
}

# Copia do item com textos traduzidos (o original nao muda)
function Get-LocItem {
    param($It)
    if ($script:UiLang -ne 'en' -or -not ($It -is [hashtable])) { return $It }
    $c = $It.Clone()
    if ($It.Label) { $c.Label = L ([string]$It.Label) }
    if ($It.Desc) { $c.Desc = L ([string]$It.Desc) }
    if ($It.Meta) { $c.Meta = L ([string]$It.Meta) }
    foreach ($bk in @('Badges', 'DBadges')) {
        if ($It[$bk]) { $c[$bk] = @(foreach ($b in @($It[$bk])) { if ($b) { @{ T = (L ([string]$b.T)); C = $b.C } } }) }
    }
    return $c
}

# Atalho: menu simples so com rotulos. Retorna indice ou -1.
function Select-Option {
    param([string]$Title, [string[]]$Options, [string[]]$Descs = @(), [int]$Selected = 0, [string]$Sub = '', [string]$Art = '')
    $items = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $d = ''
        if ($i -lt $Descs.Count) { $d = $Descs[$i] }
        $items += @{ Label = $Options[$i]; Desc = $d; Badges = @() }
    }
    return (Show-Menu -Title $Title -Sub $Sub -Items $items -Selected $Selected -Art $Art)
}

# ---------------------------------------------------------------------
#  Confirmacao Sim/Nao com setas
# ---------------------------------------------------------------------
function Confirm-Action {
    param([string]$Msg, [bool]$Default = $false, [string]$Color = 'Yellow')
    $w = Get-UiWidth
    $g = $script:G
    Say ''
    $first = $true
    $Msg = L $Msg
    $yT = ' SIM '; $nT = ' NAO '
    if ($script:UiLang -eq 'en') { $yT = ' YES '; $nT = ' NO  ' }
    foreach ($l in (Wrap-Text $Msg ($w - 8))) {
        if ($first) { Write-Host ('  ' + $g.Dia + ' ') -NoNewline -ForegroundColor Magenta; $first = $false } else { Write-Host '    ' -NoNewline }
        Write-Out $l $Color
    }
    if (-not $script:UseKeys) {
        $a = Read-Host (L '  (S/N)')
        return ($a -match '^[sSyY]')
    }
    $yes = $Default
    $row = -1
    if ($script:CanCursor) { try { $row = [Console]::CursorTop } catch { $row = -1 } }
    $hid = $false
    if ($script:CanCursor) { try { [Console]::CursorVisible = $false; $hid = $true } catch { } }
    try {
        while ($true) {
            if ($row -ge 0) { Set-Cur 0 $row }
            Write-Host '    ' -NoNewline
            if ($yes) {
                Write-Host (' ' + $g.Ptr + $yT) -NoNewline -ForegroundColor Black -BackgroundColor Green
                Write-Host '   ' -NoNewline
                Write-Host ('  ' + $nT) -NoNewline -ForegroundColor DarkGray -BackgroundColor Black
            } else {
                Write-Host ('  ' + $yT) -NoNewline -ForegroundColor DarkGray -BackgroundColor Black
                Write-Host '   ' -NoNewline
                Write-Host (' ' + $g.Ptr + $nT) -NoNewline -ForegroundColor White -BackgroundColor Red
            }
            Write-Host ('     ' + (L 'setas/Tab alternam  |  Enter confirma  |  S / N') + '   ') -NoNewline -ForegroundColor DarkGray
            if ($row -lt 0) { Write-Host '' }
            $k = Read-Key
            switch ($k.Key) {
                'LeftArrow'  { $yes = -not $yes }
                'RightArrow' { $yes = -not $yes }
                'UpArrow'    { $yes = -not $yes }
                'DownArrow'  { $yes = -not $yes }
                'Tab'        { $yes = -not $yes }
                'Enter'      { if ($row -ge 0) { Write-Host '' }; return $yes }
                'Escape'     { if ($row -ge 0) { Write-Host '' }; return $false }
                default {
                    $c = ([string]$k.KeyChar).ToLower()
                    if ($c -eq 's' -or $c -eq 'y') { if ($row -ge 0) { Write-Host '' }; return $true }
                    if ($c -eq 'n') { if ($row -ge 0) { Write-Host '' }; return $false }
                }
            }
        }
    } finally {
        if ($hid) { try { [Console]::CursorVisible = $true } catch { } }
    }
}

function Pause-Key {
    param([string]$Msg = 'Pressione qualquer tecla para continuar...')
    $Msg = L $Msg
    Say ''
    Write-Host ('  ' + $script:G.Ptr + ' ') -NoNewline -ForegroundColor Magenta
    Write-Out $Msg 'DarkGray'
    if (-not $script:UseKeys) { [void](Read-Host); return }
    [void](Read-Key)
}

# ---------------------------------------------------------------------
#  Pager de texto (guias). Linhas com prefixo: '#' titulo, '!' aviso,
#  '+' ok/bom, '~' nota, resto normal.
# ---------------------------------------------------------------------
function Get-TextLineStyle {
    param([string]$L)
    $g = $script:G
    if ($L.StartsWith('#')) { return @((($g.Sq + ' ') + $L.Substring(1).Trim()), 'Yellow') }
    if ($L.StartsWith('!')) { return @((('  ' + $g.TriU + ' ') + $L.Substring(1).Trim()), 'Red') }
    if ($L.StartsWith('+')) { return @((('  ' + $g.Chk + ' ') + $L.Substring(1).Trim()), 'Green') }
    if ($L.StartsWith('~')) { return @((('  ' + $g.Dot + ' ') + $L.Substring(1).Trim()), 'DarkCyan') }
    return @(('  ' + $L), 'Gray')
}
function Show-Text {
    param([string]$Title, [string[]]$Lines)
    $w = Get-UiWidth
    $all = @()
    $Title = L $Title
    foreach ($l0 in $Lines) {
        $l = L $l0
        $st = Get-TextLineStyle $l
        $wr = @(Wrap-Text $st[0] ($w - 3))
        if ($wr.Count -eq 0) { $wr = @('') }
        for ($i = 0; $i -lt $wr.Count; $i++) {
            $txt = $wr[$i]
            if ($i -gt 0 -and $l.Length -gt 0 -and $l[0] -match '[!+~]') { $txt = '    ' + $txt }
            $all += , @($txt, $st[1])
        }
    }
    if (-not $script:CanCursor -or -not $script:UseKeys) {
        Show-Banner $Title
        foreach ($x in $all) { Write-Out $x[0] $x[1] }
        Pause-Key
        return
    }
    $top = 0
    $first = $true
    $hid = $false
    try { [Console]::CursorVisible = $false; $hid = $true } catch { }
    try {
        while ($true) {
            $w = Get-UiWidth
            $h = Get-UiHeight
            $page = [Math]::Max(5, $h - 6)
            $maxTop = [Math]::Max(0, $all.Count - $page)
            if ($top -gt $maxTop) { $top = $maxTop }
            if ($top -lt 0) { $top = 0 }
            if ($first) { Clear-Screen; $first = $false }
            Set-Cur 0 0
            [void](Write-HeaderFrame $w $Title '')
            for ($r = 0; $r -lt $page; $r++) {
                $i = $top + $r
                if ($i -lt $all.Count) { Write-Out (Fit $all[$i][0] $w) $all[$i][1] } else { Write-Out (Fit '' $w) 'Gray' }
            }
            $pos = ''
            if ($all.Count -gt $page) { $pos = (' | [{0}-{1}/{2}]' -f ($top + 1), [Math]::Min($all.Count, $top + $page), $all.Count) }
            Write-KeyHints ((L 'Setas: rolar | PgUp/PgDn: pagina | Esc: voltar') + $pos) $w
            $k = Read-Key
            switch ($k.Key) {
                'UpArrow'   { $top-- }
                'DownArrow' { $top++ }
                'PageUp'    { $top -= $page }
                'PageDown'  { $top += $page }
                'Home'      { $top = 0 }
                'End'       { $top = $maxTop }
                'Escape'    { return }
                'Enter'     { return }
                'Backspace' { return }
                default     { if (([string]$k.KeyChar).ToLower() -eq 'q') { return } }
            }
        }
    } finally {
        if ($hid) { try { [Console]::CursorVisible = $true } catch { } }
    }
}

# =====================================================================
#  ARTE
#  - Glifos Unicode criados em runtime ([char]0x....): o fonte continua
#    100% ASCII. So caracteres presentes no CP437/CP850 (renderizam em
#    Consolas, Lucida, fontes raster e no Windows Terminal).
#  - Letras grandes estilo "ANSI Shadow" GERADAS POR ALGORITMO: bitmap da
#    letra + contorno da sombra deslocada meia celula (nada desenhado a mao,
#    entao nao entorta).
#  - Sprites pixel-art: 2 pixels por celula com meio-bloco colorido.
#  - Saida redirecionada / FNO_ASCII=1 => tudo cai para ASCII puro.
# =====================================================================
$script:Fancy = $false
$script:G = @{}

function Initialize-Glyphs {
    param([switch]$Force, [switch]$Ascii)
    $f = [bool]$script:CanCursor
    try { if ([Console]::IsOutputRedirected) { $f = $false } } catch { $f = $false }
    if ($env:FNO_ASCII -eq '1') { $f = $false }
    if ($Force) { $f = $true }
    if ($Ascii) { $f = $false }
    $script:Fancy = $f
    if ($f) {
        $m = @{
            DTL = 0x2554; DTR = 0x2557; DBL = 0x255A; DBR = 0x255D; DH = 0x2550; DV = 0x2551; LabL = 0x2563; LabR = 0x2560
            STL = 0x250C; STR = 0x2510; SBL = 0x2514; SBR = 0x2518; SH = 0x2500; SV = 0x2502
            Full = 0x2588; Up = 0x2580; Dn = 0x2584; Sh1 = 0x2591; Sh2 = 0x2592; Sh3 = 0x2593
            Ptr = 0x25BA; Dot = 0x2022; ArU = 0x2191; ArD = 0x2193; TriU = 0x25B2; TriD = 0x25BC; Sq = 0x25A0; Chk = 0x221A; Dia = 0x2666
        }
        $g = @{}
        foreach ($k in $m.Keys) { $g[$k] = [string][char]$m[$k] }
        $script:G = $g
    } else {
        $script:G = @{
            DTL = '+'; DTR = '+'; DBL = '+'; DBR = '+'; DH = '='; DV = '|'; LabL = '['; LabR = ']'
            STL = '+'; STR = '+'; SBL = '+'; SBR = '+'; SH = '-'; SV = '|'
            Full = '#'; Up = '"'; Dn = '_'; Sh1 = '.'; Sh2 = ':'; Sh3 = '#'
            Ptr = '>'; Dot = '*'; ArU = '^'; ArD = 'v'; TriU = '^'; TriD = 'v'; Sq = '#'; Chk = 'v'; Dia = '*'
        }
    }
}

# ---------------------------------------------------------------------
#  Fonte grande (bitmaps de 5 linhas; '#' = bloco). A 6a linha e a sombra.
#  Bitmaps conferidos contra o ANSI Shadow.flf original (figlet).
# ---------------------------------------------------------------------
$script:BigFont = @{
    'A' = @(' #####', '##   ##', '#######', '##   ##', '##   ##')
    'B' = @('######', '##   ##', '######', '##   ##', '######')
    'C' = @(' ######', '##', '##', '##', ' ######')
    'D' = @('######', '##   ##', '##   ##', '##   ##', '######')
    'E' = @('#######', '##', '#####', '##', '#######')
    'F' = @('#######', '##', '#####', '##', '##')
    'G' = @(' ######', '##', '##  ###', '##   ##', ' ######')
    'H' = @('##   ##', '##   ##', '#######', '##   ##', '##   ##')
    'I' = @('##', '##', '##', '##', '##')
    'J' = @('     ##', '     ##', '     ##', '##   ##', ' #####')
    'K' = @('##   ##', '##  ##', '#####', '##  ##', '##   ##')
    'L' = @('##', '##', '##', '##', '#######')
    'M' = @('###    ###', '####  ####', '## #### ##', '##  ##  ##', '##      ##')
    'N' = @('###    ##', '####   ##', '## ##  ##', '##  ## ##', '##   ####')
    'O' = @(' ######', '##    ##', '##    ##', '##    ##', ' ######')
    'P' = @('######', '##   ##', '######', '##', '##')
    'R' = @('######', '##   ##', '######', '##   ##', '##   ##')
    'S' = @('#######', '##', '#######', '     ##', '#######')
    'T' = @('########', '   ##', '   ##', '   ##', '   ##')
    'U' = @('##    ##', '##    ##', '##    ##', '##    ##', ' ######')
    'V' = @('##    ##', '##    ##', '##    ##', ' ##  ##', '  ####')
    'W' = @('##     ##', '##     ##', '##  #  ##', '## ### ##', ' ### ###')
    'X' = @('##   ##', ' ## ##', '  ###', ' ## ##', '##   ##')
    'Y' = @('##    ##', ' ##  ##', '  ####', '   ##', '   ##')
    'Z' = @('#######', '   ###', '  ###', ' ###', '#######')
    '0' = @(' ######', '##  ####', '## ## ##', '####  ##', ' ######')
    '1' = @(' ##', '###', ' ##', ' ##', ' ##')
    '2' = @('######', '     ##', ' #####', '##', '#######')
    '.' = @('', '', '', '', '##')
    ' ' = @('  ', '  ', '  ', '  ', '  ')
}

function Get-BigBitmap {
    param([string]$Text)
    $rows = @('', '', '', '', '')
    $first = $true
    foreach ($ch in $Text.ToUpper().ToCharArray()) {
        $gl = $script:BigFont[[string]$ch]
        if (-not $gl) { continue }
        $gw = 0
        foreach ($r in $gl) { if ($r.Length -gt $gw) { $gw = $r.Length } }
        for ($i = 0; $i -lt 5; $i++) {
            if (-not $first) { $rows[$i] += ' ' }
            $rows[$i] += ([string]$gl[$i]).PadRight($gw)
        }
        $first = $false
    }
    return $rows
}

# Converte o bitmap em 6 linhas: '#' vira bloco e a sombra (bitmap deslocado
# meia celula p/ baixo-direita) vira contorno de linha dupla. Para cada celula
# vazia, olha os 4 quadrantes em volta do centro (pixels UL, UR, DL, DR) e liga
# um segmento onde o dentro/fora muda.
function ConvertTo-ShadowRows {
    param([string[]]$Bmp, [switch]$Plain)
    $H = $Bmp.Count
    $W = 0
    foreach ($r in $Bmp) { if ($r.Length -gt $W) { $W = $r.Length } }
    $grid = @()
    for ($r = 0; $r -lt $H; $r++) { $grid += , ([string]$Bmp[$r]).PadRight($W + 1) }
    $map = @{ 3 = 0x2550; 5 = 0x2554; 6 = 0x2557; 9 = 0x255A; 10 = 0x255D; 12 = 0x2551; 15 = 0x256C }
    $amap = @{ 3 = '='; 5 = '+'; 6 = '+'; 9 = '+'; 10 = '+'; 12 = '|'; 15 = '+' }
    $out = @()
    for ($r = 0; $r -le $H; $r++) {
        $sb = New-Object System.Text.StringBuilder
        for ($c = 0; $c -le $W; $c++) {
            $px = @(0, 0, 0, 0)
            $coords = @(@(($r - 1), ($c - 1)), @(($r - 1), $c), @($r, ($c - 1)), @($r, $c))
            for ($q = 0; $q -lt 4; $q++) {
                $pr = $coords[$q][0]; $pc = $coords[$q][1]
                if ($pr -ge 0 -and $pr -lt $H -and $pc -ge 0 -and $grid[$pr][$pc] -eq '#') { $px[$q] = 1 }
            }
            if ($px[3] -eq 1) { [void]$sb.Append('#'); continue }
            $k = 0
            if ($px[0] -ne $px[1]) { $k += 8 }
            if ($px[2] -ne $px[3]) { $k += 4 }
            if ($px[0] -ne $px[2]) { $k += 2 }
            if ($px[1] -ne $px[3]) { $k += 1 }
            if ($k -eq 0) { [void]$sb.Append(' ') }
            elseif ($Plain) { [void]$sb.Append($amap[$k]) }
            else { [void]$sb.Append([char]$map[$k]) }
        }
        $out += $sb.ToString().TrimEnd()
    }
    return $out
}

# ---------------------------------------------------------------------
#  Linhas segmentadas: cada linha = lista de @{T; F; B}
# ---------------------------------------------------------------------
function Add-Seg {
    param($List, [string]$T, $F = $null, $B = $null)
    if ($List.Count -gt 0) {
        $l = $List[$List.Count - 1]
        if ($l.F -eq $F -and $l.B -eq $B) { $l.T += $T; return }
    }
    [void]$List.Add(@{ T = $T; F = $F; B = $B })
}
function Get-SegWidth { param($Segs) $n = 0; foreach ($s in @($Segs)) { $n += $s.T.Length }; return $n }
function Write-SegLine {
    param($Segs, [int]$PadTo = 0)
    $n = 0
    foreach ($s in @($Segs)) {
        if (-not $s.T) { continue }
        $n += $s.T.Length
        if ($s.B) { Write-Host $s.T -NoNewline -ForegroundColor $s.F -BackgroundColor $s.B }
        elseif ($s.F) { Write-Host $s.T -NoNewline -ForegroundColor $s.F }
        else { Write-Host $s.T -NoNewline }
    }
    if ($PadTo -gt $n) { Write-Host (' ' * ($PadTo - $n)) -NoNewline }
    Write-Host ''
}

$script:Themes = @{
    storm   = @{ Rows = @('White', 'Cyan', 'Cyan', 'Blue', 'Blue'); Sh = 'DarkBlue' }
    cyan    = @{ Rows = @('White', 'Cyan', 'Cyan', 'DarkCyan', 'DarkCyan'); Sh = 'DarkBlue' }
    yellow  = @{ Rows = @('White', 'Yellow', 'Yellow', 'DarkYellow', 'DarkYellow'); Sh = 'DarkRed' }
    green   = @{ Rows = @('White', 'Green', 'Green', 'DarkGreen', 'DarkGreen'); Sh = 'DarkGray' }
    magenta = @{ Rows = @('White', 'Magenta', 'Magenta', 'DarkMagenta', 'DarkMagenta'); Sh = 'DarkBlue' }
    red     = @{ Rows = @('White', 'Red', 'Red', 'DarkRed', 'DarkRed'); Sh = 'DarkGray' }
    blue    = @{ Rows = @('White', 'Cyan', 'Blue', 'Blue', 'DarkBlue'); Sh = 'DarkGray' }
    gray    = @{ Rows = @('White', 'White', 'Gray', 'Gray', 'DarkGray'); Sh = 'DarkBlue' }
}

# Bloco de arte = @{ W; Lines = @( segs, segs, ... ) }
function Get-BigBlock {
    param([string]$Text, [string]$Theme = 'storm')
    $th = $script:Themes[$Theme]
    if (-not $th) { $th = $script:Themes['storm'] }
    $rows = @(ConvertTo-ShadowRows (Get-BigBitmap $Text))
    $W = 0
    foreach ($r in $rows) { if ($r.Length -gt $W) { $W = $r.Length } }
    $lines = @()
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $segs = New-Object System.Collections.ArrayList
        $bc = $th.Rows[[Math]::Min($i, $th.Rows.Count - 1)]
        foreach ($ch in $rows[$i].ToCharArray()) {
            if ($ch -eq '#') { Add-Seg $segs $script:G.Full $bc }
            elseif ($ch -eq ' ') { Add-Seg $segs ' ' }
            else { Add-Seg $segs ([string]$ch) $th.Sh }
        }
        $lines += , $segs
    }
    return @{ W = $W; Lines = $lines }
}

# ---------------------------------------------------------------------
#  Sprites: 1 caractere por pixel. Hex = cor do console (0-F), '.' = vazio.
#  0 Black 1 DarkBlue 2 DarkGreen 3 DarkCyan 4 DarkRed 5 DarkMagenta
#  6 DarkYellow 7 Gray 8 DarkGray 9 Blue A Green B Cyan C Red D Magenta
#  E Yellow F White
# ---------------------------------------------------------------------
$script:Sprites = @{
    bolt = @(
        '.......EEEE.',
        '......EEEE..',
        '.....EEEE...',
        '....EEEE....',
        '...EEEEEEEE.',
        '..EEEEEEEE..',
        '......EEE...',
        '.....EEE....',
        '....EE6.....',
        '...EE6......',
        '..E6........',
        '.6..........')
    chip = @(
        '...7.7.7...',
        '...7.7.7...',
        '..8888888..',
        '778BBBBB877',
        '..8B999B8..',
        '778B9F9B877',
        '..8B999B8..',
        '778BBBBB877',
        '..8888888..',
        '...7.7.7...',
        '...7.7.7...')
    gpu = @(
        '7.............',
        '78888888888888',
        '78833388833388',
        '783BBB383BBB38',
        '783B7B383B7B38',
        '783BBB383BBB38',
        '78833388833388',
        '78888888888888',
        '7...EEEEEEE...')
    bars = @(
        '..........AA',
        '..........AA',
        '.......AA.AA',
        '.......AA.AA',
        '....AA.AA.AA',
        '....AA.AA.AA',
        '.AA.AA.AA.AA',
        '.AA.AA.AA.AA')
    pad = @(
        '..DDDDDDDDDD..',
        '.DDDDDDDDDDDD.',
        'DDDFDDDDDDEDDD',
        'DDFFFDDDD9DCDD',
        'DDDFDDDDDDADDD',
        '55555555555555',
        '5555......5555',
        '.55........55.')
    gear = @(
        '....777....',
        '.7..777..7.',
        '.777777777.',
        '..77...77..',
        '7777...7777',
        '7777...7777',
        '7777...7777',
        '..77...77..',
        '.777777777.',
        '.7..777..7.',
        '....777....')
    scope = @(
        '..BBBBB.....',
        '.B11111B....',
        'B1FF1111B...',
        'B1F11111B...',
        'B1111111B...',
        'B1111111B...',
        '.B11111B....',
        '..BBBBB66...',
        '.......666..',
        '........666.',
        '.........66.')
    apps = @(
        'DDD.BBB.EEE',
        'DDD.BBB.EEE',
        'DDD.BBB.EEE',
        '...........',
        'AAA.CCC.999',
        'AAA.CCC.999',
        'AAA.CCC.999',
        '...........',
        '666.333.FFF',
        '666.333.FFF',
        '666.333.FFF')
    book = @(
        '4CCCCCCCCC.',
        '4CCCCCCCCCF',
        '4CEEEEEEECF',
        '4CCCCCCCCCF',
        '4CCEEEEECCF',
        '4CCCCCCCCCF',
        '4CCCCCCCCCF',
        '4CCCCCCCCCF',
        '4CCCCCCCCCF',
        '.FFFFFFFFFF')
    shield = @(
        'BBBBBB99999',
        'BBBBBB99999',
        'BBBBBB99F99',
        'BBBBBB9F999',
        'BBFBBBF9999',
        'BBBFBF99999',
        '.BBBF99999.',
        '.BBBBB9999.',
        '..BBBB999..',
        '...BBB99...',
        '....B99....',
        '.....9.....')
    crown = @(
        'F.....F.....F',
        'E.....E.....E',
        'EE...EEE...EE',
        'EEE.EEEEE.EEE',
        'EEEEEEEEEEEEE',
        'EECEEE9EEEAEE',
        'EEEEEEEEEEEEE',
        '6666666666666')
    battery = @(
        'FFFFFFFFFFFF..',
        'F..........F..',
        'F.AA.AA.AA.FFF',
        'F.AA.AA.AA.FFF',
        'F.AA.AA.AA.FFF',
        'F..........F..',
        'FFFFFFFFFFFF..')
    llama = @(
        '............D..D..',
        '............DD.DD.',
        '...........DDDDD..',
        '...........DDFFDD.',
        '...........DDF0DDE',
        '...........DDDDDDE',
        '...........DDDDD..',
        '...........DDDD...',
        '...........BBBB...',
        'E..........DDDD...',
        'EDDEDDBDDEDDBDDD..',
        'EDDEDDBDDEDDBDDD..',
        '.DDEDDBDDEDDBDDD..',
        '.DDEDDBDDEDDBDDD..',
        '.555555555555555..',
        '..55.55....55.55..',
        '..55.55....55.55..',
        '..55.55....55.55..',
        '..88.88....88.88..')
}

function Get-SpriteBlock {
    param([string]$Name)
    $px = $script:Sprites[$Name]
    if (-not $px) { return $null }
    return (ConvertFrom-Pixels $px)
}
# Versao compacta do titulo: o mesmo bitmap, 2 pixels por celula (3 linhas)
function Get-MiniBlock {
    param([string]$Text, [string]$Theme = 'storm')
    $th = $script:Themes[$Theme]
    if (-not $th) { $th = $script:Themes['storm'] }
    $bmp = @(Get-BigBitmap $Text)
    $W = 0
    foreach ($r in $bmp) { if ($r.Length -gt $W) { $W = $r.Length } }
    $px = @()
    for ($r = 0; $r -lt $bmp.Count; $r++) {
        $hex = '{0:X}' -f [int][ConsoleColor]$th.Rows[[Math]::Min($r, $th.Rows.Count - 1)]
        $px += (($bmp[$r].PadRight($W)).Replace(' ', '.')).Replace('#', $hex)
    }
    return (ConvertFrom-Pixels $px)
}
function ConvertFrom-Pixels {
    param([string[]]$px)
    $H = $px.Count
    $W = 0
    foreach ($r in $px) { if ($r.Length -gt $W) { $W = $r.Length } }
    $get = {
        param($r, $c)
        if ($r -ge $H) { return '.' }
        $row = $px[$r]
        if ($c -ge $row.Length) { return '.' }
        return [string]$row[$c]
    }
    $lines = @()
    for ($r = 0; $r -lt $H; $r += 2) {
        $segs = New-Object System.Collections.ArrayList
        for ($c = 0; $c -lt $W; $c++) {
            $t = & $get $r $c
            $b = & $get ($r + 1) $c
            if ($t -eq '.' -and $b -eq '.') { Add-Seg $segs ' '; continue }
            $tc = $null; $bcol = $null
            if ($t -ne '.') { $tc = [string][ConsoleColor]([Convert]::ToInt32($t, 16)) }
            if ($b -ne '.') { $bcol = [string][ConsoleColor]([Convert]::ToInt32($b, 16)) }
            if ($b -eq '.') { Add-Seg $segs $script:G.Up $tc }
            elseif ($t -eq '.') { Add-Seg $segs $script:G.Dn $bcol }
            elseif ($t -eq $b) { Add-Seg $segs $script:G.Full $tc }
            else { Add-Seg $segs $script:G.Up $tc $bcol }
        }
        $lines += , $segs
    }
    return @{ W = $W; Lines = $lines }
}

function New-TextBlock {
    param($Lines)
    $out = @()
    $W = 0
    foreach ($l in @($Lines)) {
        $segs = New-Object System.Collections.ArrayList
        foreach ($s in @($l)) { Add-Seg $segs $s.T $s.F $s.B }
        $lw = Get-SegWidth $segs
        if ($lw -gt $W) { $W = $lw }
        $out += , $segs
    }
    return @{ W = $W; Lines = $out }
}

# Junta blocos lado a lado (centralizados na vertical)
function Join-Blocks {
    param($Blocks, [int]$Gap = 3, [int]$Indent = 2)
    $bl = @($Blocks | Where-Object { $_ })
    $H = 0
    foreach ($b in $bl) { if ($b.Lines.Count -gt $H) { $H = $b.Lines.Count } }
    $lines = @()
    $W = $Indent
    for ($i = 0; $i -lt $bl.Count; $i++) { $W += $bl[$i].W; if ($i -gt 0) { $W += $Gap } }
    for ($r = 0; $r -lt $H; $r++) {
        $segs = New-Object System.Collections.ArrayList
        if ($Indent -gt 0) { Add-Seg $segs (' ' * $Indent) }
        for ($i = 0; $i -lt $bl.Count; $i++) {
            $b = $bl[$i]
            if ($i -gt 0) { Add-Seg $segs (' ' * $Gap) }
            $off = [int][Math]::Floor(($H - $b.Lines.Count) / 2)
            $k = $r - $off
            $used = 0
            if ($k -ge 0 -and $k -lt $b.Lines.Count) {
                foreach ($s in $b.Lines[$k]) { Add-Seg $segs $s.T $s.F $s.B; $used += $s.T.Length }
            }
            if ($b.W -gt $used) { Add-Seg $segs (' ' * ($b.W - $used)) }
        }
        $lines += , $segs
    }
    return @{ W = $W; Lines = $lines }
}

function Get-CenteredBlock {
    param($Block, [int]$Width)
    if (-not $Block) { return $null }
    $ind = [Math]::Max(0, [int](($Width - $Block.W) / 2))
    return (Join-Blocks @($Block) 0 $ind)
}

# Arte de cabecalho de cada tela (icone + titulo grande)
$script:ArtMap = @{
    diag    = @{ Icon = 'scope'; Text = 'DIAGNOSTICO'; Theme = 'cyan' }
    lag     = @{ Icon = 'bolt'; Text = 'INPUT LAG'; Theme = 'yellow' }
    cpu     = @{ Icon = 'chip'; Text = 'CPU'; Theme = 'cyan' }
    power   = @{ Icon = 'battery'; Text = 'ENERGIA'; Theme = 'green' }
    gpu     = @{ Icon = 'gpu'; Text = 'GPU'; Theme = 'green' }
    net     = @{ Icon = 'bars'; Text = 'REDE'; Theme = 'green' }
    fn      = @{ Icon = 'pad'; Text = 'FORTNITE'; Theme = 'magenta' }
    sys     = @{ Icon = 'gear'; Text = 'SISTEMA'; Theme = 'gray' }
    apps    = @{ Icon = 'apps'; Text = 'APPS'; Theme = 'cyan' }
    bulk    = @{ Icon = 'crown'; Text = 'APLICAR TUDO'; Theme = 'yellow' }
    guides  = @{ Icon = 'book'; Text = 'GUIAS'; Theme = 'red' }
    restore = @{ Icon = 'shield'; Text = 'RESTAURAR'; Theme = 'blue' }
}
$script:ArtCache = @{}
function Get-ArtBlock {
    param([string]$Key, [int]$Width, [int]$MaxH = 99)
    if (-not $script:Fancy -or -not $Key -or $MaxH -lt 3) { return $null }
    $big = Get-ArtBlockBig $Key $Width
    if ($big -and $big.Lines.Count -le $MaxH) { return $big }
    # nao cabe: versao compacta (3 linhas; logo ganha o subtitulo se couber)
    $ck = $Key + '|mini|' + $Width + '|' + [Math]::Min($MaxH, 4)
    if ($script:ArtCache.ContainsKey($ck)) { return $script:ArtCache[$ck] }
    $res = $null
    $txt = 'FORTNITE'; $th = 'storm'
    if ($script:ArtMap.ContainsKey($Key)) { $txt = L $script:ArtMap[$Key].Text; $th = $script:ArtMap[$Key].Theme }
    $mini = Get-MiniBlock $txt $th
    if ($Key -eq 'logo' -and $MaxH -ge 4) {
        $sub = Get-SubtitleBlock
        $sp = New-Object System.Collections.ArrayList
        Add-Seg $sp (' ' * [Math]::Max(0, [int](($mini.W - $sub.W) / 2)))
        foreach ($s in $sub.Lines[0]) { Add-Seg $sp $s.T $s.F $s.B }
        $mini.Lines += , $sp
        $mini.W = [Math]::Max($mini.W, $sub.W)
    }
    if ($mini.W -le $Width) { $res = Get-CenteredBlock $mini $Width }
    $script:ArtCache[$ck] = $res
    return $res
}
function Get-ArtBlockBig {
    param([string]$Key, [int]$Width)
    $ck = $Key + '|' + $Width
    if ($script:ArtCache.ContainsKey($ck)) { return $script:ArtCache[$ck] }
    $res = $null
    if ($Key -eq 'logo') {
        $big = Get-BigBlock 'FORTNITE' 'storm'
        $sub = Get-SubtitleBlock
        $stack = @{ W = [Math]::Max($big.W, $sub.W); Lines = @() }
        foreach ($l in $big.Lines) { $stack.Lines += , $l }
        $sp = New-Object System.Collections.ArrayList
        Add-Seg $sp (' ' * [Math]::Max(0, [int](($big.W - $sub.W) / 2)))
        foreach ($s in $sub.Lines[0]) { Add-Seg $sp $s.T $s.F $s.B }
        $stack.Lines += , $sp
        if ($stack.W -le $Width) { $res = Get-CenteredBlock $stack $Width }
    } elseif ($script:ArtMap.ContainsKey($Key)) {
        $a = $script:ArtMap[$Key]
        $icon = Get-SpriteBlock $a.Icon
        $big = Get-BigBlock (L $a.Text) $a.Theme
        $j = Join-Blocks @($icon, $big) 4 0
        if ($j.W -le $Width) { $res = Get-CenteredBlock $j $Width }
        elseif ($big.W -le $Width) { $res = Get-CenteredBlock $big $Width }
    }
    $script:ArtCache[$ck] = $res
    return $res
}
function Get-SubtitleBlock {
    $txt = L 'O T I M I Z A D O R'
    $cols = @('Cyan', 'Cyan', 'Blue', 'Blue', 'Magenta', 'Magenta', 'Blue', 'Blue', 'Cyan', 'Cyan')
    $segs = New-Object System.Collections.ArrayList
    Add-Seg $segs ($script:G.SH * 3 + ' ') 'DarkGray'
    $k = 0
    foreach ($ch in $txt.ToCharArray()) {
        if ($ch -eq ' ') { Add-Seg $segs ' '; continue }
        Add-Seg $segs ([string]$ch) $cols[$k % $cols.Count]; $k++
    }
    Add-Seg $segs ('  v' + $script:Version) 'Yellow'
    Add-Seg $segs (' ' + $script:G.SH * 3) 'DarkGray'
    return (New-TextBlock @(, $segs))
}
function Write-Block {
    param($Block, [int]$PadTo = 0)
    if (-not $Block) { return 0 }
    foreach ($l in $Block.Lines) { Write-SegLine $l $PadTo }
    return $Block.Lines.Count
}

function Center {
    param([string]$T, [int]$W)
    $p = [Math]::Max(0, [int](($W - $T.Length) / 2))
    return (Fit ((' ' * $p) + $T) $W)
}
# Caixa com moldura. Rows = lista de linhas, cada linha = lista de @{T; F}.
# (monte Rows com  $rows += , @(...)  para nao achatar os arrays)
function New-BoxBlock {
    param($Rows, [int]$Inner, [string]$Frame = 'Cyan', [switch]$Single)
    $g = $script:G
    $tl = $g.DTL; $tr = $g.DTR; $bl = $g.DBL; $br = $g.DBR; $hh = $g.DH; $vv = $g.DV
    if ($Single) { $tl = $g.STL; $tr = $g.STR; $bl = $g.SBL; $br = $g.SBR; $hh = $g.SH; $vv = $g.SV }
    $lines = @()
    $lines += , @(@{ T = ($tl + ($hh * $Inner) + $tr); F = $Frame })
    foreach ($r in $Rows) {
        $segs = @(@{ T = $vv; F = $Frame })
        $used = 0
        foreach ($s in @($r)) {
            $t = [string]$s.T
            if ($used + $t.Length -gt $Inner) { $t = $t.Substring(0, [Math]::Max(0, $Inner - $used)) }
            if ($t) { $segs += @{ T = $t; F = $s.F }; $used += $t.Length }
        }
        if ($Inner -gt $used) { $segs += @{ T = (' ' * ($Inner - $used)) } }
        $segs += @{ T = $vv; F = $Frame }
        $lines += , $segs
    }
    $lines += , @(@{ T = ($bl + ($hh * $Inner) + $br); F = $Frame })
    return (New-TextBlock $lines)
}

# Barra de progresso colorida
function Write-ProgressBar {
    param([int]$Pct, [int]$Len = 30, [string]$Color = 'Green')
    $Pct = [Math]::Min(100, [Math]::Max(0, $Pct))
    $n = [int]([Math]::Round($Len * $Pct / 100))
    Write-Host ('[') -NoNewline -ForegroundColor DarkGray
    if ($n -gt 0) { Write-Host ($script:G.Full * $n) -NoNewline -ForegroundColor $Color }
    if ($Len - $n -gt 0) { Write-Host ($script:G.Sh1 * ($Len - $n)) -NoNewline -ForegroundColor DarkGray }
    Write-Host ('] ') -NoNewline -ForegroundColor DarkGray
    Write-Host (('{0,3}%' -f $Pct)) -NoNewline -ForegroundColor White
}

# =====================================================================
#  CATALOGO DE OTIMIZACOES - Windows / Input lag / CPU / Tela
#  Tweak = @{ Id; Group; Name; Desc; Tags; Level; Evidence; Reboot; Kind
#             RegsFn | Apply/Undo/Check (scriptblocks chamando funcoes) }
#  Level: 0 guia | 1 seguro | 2 avancado | 3 risco alto/experimental
#  Kind : toggle (aplicar/desfazer) | action (faz o proprio fluxo)
# =====================================================================
$script:Tweaks = @()
function Add-Tweak {
    param([hashtable]$T)
    if (-not $T.Tags) { $T.Tags = @('ALL') }
    if ($null -eq $T.Level) { $T.Level = 1 }
    if (-not $T.Kind) { $T.Kind = 'toggle' }
    if (-not $T.Evidence) { $T.Evidence = '-' }
    $script:Tweaks += $T
}
function Get-Tweak { param([string]$Id) foreach ($t in $script:Tweaks) { if ($t.Id -eq $Id) { return $t } }; return $null }

function Get-TweakRegs {
    param($T)
    if ($T.RegsFn) { return @(& $T.RegsFn) }
    return @()
}
function Get-TweakState {
    param($T)
    try {
        if ($T.Check) {
            $v = & $T.Check
            if ($v -eq $true) { return 'ON' }
            if ($v -eq $false) { return 'OFF' }
            return ''
        }
        if ($T.RegsFn) {
            $regs = @(& $T.RegsFn)
            if ($regs.Count -eq 0) { return '' }
            if (Test-Regs $regs) { return 'ON' } else { return 'OFF' }
        }
    } catch { }
    return ''
}

# ---------------------------------------------------------------------
#  Listas de registro
# ---------------------------------------------------------------------
function Get-GameModeRegs {
    $x3d = $script:HW.Cpu.DualCcdX3D
    $gb = 'HKCU\Software\Microsoft\GameBar'
    $gc = 'HKCU\System\GameConfigStore'
    $r = @()
    $r += Rg $gb 'AllowAutoGameMode' 'DWord' 1
    $r += Rg $gb 'AutoGameModeEnabled' 'DWord' 1
    if (-not $x3d) { $r += Rg $gb 'UseNexusForGameBarEnabled' 'DWord' 0 }
    $r += Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 'DWord' 0
    $r += Rg $gc 'GameDVR_Enabled' 'DWord' 0
    $r += Rg $gc 'GameDVR_FSEBehaviorMode' 'DWord' 2
    $r += Rg $gc 'GameDVR_HonorUserFSEBehaviorMode' 'DWord' 1
    $r += Rg $gc 'GameDVR_DXGIHonorFSEWindowsCompatible' 'DWord' 1
    if (-not $x3d) { $r += Rg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 'DWord' 0 }
    return $r
}
function Get-MouseRegs {
    $m = 'HKCU\Control Panel\Mouse'
    return @((Rg $m 'MouseSpeed' 'String' '0'), (Rg $m 'MouseThreshold1' 'String' '0'), (Rg $m 'MouseThreshold2' 'String' '0'))
}
function Get-VisualRegs {
    $ex = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer'
    return @(
        (Rg ($ex + '\VisualEffects') 'VisualFXSetting' 'DWord' 2),
        (Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 'DWord' 0),
        (Rg ($ex + '\Advanced') 'TaskbarAnimations' 'DWord' 0),
        (Rg ($ex + '\Advanced') 'ListviewAlphaSelect' 'DWord' 0),
        (Rg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' 'String' '0'),
        (Rg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' 'String' '0')
    )
}
function Get-GpuPrefRegs {
    $exe = $script:HW.Fn.Exe
    if (-not $exe) { return @() }
    return @(Rg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' $exe 'String' 'GpuPreference=2;')
}
function Get-FsoRegs {
    $exe = $script:HW.Fn.Exe
    if (-not $exe) { return @() }
    return @(Rg 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' $exe 'String' '~ DISABLEDXMAXIMIZEDWINDOWEDMODE')
}
function Get-MmcssRegs {
    $sp = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    return @(
        (Rg ($sp + '\Tasks\Games') 'GPU Priority' 'DWord' 8),
        (Rg ($sp + '\Tasks\Games') 'Priority' 'DWord' 6),
        (Rg ($sp + '\Tasks\Games') 'Scheduling Category' 'String' 'High'),
        (Rg ($sp + '\Tasks\Games') 'SFIO Priority' 'String' 'High'),
        (Rg $sp 'SystemResponsiveness' 'DWord' 10)
    )
}
function Get-HagsRegs { return @(Rg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 'DWord' 2) }
function Get-TimerGlobalRegs { return @(Rg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' 'DWord' 1) }
function Get-IfeoRegs {
    $b = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe\PerfOptions'
    return @((Rg $b 'CpuPriorityClass' 'DWord' 3), (Rg $b 'IoPriority' 'DWord' 3))
}
function Get-VbsRegs {
    $dg = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    return @(
        (Rg ($dg + '\Scenarios\HypervisorEnforcedCodeIntegrity') 'Enabled' 'DWord' 0),
        (Rg ($dg + '\Scenarios\CredentialGuard') 'Enabled' 'DWord' 0),
        (Rg $dg 'EnableVirtualizationBasedSecurity' 'DWord' 0),
        (Rg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard' 'EnableVirtualizationBasedSecurity' 'DWord' 0)
    )
}
function Get-MpoRegs { return @(Rg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' 'DWord' 5) }
function Get-HidRegs {
    return @(
        (Rg 'HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' 'MouseDataQueueSize' 'DWord' 32),
        (Rg 'HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' 'KeyboardDataQueueSize' 'DWord' 32)
    )
}
function Get-BgAppsRegs {
    return @(
        (Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 'DWord' 0),
        (Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 'DWord' 0),
        (Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 'DWord' 0)
    )
}
function Get-DeliveryRegs {
    return @(
        (Rg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 'DWord' 0),
        (Rg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization' 'SystemSettingsDownloadMode' 'DWord' 0)
    )
}
function Get-ThrottleRegs { return @(Rg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 'DWord' 4294967295) }
function Get-QosRegs { return @(Rg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' 'DWord' 0) }
function Get-NagleRegs {
    $r = @()
    $base = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\'
    foreach ($n in @($script:HW.Nics)) {
        $g = [string]$n.InterfaceGuid
        if (-not $g) { continue }
        $r += Rg ($base + $g) 'TcpAckFrequency' 'DWord' 1
        $r += Rg ($base + $g) 'TCPNoDelay' 'DWord' 1
        $r += Rg ($base + $g) 'TcpDelAckTicks' 'DWord' 0
    }
    return $r
}

# ---------------------------------------------------------------------
#  Plano de energia proprio
# ---------------------------------------------------------------------
$script:PlanName = 'Fortnite Otimizador'
$script:BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
function Get-ActivePlan { return (Get-Guid ((Invoke-Native -File 'powercfg' -ArgList @('/getactivescheme') -Read).Output)) }
function Find-PlanByName {
    param([string]$Name)
    $out = (Invoke-Native -File 'powercfg' -ArgList @('/list') -Read).Output
    foreach ($l in ($out -split "`n")) {
        if ($l -like ('*' + $Name + '*')) { $g = Get-Guid $l; if ($g) { return $g } }
    }
    return $null
}
function Set-PlanAc {
    param([string]$Plan, [string]$Sub, [string]$Setting, [int]$Value)
    $r = Invoke-Native -File 'powercfg' -ArgList @('-setacvalueindex', $Plan, $Sub, $Setting, [string]$Value)
    if (-not $r.Dry -and $r.ExitCode -ne 0) { Say-Warn ('powercfg nao aceitou ' + $Setting + ' (normal se o hardware nao suporta)') }
}
function Test-PowerPlanActive {
    $a = Get-ActivePlan
    $p = Find-PlanByName $script:PlanName
    return [bool]($a -and $p -and ($a -eq $p))
}
function Apply-Power {
    return (Apply-PowerPlan)
}
function Undo-Power {
    $orig = $null
    if ($script:State.Other.ContainsKey('PowerOrig')) { $orig = [string]$script:State.Other['PowerOrig'] }
    if (-not $orig) {
        $lf = Join-Path $script:BackupDir 'energia_original.txt'
        if (Test-Path -LiteralPath $lf) { $orig = Get-Guid (Get-Content -LiteralPath $lf -Raw) }
    }
    $mine = Find-PlanByName $script:PlanName
    if (-not $orig -or ($mine -and $orig -eq $mine)) { $orig = $script:BalancedGuid }
    $r = Invoke-Native -File 'powercfg' -ArgList @('-setactive', $orig)
    if (-not $r.Dry -and $r.ExitCode -ne 0) {
        $r = Invoke-Native -File 'powercfg' -ArgList @('-setactive', $script:BalancedGuid)
    }
    [void](Undo-Regs @((Rg 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 'DWord' 1)))
    Say-Ok 'Plano de energia original reativado.'
    return $true
}
function Apply-CStates {
    $g = Find-PlanByName $script:PlanName
    if (-not $g) { Say-Warn 'Aplique primeiro o plano de energia proprio.'; return $false }
    Set-PlanAc $g '54533251-82be-4824-96c1-47b60b740d00' '5d76a2ca-e8c0-402f-a133-2158492d58ad' 1
    [void](Invoke-Native -File 'powercfg' -ArgList @('-setactive', $g))
    Say-Ok 'CPU mantida sempre acordada (idle desabilitado).'
    return $true
}
function Undo-CStates {
    $g = Find-PlanByName $script:PlanName
    if ($g) { Set-PlanAc $g '54533251-82be-4824-96c1-47b60b740d00' '5d76a2ca-e8c0-402f-a133-2158492d58ad' 0; [void](Invoke-Native -File 'powercfg' -ArgList @('-setactive', $g)) }
    Say-Ok 'Idle da CPU de volta ao normal.'
    return $true
}

# ---------------------------------------------------------------------
#  Timer 0.5ms forcado (tarefa agendada, so PowerShell nativo)
# ---------------------------------------------------------------------
$script:TimerTask = 'FortniteOtimizador_TimerRes'
function Test-TimerTask { return [bool](Get-ScheduledTask -TaskName $script:TimerTask -ErrorAction SilentlyContinue) }
function Apply-TimerForce {
    $ps1 = Join-Path $script:ToolsDir 'timerres_force.ps1'
    $code = @'
$sig = '[DllImport("ntdll.dll")] public static extern int NtQueryTimerResolution(out uint Min, out uint Max, out uint Cur); [DllImport("ntdll.dll")] public static extern int NtSetTimerResolution(uint Desired, bool Set, out uint Cur);'
Add-Type -MemberDefinition $sig -Name Timer -Namespace FnoTimer
$mn = [uint32]0; $mx = [uint32]0; $cu = [uint32]0
[void][FnoTimer.Timer]::NtQueryTimerResolution([ref]$mn, [ref]$mx, [ref]$cu)
[void][FnoTimer.Timer]::NtSetTimerResolution($mx, $true, [ref]$cu)
while ($true) { Start-Sleep -Seconds 3600 }
'@
    if ($script:Dry) { Say-Dry ('gravar ' + $ps1 + ' e registrar tarefa ' + $script:TimerTask); return $true }
    try {
        if (-not (Test-Path -LiteralPath $script:ToolsDir)) { [void](New-Item -ItemType Directory -Force -Path $script:ToolsDir) }
        [IO.File]::WriteAllText($ps1, $code, (New-Object Text.UTF8Encoding($true)))
        $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $ps1 + '"')
        $trg = New-ScheduledTaskTrigger -AtLogOn
        $usr = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $pri = New-ScheduledTaskPrincipal -UserId $usr -RunLevel Highest -LogonType Interactive
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
        [void](Register-ScheduledTask -TaskName $script:TimerTask -Action $act -Trigger $trg -Principal $pri -Settings $set -Force -ErrorAction Stop)
        Start-ScheduledTask -TaskName $script:TimerTask -ErrorAction SilentlyContinue
        Say-Ok 'Tarefa criada e iniciada (timer no minimo a cada logon).'
        return $true
    } catch { Say-Bad ('Falhou: ' + $_.Exception.Message); return $false }
}
function Undo-TimerForce {
    if ($script:Dry) { Say-Dry ('remover tarefa ' + $script:TimerTask); return $true }
    try {
        Stop-ScheduledTask -TaskName $script:TimerTask -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $script:TimerTask -Confirm:$false -ErrorAction SilentlyContinue
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'timerres_force' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath (Join-Path $script:ToolsDir 'timerres_force.ps1') -Force -ErrorAction SilentlyContinue
        Say-Ok 'Timer forcado removido.'
        return $true
    } catch { Say-Bad $_.Exception.Message; return $false }
}
function Show-TimerStatus {
    $t = [FnoNative]::TimerInfo()
    $s = [FnoNative]::MeasureSleep(30)
    Say ('  Timer do Windows: melhor possivel = {0:N3} ms | padrao = {1:N3} ms | atual (neste processo) = {2:N3} ms' -f ($t[1] / 10000.0), ($t[0] / 10000.0), ($t[2] / 10000.0)) 'Gray'
    Say ('  Sleep(1) real: media {0:N2} ms, pior {1:N2} ms' -f $s[0], $s[1]) 'Gray'
    Say '  (com o timer forcado ativo a media fica perto de 1-2 ms; sem ele ~15 ms. No Win11 o pedido e por processo,' 'DarkGray'
    Say '   a chave global do item "Timer global" faz o pedido do jogo valer para o sistema todo.)' 'DarkGray'
}

# ---------------------------------------------------------------------
#  Prioridade do Windows p/ app em 1o plano
# ---------------------------------------------------------------------
function Apply-PriSep {
    $cur = Get-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation'
    $idx = Select-Option -Title 'Win32PrioritySeparation' -Sub ('Valor atual: ' + $cur) -Options @(
        '38 (0x26)  curto + variavel + boost 3:1',
        '42 (0x2A)  curto + FIXO + boost 3:1  (mais agressivo)',
        '2  (padrao do Windows cliente)') -Descs @(
        'O padrao do Windows cliente (2) ja resolve para curto+variavel; 0x26 e quase igual ao padrao. Efeito pequeno.',
        'Quantum fixo: alguns relatam menos latencia e melhor 1% low; em PC com muita coisa aberta pode prejudicar multitarefa. Testes independentes nao mostram diferenca estatistica clara.',
        'Volta ao valor padrao.')
    if ($idx -lt 0) { return $false }
    $v = @(38, 42, 2)[$idx]
    return (Set-Reg -P 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' -N 'Win32PrioritySeparation' -T 'DWord' -V $v)
}
function Check-PriSep {
    $v = Get-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation'
    if ($null -eq $v) { return $false }
    return (([int]$v -eq 38) -or ([int]$v -eq 42))
}
function Undo-PriSep {
    $ok = Undo-Regs @((Rg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 'DWord' 2))
    if (-not $ok) { [void](Set-Reg -P 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' -N 'Win32PrioritySeparation' -T 'DWord' -V 2) }
    return $true
}

# ---------------------------------------------------------------------
#  Energia da USB (mouse/teclado): "permitir desligar p/ economizar"
# ---------------------------------------------------------------------
function Get-UsbPowerTargets {
    try { return @(Get-WmiObject -Namespace 'root\wmi' -Class MSPower_DeviceEnable -ErrorAction Stop | Where-Object { $_.InstanceName -match '^(USB|HID)\\' }) } catch { return @() }
}
function Check-UsbPower {
    $t = @(Get-UsbPowerTargets)
    if ($t.Count -eq 0) { return $null }
    foreach ($i in $t) { if ($i.Enable) { return $false } }
    return $true
}
function Apply-UsbPower {
    $t = @(Get-UsbPowerTargets)
    if ($t.Count -eq 0) { Say-Warn 'Nenhum dispositivo USB/HID com gerenciamento de energia encontrado.'; return $true }
    $changed = @()
    foreach ($i in $t) {
        if ($i.Enable) {
            if ($script:Dry) { Say-Dry ('desligar economia: ' + $i.InstanceName); continue }
            try { $i.Enable = $false; [void]$i.Put(); $changed += [string]$i.InstanceName } catch { Say-Warn ('nao consegui: ' + $i.InstanceName) }
        }
    }
    if (-not $script:Dry) {
        $prev = @()
        if ($script:State.Other.ContainsKey('UsbPower')) { $prev = @($script:State.Other['UsbPower']) }
        $script:State.Other['UsbPower'] = @($prev + $changed | Select-Object -Unique)
        Save-State
    }
    if ($script:Dry) { Say-Ok 'Simulado (modo teste).' } else { Say-Ok ('Economia de energia desligada em {0} dispositivo(s) USB/HID.' -f $changed.Count) }
    return $true
}
function Undo-UsbPower {
    $list = @()
    if ($script:State.Other.ContainsKey('UsbPower')) { $list = @($script:State.Other['UsbPower']) }
    if ($list.Count -eq 0) { Say-Info 'Nada a desfazer (nenhum dispositivo alterado por esta versao).'; return $true }
    foreach ($i in (Get-UsbPowerTargets)) {
        if ($list -contains [string]$i.InstanceName) {
            if ($script:Dry) { Say-Dry ('religar economia: ' + $i.InstanceName); continue }
            try { $i.Enable = $true; [void]$i.Put() } catch { }
        }
    }
    if (-not $script:Dry) { $script:State.Other.Remove('UsbPower'); Save-State }
    Say-Ok 'Economia de energia USB restaurada.'
    return $true
}

# ---------------------------------------------------------------------
#  MSI Mode (interrupcoes por mensagem) - sem baixar ferramenta nenhuma
# ---------------------------------------------------------------------
function Get-MsiPath { param([string]$Id) return ('HKLM\SYSTEM\CurrentControlSet\Enum\' + $Id + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties') }
function Get-MsiTargets {
    $t = @()
    foreach ($g in @($script:HW.Gpus)) { if ($g.Pnp -like 'PCI\*') { $t += @{ Kind = 'GPU'; Name = $g.Name; Id = $g.Pnp } } }
    try {
        foreach ($u in @(Get-CimInstance Win32_USBController -ErrorAction Stop)) {
            if ($u.PNPDeviceID -like 'PCI\*') { $t += @{ Kind = 'USB'; Name = [string]$u.Name; Id = [string]$u.PNPDeviceID } }
        }
    } catch { }
    foreach ($n in @($script:HW.Nics)) { if ($n.PnPDeviceID -like 'PCI\*') { $t += @{ Kind = 'REDE'; Name = [string]$n.InterfaceDescription; Id = [string]$n.PnPDeviceID } } }
    return $t
}
function Get-MsiState {
    param([string]$Id)
    $v = Get-Reg (Get-MsiPath $Id) 'MSISupported'
    if ($null -eq $v) { return 'PADRAO' }
    if ([int]$v -eq 1) { return 'ON' }
    return 'OFF'
}
function Menu-Msi {
    while ($true) {
        $targets = @(Get-MsiTargets)
        $items = @()
        $items += @{ Label = 'ATIVAR MSI em todos os dispositivos abaixo que ainda nao estao ON'; Desc = 'Grava MSISupported=1 na chave do dispositivo (o mesmo que o MSI Utility faz). Precisa reiniciar. Se algum driver nao suportar MSI o Windows ignora; em caso raro de tela preta, entre no Modo Seguro e use Desfazer/Restaurar.'; Badges = @() }
        foreach ($t in $targets) {
            $st = Get-MsiState $t.Id
            $items += @{ Label = ('{0}: {1}' -f (L $t.Kind), $t.Name); Desc = ('Estado atual do MSI: {0}. (PADRAO = o driver decide; NVIDIA moderna e a maioria das placas de rede/USB ja usam MSI sozinhas.) Enter alterna este dispositivo.' -f $st); State = $st; Badges = @() }
        }
        $items += @{ Label = 'Voltar'; Desc = ''; Badges = @() }
        $i = Show-Menu -Title 'MSI MODE (interrupcoes)' -Sub 'Menos DPC/ISR compartilhado = menos micro-stutter. Ganho tipico: pequeno. Exige reboot.' -Items $items
        if ($i -lt 0 -or $i -eq ($items.Count - 1)) { return }
        if ($i -eq 0) {
            foreach ($t in $targets) {
                if ((Get-MsiState $t.Id) -ne 'ON') { [void](Set-Reg -P (Get-MsiPath $t.Id) -N 'MSISupported' -T 'DWord' -V 1); Say-Ok ('MSI ativado: ' + $t.Name) }
            }
            Save-State
            Say-Info 'Reinicie o PC para valer.'
            Pause-Key
        } else {
            $t = $targets[$i - 1]
            $st = Get-MsiState $t.Id
            if ($st -eq 'ON') {
                if (Confirm-Action ('Desfazer MSI em ' + $t.Name + '?') $false) {
                    if (-not (Undo-Regs @((Rg (Get-MsiPath $t.Id) 'MSISupported' 'DWord' 1)))) { [void](Set-Reg -P (Get-MsiPath $t.Id) -N 'MSISupported' -T 'DWord' -V 0) }
                    Say-Ok 'Alterado. Reinicie.'; Pause-Key
                }
            } else {
                if (Confirm-Action ('Ativar MSI em ' + $t.Name + '?') $true) { [void](Set-Reg -P (Get-MsiPath $t.Id) -N 'MSISupported' -T 'DWord' -V 1); Save-State; Say-Ok 'Ativado. Reinicie.'; Pause-Key }
            }
        }
    }
}

# ---------------------------------------------------------------------
#  Audio: desliga Enhancements (so onde o Windows deixa escrever)
# ---------------------------------------------------------------------
$script:AudioKey = '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5'
function Get-AudioFxPaths {
    $out = @()
    foreach ($b in @('Render', 'Capture')) {
        $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\' + $b
        try { foreach ($d in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) { $out += (Join-Path $d.PSPath 'FxProperties') } } catch { }
    }
    return $out
}
function Apply-AudioFx {
    $bk = Join-Path $script:BackupDir 'audio_fx_backup.json'
    $paths = @(Get-AudioFxPaths)
    if ($script:Dry) { Say-Dry ('desligar Enhancements em ate {0} endpoint(s)' -f $paths.Count); return $true }
    if (-not (Test-Path -LiteralPath $bk)) {
        $rec = @()
        foreach ($p in $paths) {
            $had = Test-Path -LiteralPath $p
            $val = $null
            if ($had) { try { $val = (Get-ItemProperty -LiteralPath $p -Name $script:AudioKey -ErrorAction Stop).($script:AudioKey) } catch { $val = $null } }
            $rec += [pscustomobject]@{ Path = $p; Had = $had; Val = $val }
        }
        try { $rec | ConvertTo-Json | Set-Content -LiteralPath $bk -Encoding UTF8 } catch { }
    }
    $ok = 0; $fail = 0
    foreach ($p in $paths) {
        try {
            if (-not (Test-Path -LiteralPath $p)) { $fail++; continue }   # Windows nao deixa criar FxProperties (so o Audiosrv)
            New-ItemProperty -LiteralPath $p -Name $script:AudioKey -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
            $ok++
        } catch { $fail++ }
    }
    if ($ok -gt 0) { Say-Ok ('Enhancements desligados em {0} dispositivo(s).' -f $ok) }
    if ($fail -gt 0) { Say-Warn ('{0} dispositivo(s) protegido(s) pelo Windows - nesses use Som > Propriedades > Aprimoramentos.' -f $fail) }
    return ($ok -gt 0)
}
function Undo-AudioFx {
    $bk = Join-Path $script:BackupDir 'audio_fx_backup.json'
    if (-not (Test-Path -LiteralPath $bk)) { Say-Info 'Sem backup de audio (nunca aplicado).'; return $true }
    if ($script:Dry) { Say-Dry 'restaurar audio'; return $true }
    try {
        $recs = Get-Content -LiteralPath $bk -Raw | ConvertFrom-Json
        foreach ($r in @($recs)) {
            try {
                if (-not $r.Had) { if (Test-Path -LiteralPath $r.Path) { Remove-ItemProperty -LiteralPath $r.Path -Name $script:AudioKey -ErrorAction SilentlyContinue } }
                elseif ($null -ne $r.Val) { Set-ItemProperty -LiteralPath $r.Path -Name $script:AudioKey -Value ([int]$r.Val) -Type DWord -ErrorAction SilentlyContinue }
                else { Remove-ItemProperty -LiteralPath $r.Path -Name $script:AudioKey -ErrorAction SilentlyContinue }
            } catch { }
        }
        Remove-Item -LiteralPath $bk -Force -ErrorAction SilentlyContinue
        Say-Ok 'Audio restaurado.'
    } catch { Say-Bad $_.Exception.Message; return $false }
    return $true
}

# ---------------------------------------------------------------------
#  BCDEdit (alto risco) - guarda valor anterior
# ---------------------------------------------------------------------
function Get-BcdValue {
    param([string]$Name)
    $o = (Invoke-Native -File 'bcdedit' -ArgList @('/enum', '{current}') -Read).Output
    foreach ($l in ($o -split "`n")) {
        if ($l -match ('^\s*' + [regex]::Escape($Name) + '\s+(.+?)\s*$')) { return $Matches[1] }
    }
    return $null
}
function Set-BcdSafe {
    param([string]$Name, [string]$Value)
    if (-not $script:Dry) {
        if (-not $script:State.Other.ContainsKey('Bcd')) { $script:State.Other['Bcd'] = @{} }
        if (-not $script:State.Other['Bcd'].ContainsKey($Name)) { $script:State.Other['Bcd'][$Name] = (Get-BcdValue $Name); Save-State }
    }
    $r = Invoke-Native -File 'bcdedit' -ArgList @('/set', $Name, $Value)
    if (-not $r.Dry -and $r.ExitCode -ne 0) { Say-Bad ('bcdedit /set ' + $Name + ' falhou: ' + $r.Output.Trim()); return $false }
    Say-Ok ('bcdedit ' + $Name + ' = ' + $Value + ' (' + (L 'reinicie') + ')')
    return $true
}
function Undo-Bcd {
    foreach ($n in @('useplatformclock', 'disabledynamictick', 'tscsyncpolicy')) {
        $prev = $null
        if ($script:State.Other.ContainsKey('Bcd') -and $script:State.Other['Bcd'].ContainsKey($n)) { $prev = $script:State.Other['Bcd'][$n] }
        if ($prev) { [void](Invoke-Native -File 'bcdedit' -ArgList @('/set', $n, [string]$prev)) }
        else { [void](Invoke-Native -File 'bcdedit' -ArgList @('/deletevalue', $n)) }
    }
    if (-not $script:Dry -and $script:State.Other.ContainsKey('Bcd')) { $script:State.Other.Remove('Bcd'); Save-State }
    Say-Ok 'BCDEdit de volta ao padrao (reinicie).'
    return $true
}
function Menu-Bcd {
    $i = Select-Option -Title 'BCDEDIT AVANCADO (alto risco)' -Sub 'Resultado MISTO em testes: ajuda em alguns PCs, piora FPS/stutter em outros. Teste 1 por vez.' -Options @(
        'disabledynamictick = yes',
        'tscsyncpolicy = enhanced',
        'Garantir que useplatformclock NAO esta forcado (apaga o valor)',
        'DESFAZER tudo (volta ao padrao)') -Descs @(
        'Desliga o tick dinamico: agenda em intervalos fixos. Mais previsivel, mais consumo em idle. Ja causou queda de FPS em relatos de Overclock.net/Blur Busters.',
        'Politica de sincronia do TSC entre nucleos. Evidencia fraca/mista; alguns dizem que ajuda a estabilizar frametime.',
        'Windows moderno ja NAO forca o HPET por padrao. Este item so apaga o valor caso alguem tenha ligado (nao ha ganho em ligar).',
        'Restaura o valor anterior (ou apaga o valor) dos tres itens.')
    switch ($i) {
        0 { return (Set-BcdSafe 'disabledynamictick' 'yes') }
        1 { return (Set-BcdSafe 'tscsyncpolicy' 'enhanced') }
        2 { [void](Invoke-Native -File 'bcdedit' -ArgList @('/deletevalue', 'useplatformclock')); Say-Ok 'ok'; return $true }
        3 { return (Undo-Bcd) }
        default { return $false }
    }
}

# ---------------------------------------------------------------------
#  Taxa de atualizacao da tela
# ---------------------------------------------------------------------
function Action-MaxRefresh {
    Detect-Display
    $d = $script:HW.Display
    Say ('  Modo atual: {0}x{1} @ {2} Hz' -f $d.W, $d.H, $d.Hz) 'White'
    Say ('  Maximo que o Windows oferece nesta resolucao: {0} Hz (em qualquer resolucao: {1} Hz)' -f $d.MaxHz, $d.MaxHzAny) 'White'
    if ($d.MaxHz -le $d.Hz) {
        Say-Ok 'Ja esta no maximo dessa resolucao.'
        if ($d.MaxHzAny -gt $d.Hz) { Say-Info ('Sua tela chega a {0} Hz em outra resolucao; teste trocar a resolucao ou crie o modo com CRU / Painel da GPU.' -f $d.MaxHzAny) }
        else { Say-Info 'Se o monitor tem mais Hz que isso, use cabo DisplayPort, ative a taxa no menu OSD do monitor e/ou crie o modo no painel da GPU.' }
        return $true
    }
    if (-not (Confirm-Action ('Trocar para {0}x{1} @ {2} Hz agora? (a tela pisca; volta sozinha se voce nao confirmar em 15 s)' -f $d.W, $d.H, $d.MaxHz) $true)) { return $false }
    if ($script:Dry) { Say-Dry ('SetMode {0}x{1}@{2}' -f $d.W, $d.H, $d.MaxHz); return $true }
    $t = [FnoNative]::SetMode([uint32]$d.W, [uint32]$d.H, [uint32]$d.MaxHz, $true)
    if ($t -ne 0) { Say-Bad ('O driver recusou o modo (codigo ' + $t + ').'); return $false }
    $r = [FnoNative]::SetMode([uint32]$d.W, [uint32]$d.H, [uint32]$d.MaxHz, $false)
    if ($r -ne 0) { Say-Bad ('Falhou (codigo ' + $r + ').'); return $false }
    Start-Sleep -Milliseconds 1500
    $keep = Confirm-Action ('Ficou bom? Manter {0} Hz?' -f $d.MaxHz) $true
    if (-not $keep) { [void][FnoNative]::SetMode([uint32]$d.W, [uint32]$d.H, [uint32]$d.Hz, $false); Say-Warn 'Voltei para o modo anterior.'; return $false }
    Say-Ok ('Tela em {0} Hz.' -f $d.MaxHz)
    Write-Log ('Tela {0}x{1} {2}->{3} Hz' -f $d.W, $d.H, $d.Hz, $d.MaxHz)
    return $true
}

function Register-WindowsTweaks {
    Add-Tweak @{ Id = 'refresh'; Group = 'lag'; Kind = 'action'; Level = 1; Evidence = 'forte'
        Name = 'Taxa de atualizacao da tela no MAXIMO'
        Desc = 'Maior ganho isolado de latencia: cada Hz a mais reduz o tempo entre quadros (60Hz = 16,7 ms; 144Hz = 6,9 ms; 240Hz = 4,2 ms). Detecta o maior Hz que o Windows oferece e troca com teste e confirmacao (volta sozinho se a tela ficar preta).'
        Apply = { Action-MaxRefresh } }
    Add-Tweak @{ Id = 'gamemode'; Group = 'lag'; Level = 1; Evidence = 'media'
        Name = 'Game Mode ON + gravacao em 2o plano (Game DVR) OFF'
        Desc = 'Liga o Game Mode, desliga o Game DVR/captura em fundo e o "FSE behavior" global (Fullscreen Optimizations). No Ryzen X3D de 2 CCDs a Xbox Game Bar e mantida, porque o driver 3D V-Cache da AMD usa a Game Bar para detectar jogos.'
        RegsFn = { Get-GameModeRegs } }
    Add-Tweak @{ Id = 'power'; Group = 'cpu'; Level = 1; Evidence = 'media'
        Name = 'Plano de energia OTIMIZADO (perfil automatico do seu CPU)'
        Desc = 'Cria/atualiza o plano "Fortnite Otimizador" com ~20 configuracoes avancadas conferidas no SEU Windows (boost agressivo, EPP maximo, sem core parking, USB/USB3/PCIe/Wi-Fi/HD sem economia, resfriamento ativo, Power Throttling OFF). O perfil muda conforme o CPU: Intel classico, Intel hibrido P+E, Ryzen, Ryzen X3D de 2 CCDs (que NAO pode desestacionar nucleos). Seu plano atual nao e alterado; o Desfazer volta pra ele. Veja o item abaixo para escolher/exportar/importar.'
        Check = { Test-PowerPlanActive }; Apply = { Apply-Power }; Undo = { Undo-Power } }
    Add-Tweak @{ Id = 'power_menu'; Group = 'cpu'; Kind = 'action'; Level = 1; Evidence = 'media'
        Name = 'Plano de energia: escolher perfil, ver tudo, EXPORTAR / IMPORTAR .pow'
        Desc = 'Menu completo do plano de energia: aplica o perfil recomendado, deixa escolher outro (Intel classico / hibrido / Ryzen / X3D 2 CCDs), mostra cada configuracao com o motivo, exporta o plano para um arquivo .pow (para compartilhar) e importa um .pow.'
        Apply = { Menu-Power } }
    Add-Tweak @{ Id = 'timerglobal'; Group = 'cpu'; Level = 1; Evidence = 'media'; Tags = @('WIN11')
        Name = 'Timer global: pedido de resolucao do jogo vale p/ o sistema todo'
        Desc = 'A partir do Win10 2004/Win11 o timer de 0,5 ms pedido pelo jogo passou a valer so p/ o processo dele. GlobalTimerResolutionRequests=1 restaura o comportamento global (uma chave, nenhum programa rodando). Sem efeito no Win10 antigo.'
        RegsFn = { Get-TimerGlobalRegs } }
    Add-Tweak @{ Id = 'timerforce'; Group = 'cpu'; Level = 2; Evidence = 'media'
        Name = 'Timer FORCADO no minimo (tarefa agendada, sem baixar .exe)'
        Desc = 'Tarefa no logon (PowerShell nativo, 0 download) que pede a MENOR resolucao possivel via NtSetTimerResolution. Custo real: CPU acorda ~2000x/s em vez de ~64x/s, mais consumo em idle e bateria. Combine com o item acima; se o jogo ja pede sozinho, o ganho extra e pequeno. Use "Medir timer" no Diagnostico para conferir.'
        Check = { Test-TimerTask }; Apply = { Apply-TimerForce }; Undo = { Undo-TimerForce } }
    Add-Tweak @{ Id = 'mouse'; Group = 'lag'; Level = 1; Evidence = 'forte'
        Name = 'Mouse 1:1 no Windows (Enhance Pointer Precision OFF)'
        Desc = 'HONESTO: o Fortnite usa raw input e NAO tem aceleracao de mouse no PC, entao isto NAO muda a mira dentro do jogo; so deixa o cursor de desktop/menu/loja 1:1. Para a mira o que importa: DPI fixo (400-1600), polling 1000 Hz+ no software do mouse e sensibilidade no proprio jogo.'
        RegsFn = { Get-MouseRegs } }
    Add-Tweak @{ Id = 'visualfx'; Group = 'lag'; Level = 1; Evidence = 'fraca'
        Name = 'Efeitos visuais do Windows no minimo (sem transparencia/animacao)'
        Desc = 'Menos trabalho para o DWM. Ganho real so em GPU integrada/PC fraco (+2 a 5% FPS); em GPU dedicada e minimo. Muda a aparencia do Windows (sem transparencia).'
        RegsFn = { Get-VisualRegs } }
    Add-Tweak @{ Id = 'gpupref'; Group = 'lag'; Level = 1; Evidence = 'media'
        Name = 'Fortnite sempre na GPU de alto desempenho (Configuracoes > Graficos)'
        Desc = 'Importante em notebooks/PCs com placa integrada + dedicada: garante que o jogo NAO rode na integrada. Precisa achar o FortniteClient-Win64-Shipping.exe.'
        RegsFn = { Get-GpuPrefRegs } }
    Add-Tweak @{ Id = 'fso'; Group = 'lag'; Level = 2; Evidence = 'media'
        Name = 'Fullscreen Optimizations OFF no exe do Fortnite'
        Desc = 'Marca DISABLEDXMAXIMIZEDWINDOWEDMODE no exe. No Win11 24H2/25H2 o modo "Independent Flip" ja evita o compositor em muitos casos, entao o ganho hoje e menor que no Win10; o item so garante o comportamento antigo. Use tambem "Tela cheia" (nao janela) no jogo.'
        RegsFn = { Get-FsoRegs } }
    Add-Tweak @{ Id = 'mmcss'; Group = 'cpu'; Level = 2; Evidence = 'fraca'
        Name = 'MMCSS: prioridade "Games" + SystemResponsiveness=10'
        Desc = 'Reserva mais CPU/GPU para tarefas multimidia registradas como Games. Nao ha prova de que o Fortnite use essa classe do MMCSS; efeito pequeno/nao comprovado. Mantido por ser seguro e reversivel.'
        RegsFn = { Get-MmcssRegs } }
    Add-Tweak @{ Id = 'prisep'; Group = 'cpu'; Level = 2; Evidence = 'fraca'; NoBulk = $true
        Name = 'Win32PrioritySeparation (fatia de CPU do app em foco)'
        Desc = 'Tweak classico. O padrao do Windows cliente ja e "curto+variavel"; 38 (0x26) e quase igual. 42 (0x2A) usa quantum FIXO e e o unico que muda de verdade, com resultados mistos em testes. Voce escolhe o valor.'
        Check = { Check-PriSep }; Apply = { Apply-PriSep }; Undo = { Undo-PriSep } }
    Add-Tweak @{ Id = 'ifeo'; Group = 'cpu'; Level = 2; Evidence = 'media'
        Name = 'Prioridade ALTA fixa p/ o Fortnite (CPU + disco) via registro'
        Desc = 'Grava PerfOptions (CpuPriorityClass=High, IoPriority=High) para o FortniteClient-Win64-Shipping.exe: o Windows ja cria o processo com prioridade alta, sem programa extra. O Easy Anti-Cheat bloqueia mudar prioridade de fora com o jogo aberto, mas isto e aplicado na criacao. Nao ha relato conhecido de ban por PerfOptions; a Epic nao documenta. Se o EAC reclamar, desfaca.'
        RegsFn = { Get-IfeoRegs } }
    Add-Tweak @{ Id = 'hags'; Group = 'lag'; Level = 2; Evidence = 'media'; Reboot = $true; NoBulk = $true; Tags = @('NV', 'AMD', 'INTELGPU')
        Name = 'HAGS: agendamento de GPU acelerado por hardware'
        Desc = 'Deixa a GPU gerenciar a propria fila. OBRIGATORIO para DLSS Frame Generation (RTX 40/50): nao desligue se voce usa FG em outros jogos. Na latencia pura o efeito e pequeno e varia (+-1 a 2%, depende do driver). Por isso NAO entra no "Aplicar tudo". Teste com o CapFrameX antes de decidir. Precisa reiniciar.'
        RegsFn = { Get-HagsRegs } }
    Add-Tweak @{ Id = 'usbpower'; Group = 'lag'; Level = 2; Evidence = 'media'
        Name = 'USB/HID: desligar "permitir desligar p/ economizar energia"'
        Desc = 'Evita o mouse/teclado dormir e demorar para acordar (falha de 1o movimento/micro-atraso). Aplica a todos os hubs/dispositivos USB e HID e guarda a lista p/ desfazer.'
        Check = { Check-UsbPower }; Apply = { Apply-UsbPower }; Undo = { Undo-UsbPower } }
    Add-Tweak @{ Id = 'msi'; Group = 'lag'; Kind = 'action'; Level = 2; Evidence = 'media'; Reboot = $true
        Name = 'MSI Mode da GPU / USB / Placa de rede (sem baixar ferramenta)'
        Desc = 'Interrupcao por mensagem em vez de linha compartilhada = menos DPC. No Windows 11 com driver atual a maioria das GPUs/placas de rede JA vem em MSI/MSI-X, entao muitas vezes nao ha nada a fazer: o menu mostra o estado de cada dispositivo e ativa so o que precisa. Para achar o driver culpado de picos, meca antes com o LatencyMon (menu Programas). Exige reiniciar.'
        Apply = { Menu-Msi } }
    Add-Tweak @{ Id = 'audiofx'; Group = 'lag'; Level = 2; Evidence = 'fraca'
        Name = 'Audio: Enhancements do Windows OFF'
        Desc = 'Tira o DSP (EQ/loudness) do caminho do som. Parte das chaves e protegida pelo Windows; o script muda onde da e avisa o resto (desligue em Som > Propriedades > Aprimoramentos).'
        Check = { $p = @(Get-AudioFxPaths | Where-Object { Test-Path -LiteralPath $_ }); if ($p.Count -eq 0) { return $null }; foreach ($x in $p) { try { $v = (Get-ItemProperty -LiteralPath $x -Name $script:AudioKey -ErrorAction Stop).($script:AudioKey); if ([int]$v -ne 1) { return $false } } catch { return $false } }; return $true }
        Apply = { Apply-AudioFx }; Undo = { Undo-AudioFx } }
    Add-Tweak @{ Id = 'cstates'; Group = 'cpu'; Level = 3; Evidence = 'fraca'; Tags = @('DESKTOP'); Reboot = $false
        Name = 'CPU sempre em C0 (desabilitar idle states) - EXTREMO'
        Desc = 'Configura o plano "Fortnite Otimizador" com IDLEDISABLE=1: a CPU nunca entra em estados de economia, sem latencia de despertar. Esquenta e consome bem mais, vida util menor com cooler fraco. Evidencia de ganho perceptivel e fraca. So desktop, e so para quem mede.'
        Check = { $null }; Apply = { Apply-CStates }; Undo = { Undo-CStates } }
    Add-Tweak @{ Id = 'hid'; Group = 'lag'; Level = 3; Evidence = 'nenhuma'; Reboot = $true
        Name = 'Buffer de HID mouse/teclado = 32 (NAO COMPROVADO)'
        Desc = 'MouseDataQueueSize/KeyboardDataQueueSize (padrao 100). Pesquisa dividida; varios testes nao acham ganho real e alguns chamam de placebo. Sem risco de quebrar (nao use menos de 16).'
        RegsFn = { Get-HidRegs } }
    Add-Tweak @{ Id = 'vbs'; Group = 'lag'; Level = 3; Evidence = 'forte'; Reboot = $true
        Name = 'VBS / Integridade de memoria (HVCI) OFF  -  REDUZ SEGURANCA'
        Desc = 'Microsoft e testes independentes mostram +5 a 15% FPS em alguns jogos ao desligar (varia muito; em CPU recente e menor). Custo: perde uma camada anti-malware de kernel e desliga Credential Guard. Se voce usa VirtualBox/WSL2/Hyper-V isso nao afeta. Depois confirme em Seguranca do Windows > Isolamento de nucleo. Updates grandes do Windows 11 (24H2/25H2) podem religar sozinho: reconfira o estado aqui apos cada atualizacao de versao. Reversivel.'
        RegsFn = { Get-VbsRegs } }
    Add-Tweak @{ Id = 'mpo'; Group = 'lag'; Level = 3; Evidence = 'fraca'; Reboot = $true; Tags = @('NV', 'AMD')
        Name = 'MPO (Multi-Plane Overlay) OFF - correcao de flicker/stutter'
        Desc = 'Recomendacao oficial da NVIDIA para flicker/tela preta/stutter com varios monitores ou HDR. NAO e um tweak de latencia comprovado: so use se voce tem esses sintomas. Precisa reiniciar.'
        RegsFn = { Get-MpoRegs } }
    Add-Tweak @{ Id = 'bcd'; Group = 'lag'; Kind = 'action'; Level = 3; Evidence = 'mista'; Reboot = $true
        Name = 'BCDEdit avancado (dynamictick / tscsyncpolicy)'
        Desc = 'ALTO RISCO/misto: em alguns PCs melhora DPC, em outros PIORA FPS. Guarda o valor anterior e tem "Desfazer tudo". Teste 1 por vez.'
        Apply = { [void](Menu-Bcd) } }
}

# =====================================================================
#  REDE (Ethernet + Wi-Fi)
# =====================================================================
$script:DnsProviders = @{
    'cloudflare' = @('1.1.1.1', '1.0.0.1')
    'google'     = @('8.8.8.8', '8.8.4.4')
    'quad9'      = @('9.9.9.9', '149.112.112.112')
}

# --- Ajustes avancados do adaptador, por PALAVRA-CHAVE do driver -------
# (nomes de tela mudam com o idioma; a RegistryKeyword nao)
function Get-NicChanges {
    $changes = @()
    $clear = '^\*?(EEE|InterruptModeration|FlowControl)$|^(EEELinkAdvertisement|EnableGreenEthernet|GreenEthernet|GigaLite|ReduceSpeedOnPowerDown|AdvancedEEE|ULPMode|EnableSavePowerNow)$'
    $ambig = 'PowerSav|PowerSave|PSMode|uAPSD|Roam'
    foreach ($n in @($script:HW.Nics)) {
        $props = @(Get-NetAdapterAdvancedProperty -Name $n.Name -ErrorAction SilentlyContinue)
        foreach ($p in $props) {
            $kw = [string]$p.RegistryKeyword
            $old = [string](@($p.RegistryValue)[0])
            $new = $null
            $disp = ''
            $valsReg = @($p.ValidRegistryValues)
            $valsDisp = @($p.ValidDisplayValues)
            if ($kw -match $clear) {
                if ($valsReg -contains '0') { $new = '0'; $disp = 'Desativado' }
            } elseif ($kw -match $ambig) {
                for ($i = 0; $i -lt $valsDisp.Count; $i++) {
                    if ([string]$valsDisp[$i] -match '^\s*(\d+\.\s*)?(disabled?|off|maximum performance|lowest|no power ?sav\w*|desativad\w*|desligad\w*|desempenho m\w+|mais baixo)\s*$') {
                        if ($i -lt $valsReg.Count) { $new = [string]$valsReg[$i]; $disp = [string]$valsDisp[$i] }
                        break
                    }
                }
            }
            if ($null -ne $new -and $new -ne $old) {
                $changes += @{ Nic = [string]$n.Name; Keyword = $kw; Name = [string]$p.DisplayName; OldReg = $old; OldDisp = [string]$p.DisplayValue; NewReg = $new; NewDisp = $disp }
            }
        }
    }
    return $changes
}
function Action-Nic {
    Say '  Lendo as opcoes reais do seu adaptador...' 'DarkGray'
    $ch = @(Get-NicChanges)
    if ($ch.Count -eq 0) { Say-Ok 'Nada a alterar: o adaptador ja esta sem economia de energia/moderacao de interrupcao (ou o driver nao expoe essas opcoes).'; return $true }
    Say ('  O que sera alterado ({0} item(ns)):' -f $ch.Count) 'White'
    foreach ($c in $ch) { Say ('   {0}: {1}   {2} -> {3}' -f $c.Nic, $c.Name, $c.OldDisp, $c.NewDisp) 'Gray' }
    Say '  Aviso: o adaptador reinicia (rede cai ~5 s). Interrupt Moderation OFF = menos latencia, um pouco mais de CPU.' 'Yellow'
    if (-not (Confirm-Action 'Aplicar estas mudancas?' $true)) { return $false }
    if ($script:Dry) { foreach ($c in $ch) { Say-Dry ('{0} {1} = {2}' -f $c.Nic, $c.Keyword, $c.NewReg) }; return $true }
    $rec = @()
    if ($script:State.Other.ContainsKey('Nic')) { $rec = @($script:State.Other['Nic']) }
    $nics = @()
    foreach ($c in $ch) {
        try {
            $already = $false
            foreach ($r in $rec) { if ($r.Nic -eq $c.Nic -and $r.Keyword -eq $c.Keyword) { $already = $true } }
            if (-not $already) { $rec += @{ Nic = $c.Nic; Keyword = $c.Keyword; Old = $c.OldReg } }
            Set-NetAdapterAdvancedProperty -Name $c.Nic -RegistryKeyword $c.Keyword -RegistryValue $c.NewReg -NoRestart -ErrorAction Stop
            if ($nics -notcontains $c.Nic) { $nics += $c.Nic }
            Write-Log ('NIC {0} {1}: {2} -> {3}' -f $c.Nic, $c.Keyword, $c.OldReg, $c.NewReg)
        } catch { Say-Warn ('Nao consegui alterar ' + $c.Name + ': ' + $_.Exception.Message) }
    }
    $script:State.Other['Nic'] = $rec
    Save-State
    foreach ($n in $nics) { try { Restart-NetAdapter -Name $n -Confirm:$false -ErrorAction SilentlyContinue } catch { } }
    Say-Ok 'Adaptador ajustado.'
    return $true
}
function Undo-Nic {
    if (-not $script:State.Other.ContainsKey('Nic')) { Say-Info 'Nada a desfazer (nenhum ajuste de adaptador feito por esta versao).'; return $true }
    $nics = @()
    foreach ($r in @($script:State.Other['Nic'])) {
        if ($script:Dry) { Say-Dry ('restaurar {0} {1} = {2}' -f $r.Nic, $r.Keyword, $r.Old); continue }
        try { Set-NetAdapterAdvancedProperty -Name $r.Nic -RegistryKeyword $r.Keyword -RegistryValue ([string]$r.Old) -NoRestart -ErrorAction Stop; if ($nics -notcontains $r.Nic) { $nics += $r.Nic } } catch { Say-Warn ('Nao consegui restaurar ' + $r.Keyword) }
    }
    if (-not $script:Dry) {
        foreach ($n in $nics) { try { Restart-NetAdapter -Name $n -Confirm:$false -ErrorAction SilentlyContinue } catch { } }
        $script:State.Other.Remove('Nic'); Save-State
    }
    Say-Ok 'Adaptador restaurado.'
    return $true
}

# --- DNS ----------------------------------------------------------------
function Action-Dns {
    $i = Select-Option -Title 'DNS' -Sub 'DNS NAO muda o ping dentro da partida (o jogo fala por IP/UDP); acelera login, loja e matchmaking.' -Options @(
        'Cloudflare  1.1.1.1 / 1.0.0.1', 'Google  8.8.8.8 / 8.8.4.4', 'Quad9  9.9.9.9 / 149.112.112.112', 'Automatico (DHCP) - restaurar') -Descs @(
        'Geralmente o mais rapido no Brasil.', 'Muito estavel.', 'Bloqueia dominios maliciosos.', 'Volta a usar o DNS que o roteador/provedor entrega.')
    if ($i -lt 0) { return $false }
    $set = $null
    switch ($i) { 0 { $set = $script:DnsProviders['cloudflare'] } 1 { $set = $script:DnsProviders['google'] } 2 { $set = $script:DnsProviders['quad9'] } default { $set = $null } }
    $known = @(); foreach ($k in $script:DnsProviders.Keys) { $known += ($script:DnsProviders[$k] -join ',') }
    foreach ($n in @($script:HW.Nics)) {
        if ($script:Dry) { if ($set) { Say-Dry ('DNS ' + ($set -join ',') + ' em ' + $n.Name) } else { Say-Dry ('DNS automatico em ' + $n.Name) }; continue }
        try {
            $g = [string]$n.InterfaceGuid
            $cur = Get-Reg ('HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\' + $g) 'NameServer'
            if (-not $script:State.Other.ContainsKey('Dns')) { $script:State.Other['Dns'] = @{} }
            if (-not $script:State.Other['Dns'].ContainsKey($g)) {
                $curs = [string]$cur
                if ($known -contains ($curs -replace ' ', '')) { $curs = '' }
                $script:State.Other['Dns'][$g] = $curs
            }
            if ($set) { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses $set -ErrorAction Stop; Say-Ok ('DNS ' + ($set -join ', ') + ' em ' + $n.Name) }
            else { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction Stop; Say-Ok ('DNS automatico em ' + $n.Name) }
        } catch { Say-Bad ('DNS em ' + $n.Name + ': ' + $_.Exception.Message) }
    }
    if (-not $script:Dry) { Save-State }
    [void](Invoke-Native -File 'ipconfig' -ArgList @('/flushdns'))
    return $true
}
function Undo-Dns {
    foreach ($n in @($script:HW.Nics)) {
        if ($script:Dry) { Say-Dry ('DNS automatico em ' + $n.Name); continue }
        $g = [string]$n.InterfaceGuid
        $prev = ''
        if ($script:State.Other.ContainsKey('Dns') -and $script:State.Other['Dns'].ContainsKey($g)) { $prev = [string]$script:State.Other['Dns'][$g] }
        try {
            if ($prev) { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses ($prev -split '[ ,]+' | Where-Object { $_ }) -ErrorAction Stop }
            else { Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction Stop }
        } catch { }
    }
    if (-not $script:Dry -and $script:State.Other.ContainsKey('Dns')) { $script:State.Other.Remove('Dns'); Save-State }
    Say-Ok 'DNS restaurado.'
    return $true
}

# --- Pilha TCP ------------------------------------------------------------
function Get-TcpSetting {
    try { return (Get-NetTCPSetting -SettingName InternetCustom -ErrorAction Stop) } catch { return $null }
}
function Check-Tcp {
    $s = Get-TcpSetting
    if (-not $s) { return $null }
    return (([string]$s.AutoTuningLevelLocal -eq 'Normal') -and ([string]$s.EcnCapability -eq 'Disabled') -and ([string]$s.Timestamps -eq 'Disabled'))
}
function Apply-Tcp {
    $s = Get-TcpSetting
    if ($s -and -not $script:Dry -and -not $script:State.Other.ContainsKey('Tcp')) {
        $script:State.Other['Tcp'] = @{ Auto = [string]$s.AutoTuningLevelLocal; Ecn = [string]$s.EcnCapability; Ts = [string]$s.Timestamps }
        Save-State
    }
    $r = Invoke-Native -File 'netsh' -ArgList @('int', 'tcp', 'set', 'global', 'autotuninglevel=normal', 'rss=enabled', 'ecncapability=disabled', 'timestamps=disabled')
    if (-not $r.Dry -and $r.ExitCode -ne 0) { Say-Bad ('netsh falhou: ' + $r.Output.Trim()); return $false }
    Say-Ok 'TCP: autotuning normal, RSS on, ECN off, timestamps off.'
    return $true
}
function Undo-Tcp {
    $a = 'normal'; $e = 'default'; $t = 'default'
    if ($script:State.Other.ContainsKey('Tcp')) {
        $o = $script:State.Other['Tcp']
        $a = ([string]$o.Auto).ToLower(); $e = ([string]$o.Ecn).ToLower(); $t = ([string]$o.Ts).ToLower()
    }
    if (@('disabled', 'enabled', 'default') -notcontains $e) { $e = 'default' }
    if (@('disabled', 'enabled', 'default') -notcontains $t) { $t = 'default' }
    if (@('normal', 'disabled', 'restricted', 'highlyrestricted', 'experimental') -notcontains $a) { $a = 'normal' }
    [void](Invoke-Native -File 'netsh' -ArgList @('int', 'tcp', 'set', 'global', ('autotuninglevel=' + $a), 'rss=enabled', ('ecncapability=' + $e), ('timestamps=' + $t)))
    if (-not $script:Dry -and $script:State.Other.ContainsKey('Tcp')) { $script:State.Other.Remove('Tcp'); Save-State }
    Say-Ok 'TCP no padrao anterior.'
    return $true
}

# --- Tuneis IPv6 legados ------------------------------------------------
function Check-Tunnels {
    try {
        return (([string](Get-NetTeredoConfiguration -ErrorAction Stop).Type -eq 'Disabled') -and ([string](Get-Net6to4Configuration -ErrorAction Stop).State -eq 'Disabled') -and ([string](Get-NetIsatapConfiguration -ErrorAction Stop).State -eq 'Disabled'))
    } catch { return $null }
}
function Apply-Tunnels {
    if ($script:Dry) { Say-Dry 'Teredo/6to4/ISATAP -> Disabled'; return $true }
    try {
        Set-NetTeredoConfiguration -Type Disabled -ErrorAction Stop
        Set-Net6to4Configuration -State Disabled -ErrorAction Stop
        Set-NetIsatapConfiguration -State Disabled -ErrorAction Stop
        $script:State.Other['Tunnels'] = $true; Save-State
        Say-Ok 'Teredo, 6to4 e ISATAP desligados.'
        return $true
    } catch { Say-Bad $_.Exception.Message; return $false }
}
function Undo-Tunnels {
    if ($script:Dry) { Say-Dry 'Teredo/6to4/ISATAP -> Default'; return $true }
    try {
        Set-NetTeredoConfiguration -Type Default -ErrorAction SilentlyContinue
        Set-Net6to4Configuration -State Default -ErrorAction SilentlyContinue
        Set-NetIsatapConfiguration -State Default -ErrorAction SilentlyContinue
        if ($script:State.Other.ContainsKey('Tunnels')) { $script:State.Other.Remove('Tunnels'); Save-State }
        Say-Ok 'Tuneis no padrao.'
    } catch { }
    return $true
}

# --- LSO ----------------------------------------------------------------
function Check-Lso {
    try {
        foreach ($n in @($script:HW.Nics)) {
            $l = Get-NetAdapterLso -Name $n.Name -ErrorAction Stop
            if ($l.IPv4Enabled -or $l.IPv6Enabled) { return $false }
        }
        return $true
    } catch { return $null }
}
function Apply-Lso {
    $was = @()
    foreach ($n in @($script:HW.Nics)) {
        try { $l = Get-NetAdapterLso -Name $n.Name -ErrorAction Stop; if ($l.IPv4Enabled -or $l.IPv6Enabled) { $was += [string]$n.Name } } catch { }
    }
    if ($script:Dry) { foreach ($w in $was) { Say-Dry ('Disable-NetAdapterLso ' + $w) }; return $true }
    if (-not $script:State.Other.ContainsKey('Lso')) { $script:State.Other['Lso'] = $was; Save-State }
    foreach ($w in $was) {
        try { Disable-NetAdapterLso -Name $w -IPv4 -IPv6 -NoRestart -ErrorAction Stop; Restart-NetAdapter -Name $w -Confirm:$false -ErrorAction SilentlyContinue; Say-Ok ('LSO OFF em ' + $w) } catch { Say-Warn ('LSO em ' + $w + ': ' + $_.Exception.Message) }
    }
    return $true
}
function Undo-Lso {
    $list = @($script:HW.Nics | ForEach-Object { [string]$_.Name })
    if ($script:State.Other.ContainsKey('Lso')) { $list = @($script:State.Other['Lso']) }
    foreach ($w in $list) {
        if ($script:Dry) { Say-Dry ('Enable-NetAdapterLso ' + $w); continue }
        try { Enable-NetAdapterLso -Name $w -IPv4 -IPv6 -ErrorAction SilentlyContinue } catch { }
    }
    if (-not $script:Dry -and $script:State.Other.ContainsKey('Lso')) { $script:State.Other.Remove('Lso'); Save-State }
    Say-Ok 'LSO restaurado.'
    return $true
}

function Action-NetReset {
    Say '  Isto faz "netsh winsock reset" + "netsh int ip reset": limpa a pilha de rede. Precisa REINICIAR.' 'Yellow'
    if (-not (Confirm-Action 'Fazer o reset limpo agora?' $false)) { return $false }
    [void](Invoke-Native -File 'netsh' -ArgList @('winsock', 'reset'))
    [void](Invoke-Native -File 'netsh' -ArgList @('int', 'ip', 'reset'))
    Say-Ok 'Reset feito. REINICIE o PC.'
    return $true
}

function Register-NetTweaks {
    Add-Tweak @{ Id = 'nic'; Group = 'net'; Kind = 'action'; Level = 2; Evidence = 'media'; Tags = @('ALL')
        Name = 'Adaptador de rede: sem economia de energia / moderacao de interrupcao'
        Desc = 'Le as opcoes REAIS do seu driver (por palavra-chave, independe do idioma) e mostra o que vai mudar antes de aplicar: Ethernet -> EEE, Green Ethernet, Interrupt Moderation, Flow Control OFF. Wi-Fi -> economia de energia em "Desempenho maximo" e roaming no minimo. Guarda o valor antigo p/ desfazer.'
        Apply = { [void](Action-Nic) } }
    Add-Tweak @{ Id = 'nagle'; Group = 'net'; Level = 1; Evidence = 'fraca'
        Name = 'Nagle OFF + ACK imediato nas suas placas de rede'
        Desc = 'TcpNoDelay/TcpAckFrequency=1 so afetam TCP (login, party, chat). O gameplay do Fortnite e UDP, entao NAO muda tiro/build. Seguro e reversivel; aplicado so as placas fisicas ativas.'
        RegsFn = { Get-NagleRegs } }
    Add-Tweak @{ Id = 'throttle'; Group = 'net'; Level = 2; Evidence = 'fraca'
        Name = 'NetworkThrottlingIndex OFF (ffffffff)'
        Desc = 'Tira o limite de pacotes/s do MMCSS para multimidia. Guias de jogo recomendam, mas nao ha medicao confiavel de ganho no Fortnite. Inofensivo.'
        RegsFn = { Get-ThrottleRegs } }
    Add-Tweak @{ Id = 'qos'; Group = 'net'; Level = 2; Evidence = 'nenhuma'
        Name = 'QoS: reserva de banda 0% (NonBestEffortLimit=0)'
        Desc = 'HONESTO: a reserva de 20% so existe quando algum app usa QoS; na pratica e mito/placebo. Mantido por compatibilidade, inofensivo.'
        RegsFn = { Get-QosRegs } }
    Add-Tweak @{ Id = 'tcp'; Group = 'net'; Level = 2; Evidence = 'fraca'
        Name = 'Pilha TCP: autotuning normal, RSS on, ECN off, timestamps off'
        Desc = 'Configuracao saudavel e conservadora. Em geral o Windows ja vem assim; util p/ desfazer ajustes ruins de "otimizadores de internet". Guarda os valores atuais.'
        Check = { Check-Tcp }; Apply = { Apply-Tcp }; Undo = { Undo-Tcp } }
    Add-Tweak @{ Id = 'tunnels'; Group = 'net'; Level = 2; Evidence = 'fraca'
        Name = 'Desligar tuneis IPv6 legados (Teredo / 6to4 / ISATAP)'
        Desc = 'Menos trafego/DNS inesperado em segundo plano. Teredo desligado pode afetar alguns jogos P2P do Xbox/Microsoft Store; o Fortnite usa servidores da Epic e nao depende dele.'
        Check = { Check-Tunnels }; Apply = { Apply-Tunnels }; Undo = { Undo-Tunnels } }
    Add-Tweak @{ Id = 'lso'; Group = 'net'; Level = 2; Evidence = 'fraca'
        Name = 'Large Send Offload (LSO) OFF - REINICIA o adaptador'
        Desc = 'Alguns drivers Realtek/Intel geram picos com LSO. Desliga v4/v6 e reinicia o adaptador (queda de ~5 s). Nao entra no "Aplicar tudo" por causa da queda de rede.'
        NoBulk = $true
        Check = { Check-Lso }; Apply = { Apply-Lso }; Undo = { Undo-Lso } }
    Add-Tweak @{ Id = 'dns'; Group = 'net'; Kind = 'action'; Level = 1; Evidence = 'media'
        Name = 'DNS rapido (Cloudflare / Google / Quad9) ou voltar ao automatico'
        Desc = 'Acelera login, loja e matchmaking. NAO muda o ping dentro da partida. Guarda o DNS anterior de cada adaptador.'
        Apply = { [void](Action-Dns) } }
    Add-Tweak @{ Id = 'netreset'; Group = 'net'; Kind = 'action'; Level = 2; Evidence = '-'; Reboot = $true
        Name = 'Reset limpo da pilha de rede (winsock + IP)'
        Desc = 'Conserta rede corrompida por VPN/antivirus/otimizadores antigos. Precisa reiniciar. So use se estiver com problema.'
        Apply = { [void](Action-NetReset) } }
}

# =====================================================================
#  INTEGRACOES (winget) + GPU + FORTNITE + SISTEMA
# =====================================================================

# ---------------------------------------------------------------------
#  winget / programas
# ---------------------------------------------------------------------
function Invoke-Live {
    param([string]$File, [string[]]$ArgList = @())
    if ($script:Dry) { Say-Dry ($File + ' ' + ($ArgList -join ' ')); return 0 }
    try { & $File @ArgList | Out-Host; return [int]$LASTEXITCODE } catch { Say-Bad $_.Exception.Message; return -1 }
}
function Install-Winget {
    param([string]$Id)
    if (-not (Test-Cmd 'winget')) { Say-Warn 'winget nao encontrado (instale o "App Installer" na Microsoft Store).'; return $false }
    Say ('  winget install ' + $Id) 'DarkGray'
    $c = Invoke-Live -File 'winget' -ArgList @('install', '-e', '--id', $Id, '--accept-source-agreements', '--accept-package-agreements')
    if ($c -eq 0) { Say-Ok ('Instalado: ' + $Id); Write-Log ('winget install ' + $Id); return $true }
    Say-Warn ('winget retornou codigo ' + $c + ' (se ja estava instalado, ignore).')
    return $false
}
function Get-InstalledNames {
    if ($script:InstalledCache) { return $script:InstalledCache }
    $names = @()
    foreach ($p in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        try { $names += @(Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.DisplayName } | Where-Object { $_ }) } catch { }
    }
    $script:InstalledCache = $names
    return $names
}
function Find-AppExe {
    param([string]$ExeName, [string]$IdPrefix, [switch]$Quick)
    $roots = @()
    $pk = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if ($IdPrefix -and (Test-Path -LiteralPath $pk)) {
        foreach ($d in @(Get-ChildItem -LiteralPath $pk -Directory -Filter ($IdPrefix + '*') -ErrorAction SilentlyContinue)) { $roots += $d.FullName }
    }
    $roots += (Join-Path $script:ToolsDir '*')
    $roots += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links')
    if (-not $Quick) { $roots += $env:ProgramFiles; $roots += ${env:ProgramFiles(x86)} }
    foreach ($r in $roots) {
        if (-not $r) { continue }
        try {
            $hit = Get-ChildItem -Path $r -Filter $ExeName -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        } catch { }
    }
    return $null
}
$script:Apps = @(
    @{ Name = 'NVIDIA Profile Inspector'; Id = 'Orbmu2k.nvidiaProfileInspector'; Exe = 'nvidiaProfileInspector.exe'; Match = 'Profile Inspector'; Tags = @('NV')
       Desc = 'Edita os perfis do driver NVIDIA (o que o Painel de Controle esconde). O item "Perfil de baixa latencia" do menu NVIDIA usa a linha de comando dele (-silentImport) para aplicar tudo sem abrir nada. Codigo aberto (GitHub Orbmu2k).' },
    @{ Name = 'CapFrameX (medir FPS, frametime e latencia)'; Id = 'CXWorld.CapFrameX'; Exe = 'CapFrameX.exe'; Match = 'CapFrameX'; Tags = @('ALL')
       Desc = 'A ferramenta certa para PROVAR se um tweak ajudou: captura frametime, 1%/0.1% lows e (com PresentMon) latencia. Compare antes/depois; sem medir e placebo.' },
    @{ Name = 'LatencyMon (DPC/ISR)'; Id = 'Resplendence.LatencyMon'; Exe = 'LatMon.exe'; Match = 'LatencyMon'; Tags = @('ALL')
       Desc = 'Mostra qual driver causa picos de DPC/ISR (audio estalando, mouse pulando). Base para decidir sobre MSI Mode e drivers problematicos.' },
    @{ Name = 'ISLC (limpa a Standby List da RAM)'; Id = 'Wagnardsoft.ISLC'; Exe = 'ISLC.exe'; Match = 'standby list cleaner'; Tags = @('ALL')
       Desc = 'Esvazia a memoria "em espera" quando ela enche (evita hitch de alocacao). Config comum: lista 1024 MB, livre 1024 MB, timer 0,50 ms, polling 500 ms. So ajuda se voce enche a RAM (16 GB ou menos + navegador aberto).' },
    @{ Name = 'HWiNFO (temperaturas, clocks, sensores)'; Id = 'REALiX.HWiNFO'; Exe = 'HWiNFO64.exe'; Match = 'HWiNFO'; Tags = @('ALL')
       Desc = 'Confere se a CPU/GPU esta em thermal throttling depois de aplicar o plano de energia maximo.' },
    @{ Name = 'Process Lasso (regras de prioridade/afinidade)'; Id = 'BitSum.ProcessLasso'; Exe = 'ProcessLasso.exe'; Match = 'Process Lasso'; Tags = @('ALL')
       Desc = 'Prioridade e afinidade persistentes por programa. Em CPU Intel hibrida (12a gen+) ou Ryzen de 2 CCDs ajuda a prender o jogo nos nucleos certos. O EAC pode bloquear mudar o jogo com ele aberto; use as regras para os OUTROS apps.' },
    @{ Name = 'RivaTuner Statistics Server (limitador de FPS)'; Id = 'Guru3D.RTSS'; Exe = 'RTSS.exe'; Match = 'RivaTuner'; Tags = @('ALL')
       Desc = 'Limitador de FPS de menor variacao de frametime. O Fortnite ja tem limitador proprio + Reflex; RTSS e opcional e o overlay pode ser bloqueado pelo Easy Anti-Cheat. Use so se souber por que.' },
    @{ Name = 'MSI Afterburner (OC/undervolt/curva de ventoinha)'; Id = 'Guru3D.Afterburner'; Exe = 'MSIAfterburner.exe'; Match = 'Afterburner'; Tags = @('NV', 'AMD')
       Desc = 'Ajuste de clock/voltagem/ventoinha. Undervolt = menos calor e clocks mais estaveis (menos throttling).' },
    @{ Name = 'Display Driver Uninstaller (DDU)'; Id = 'Wagnardsoft.DisplayDriverUninstaller'; Exe = 'Display Driver Uninstaller.exe'; Match = 'Display Driver Uninstaller'; Tags = @('ALL')
       Desc = 'Remove o driver de video por completo (use no Modo Seguro) antes de instalar um novo. Resolve stutter/erros de driver quebrado ou trocado de marca NVIDIA/AMD/Intel.' },
    @{ Name = 'NVCleanstall (driver NVIDIA enxuto)'; Id = 'TechPowerUp.NVCleanstall'; Exe = 'NVCleanstall.exe'; Match = 'NVCleanstall'; Tags = @('NV')
       Desc = 'Instala o driver NVIDIA sem telemetria/extras que voce nao quer. Opcional.' },
    @{ Name = 'Custom Resolution Utility (CRU)'; Id = 'ToastyX.CustomResolutionUtility'; Exe = 'CRU.exe'; Match = 'Custom Resolution'; Tags = @('ALL')
       Desc = 'Cria resolucoes/Hz personalizadas (resolucao esticada de jogador pro). Depois use restart64.exe para reiniciar o driver.' },
    @{ Name = 'Sysinternals Autoruns (o que inicia com o Windows)'; Id = 'Microsoft.Sysinternals.Autoruns'; Exe = 'Autoruns64.exe'; Match = 'Autoruns'; Tags = @('ALL')
       Desc = 'Lista TUDO que inicia com o Windows (mais completo que o Gerenciador de Tarefas).' },
    @{ Name = 'CrystalDiskInfo (saude do SSD/HD)'; Id = 'CrystalDewWorld.CrystalDiskInfo'; Exe = 'DiskInfo64.exe'; Match = 'CrystalDiskInfo'; Tags = @('ALL')
       Desc = 'Verifica a saude do disco onde o Fortnite esta instalado.' },
    @{ Name = 'O&O ShutUp10++ (privacidade/telemetria)'; Id = 'OO-Software.ShutUp10'; Exe = 'OOSU10.exe'; Match = 'ShutUp10'; Tags = @('ALL')
       Desc = 'Mexe em MUITAS configuracoes de privacidade do Windows. Ganho de FPS desprezivel; use so por privacidade e crie o ponto de restauracao por ele.' }
)
function Menu-Apps {
    $script:InstalledCache = $null
    $names = Get-InstalledNames
    while ($true) {
        $items = @()
        foreach ($a in $script:Apps) {
            $inst = $false
            foreach ($n in $names) { if ($n -match [regex]::Escape($a.Match)) { $inst = $true; break } }
            if (-not $inst) { if (Find-AppExe -ExeName $a.Exe -IdPrefix $a.Id -Quick) { $inst = $true } }
            $st = 'OFF'; if ($inst) { $st = 'ON' }
            $na = -not (Test-Applicable $a.Tags)
            $lbl = $a.Name
            if ($inst) { $lbl = $lbl + '  (instalado)' }
            $items += @{ Label = $lbl; Desc = ($a.Desc + '  [winget: ' + $a.Id + ']'); Badges = (Get-TagBadges $a.Tags); State = $st; Na = $na; App = $a }
        }
        $items += @{ Label = 'Voltar'; Desc = ''; Badges = @() }
        $i = Show-Menu -Title 'PROGRAMAS E INTEGRACOES (winget)' -Sub 'Instala/abre direto por aqui. So programas oficiais; nada e instalado sem voce escolher.' -Items $items -Art 'apps'
        if ($i -lt 0 -or $i -ge $script:Apps.Count) { return }
        $a = $script:Apps[$i]
        $exe = Find-AppExe -ExeName $a.Exe -IdPrefix $a.Id
        $opts = @('Instalar / atualizar via winget')
        if ($exe) { $opts += 'Abrir o programa' }
        $opts += 'Voltar'
        $j = Select-Option -Title $a.Name -Options $opts -Descs @($a.Desc) -Sub ('winget id: ' + $a.Id)
        if ($j -eq 0) { [void](Install-Winget $a.Id); $script:InstalledCache = $null; $names = Get-InstalledNames; Pause-Key }
        elseif ($j -eq 1 -and $exe) {
            if ($script:Dry) { Say-Dry ('abrir ' + $exe) } else { try { Start-Process -FilePath $exe } catch { Say-Bad $_.Exception.Message; Pause-Key } }
        }
    }
}

# ---------------------------------------------------------------------
#  NVIDIA
# ---------------------------------------------------------------------
function Get-NvSmi {
    $c = Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}
function Action-NvOverlay {
    foreach ($p in @('NVIDIA Share', 'nvsphelper64', 'NVIDIA Overlay', 'NVIDIA Web Helper')) {
        if ($script:Dry) { Say-Dry ('encerrar ' + $p); continue }
        Get-Process -Name $p -ErrorAction SilentlyContinue | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { } }
    }
    $rk = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    $k = Open-RegKey -P $rk
    $n = 0
    if ($k) {
        foreach ($name in $k.GetValueNames()) {
            if ($name -match 'NVIDIA') { [void](Remove-RegValue -P $rk -N $name); Say-Ok ('Removido do autostart: ' + $name); $n++ }
        }
        $k.Close()
    }
    if ($n -eq 0) { Say-Info 'Nenhuma entrada NVIDIA no autostart do usuario.' }
    Save-State
    Say ''
    Say '  Para desligar o overlay/gravacao de vez (o proprio app controla):' 'White'
    Say '   App NVIDIA > Configuracoes > Overlay do jogo = OFF  (e Instant Replay / ShadowPlay = OFF)' 'Gray'
    Say '   Custo do overlay/Instant Replay ligado: alguns % de FPS e uma fila de captura a mais.' 'Gray'
    return $true
}
function Find-NpiExe { return (Find-AppExe -ExeName 'nvidiaProfileInspector.exe' -IdPrefix 'Orbmu2k.nvidiaProfileInspector') }
function Get-NpiSettings {
    return @(
        @{ Name = 'Power management mode';            Id = 0x1057EB71; Val = 1;    Why = 'Prefer maximum performance: GPU nao desce de clock durante o jogo.' },
        @{ Name = 'Maximum pre-rendered frames';      Id = 0x007BA09E; Val = 1;    Why = 'Fila de quadros CPU->GPU = 1 (menos latencia).' },
        @{ Name = 'Ultra Low Latency - Enabled';      Id = 0x10835000; Val = 1;    Why = 'Liga o caminho Ultra Low Latency do driver. (Com Reflex ligado no jogo, o Reflex assume.)' },
        @{ Name = 'Ultra Low Latency - CPL State';    Id = 0x0005F543; Val = 2;    Why = 'Faz o Painel NVIDIA mostrar "Ultra".' },
        @{ Name = 'Texture Filtering - Quality';      Id = 0x00CE2691; Val = 0x14; Why = 'High performance (menos custo de textura; diferenca visual minima).' },
        @{ Name = 'Preferred refresh rate';           Id = 0x0064B541; Val = 1;    Why = 'Highest available: garante o maior Hz da tela.' }
    )
}
function New-NipXml {
    param($Settings)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-16"?>')
    [void]$sb.AppendLine('<ArrayOfProfile>')
    [void]$sb.AppendLine('  <Profile>')
    [void]$sb.AppendLine('    <ProfileName>Fortnite</ProfileName>')
    [void]$sb.AppendLine('    <Executeables>')
    [void]$sb.AppendLine('      <string>fortniteclient-win64-shipping.exe</string>')
    [void]$sb.AppendLine('    </Executeables>')
    [void]$sb.AppendLine('    <Settings>')
    foreach ($s in $Settings) {
        [void]$sb.AppendLine('      <ProfileSetting>')
        [void]$sb.AppendLine('        <SettingNameInfo>' + [Security.SecurityElement]::Escape([string]$s.Name) + '</SettingNameInfo>')
        [void]$sb.AppendLine('        <SettingID>' + ([uint32]$s.Id) + '</SettingID>')
        [void]$sb.AppendLine('        <SettingValue>' + ([uint32]$s.Val) + '</SettingValue>')
        [void]$sb.AppendLine('        <ValueType>Dword</ValueType>')
        [void]$sb.AppendLine('      </ProfileSetting>')
    }
    [void]$sb.AppendLine('    </Settings>')
    [void]$sb.AppendLine('  </Profile>')
    [void]$sb.AppendLine('</ArrayOfProfile>')
    return $sb.ToString()
}
function Action-NvProfile {
    $set = Get-NpiSettings
    Say '  Vai gravar no perfil "Fortnite" do driver NVIDIA (IDs conferidos no codigo-fonte do Profile Inspector):' 'White'
    foreach ($s in $set) { Say ('   - {0} = {1}   ({2})' -f $s.Name, $s.Val, $s.Why) 'Gray' }
    Say '  Nao mexe em VSync/G-Sync (deixe o Fortnite controlar). So afeta o Fortnite, nao o perfil global.' 'DarkGray'
    $exe = Find-NpiExe
    if (-not $exe) {
        if (-not (Confirm-Action 'NVIDIA Profile Inspector nao esta instalado. Instalar agora via winget (Orbmu2k.nvidiaProfileInspector)?' $true)) { return $false }
        [void](Install-Winget 'Orbmu2k.nvidiaProfileInspector')
        $exe = Find-NpiExe
        if (-not $exe -and -not $script:Dry) { Say-Bad 'Nao achei o nvidiaProfileInspector.exe apos instalar. Abra o menu Programas e tente de novo.'; return $false }
    }
    if (-not (Confirm-Action 'Aplicar o perfil de baixa latencia (com backup dos perfis atuais)?' $true)) { return $false }
    $nip = Join-Path $script:ToolsDir 'Fortnite_baixa_latencia.nip'
    if ($script:Dry) {
        Say-Dry ('"' + $exe + '" -exportCustomized   (backup)')
        Say-Dry ('gravar ' + $nip + ' e importar: -silentImport')
        return $true
    }
    try {
        if (-not (Test-Path -LiteralPath $script:ToolsDir)) { [void](New-Item -ItemType Directory -Force -Path $script:ToolsDir) }
        $dir = Split-Path -Parent $exe
        $before = @(Get-ChildItem -LiteralPath $dir -Filter '*.nip' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $p = Start-Process -FilePath $exe -ArgumentList '-exportCustomized' -PassThru -WindowStyle Hidden
        if (-not $p.WaitForExit(45000)) { try { $p.Kill() } catch { } }
        $after = @(Get-ChildItem -LiteralPath $dir -Filter '*.nip' -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.FullName })
        foreach ($f in $after) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $script:BackupDir ('nvidia_perfis_backup_' + $f.Name)) -Force; Say-Ok ('Backup dos perfis: ' + $f.Name) }
        if ($after.Count -eq 0) { Say-Warn 'Nenhum perfil customizado para exportar (normal em instalacao limpa).' }
        [IO.File]::WriteAllText($nip, (New-NipXml $set), [Text.Encoding]::Unicode)
        $p2 = Start-Process -FilePath $exe -ArgumentList @('-silentImport', ('"' + $nip + '"')) -PassThru -WindowStyle Hidden
        if (-not $p2.WaitForExit(60000)) { Say-Warn 'O Profile Inspector demorou; conferindo mesmo assim.'; try { $p2.Kill() } catch { } }
        Say-Ok 'Perfil importado no driver.'
        Write-Log 'NVIDIA: perfil Fortnite importado via NPI'
        Say ''
        Say '  Confira: abra o NVIDIA Profile Inspector, digite "Fortnite" no campo de perfil.' 'Gray'
        Say '  Desfazer: no Profile Inspector, perfil Fortnite > botao "restaurar perfil aos padroes".' 'Gray'
        return $true
    } catch { Say-Bad $_.Exception.Message; return $false }
}
function Action-NvClocks {
    $smi = Get-NvSmi
    if (-not $smi) { Say-Warn 'nvidia-smi nao encontrado (driver NVIDIA instalado?).'; return $false }
    $i = Select-Option -Title 'CLOCK DA GPU (nvidia-smi)' -Sub 'Vale so ate reiniciar. GTX 16 / RTX suportam.' -Options @('Travar faixa 75%-100% do boost maximo', 'Liberar (voltar ao automatico)') -Descs @(
        'A GPU nunca desce abaixo de ~75% do clock maximo: some o atraso de "acordar" a GPU entre cenas leves e pesadas. Custo: mais calor/consumo em idle enquanto travado. Equivale a "Prefer maximum performance" mas mais rigido.',
        'Executa nvidia-smi -rgc.')
    if ($i -lt 0) { return $false }
    if ($i -eq 1) { $r = Invoke-Native -File $smi -ArgList @('-i', '0', '-rgc'); if ($r.Dry -or $r.ExitCode -eq 0) { Say-Ok 'Clock liberado.' } else { Say-Bad $r.Output.Trim() }; return $true }
    $mx = (Invoke-Native -File $smi -ArgList @('-i', '0', '--query-gpu=clocks.max.graphics', '--format=csv,noheader,nounits') -Read).Output.Trim()
    $max = 0
    if (-not [int]::TryParse(($mx -split "`n")[0].Trim(), [ref]$max) -or $max -le 0) { Say-Bad ('Nao consegui ler o clock maximo: ' + $mx); return $false }
    $sup = (Invoke-Native -File $smi -ArgList @('-i', '0', '--query-supported-clocks=gr', '--format=csv,noheader,nounits') -Read).Output
    $target = [int]($max * 0.75)
    $min = $max
    foreach ($l in ($sup -split "`n")) { $v = 0; if ([int]::TryParse($l.Trim(), [ref]$v) -and $v -ge $target -and $v -lt $min) { $min = $v } }
    if (-not (Confirm-Action ('Travar clock da GPU em {0}-{1} MHz ate reiniciar?' -f $min, $max) $true)) { return $false }
    $r = Invoke-Native -File $smi -ArgList @('-i', '0', '-lgc', ('{0},{1}' -f $min, $max))
    if ($r.Dry) { return $true }
    if ($r.ExitCode -eq 0) { $script:State.Other['NvClocks'] = $true; Save-State; Say-Ok ('GPU travada em {0}-{1} MHz. Reiniciar ou "Liberar" desfaz.' -f $min, $max); Write-Log ('nvidia-smi -lgc {0},{1}' -f $min, $max); return $true }
    Say-Bad ('nvidia-smi recusou: ' + $r.Output.Trim())
    return $false
}

function Register-GpuTweaks {
    Add-Tweak @{ Id = 'nv_profile'; Group = 'gpu'; Kind = 'action'; Level = 2; Evidence = 'media'; Tags = @('NV')
        Name = 'Perfil de BAIXA LATENCIA do Fortnite no driver (via Profile Inspector)'
        Desc = 'Integracao real: instala (winget) e comanda o NVIDIA Profile Inspector pela linha de comando, faz backup dos perfis e importa um perfil so do Fortnite: Prefer max performance, pre-rendered frames=1, Ultra Low Latency, filtro de textura High performance, Hz maximo. Se voce liga o NVIDIA Reflex no jogo, o Reflex assume a fila (recomendado).'
        Apply = { [void](Action-NvProfile) } }
    Add-Tweak @{ Id = 'nv_overlay'; Group = 'gpu'; Kind = 'action'; Level = 2; Evidence = 'media'; Tags = @('NV')
        Name = 'NVIDIA: fechar Share/Overlay e tirar do autostart'
        Desc = 'ShadowPlay/Instant Replay/overlay gravando em segundo plano custam alguns % de FPS e uma fila extra. Encerra os processos, remove entradas NVIDIA do autostart (com backup) e mostra onde desligar no app NVIDIA.'
        Apply = { [void](Action-NvOverlay) } }
    Add-Tweak @{ Id = 'nv_clocks'; Group = 'gpu'; Kind = 'action'; Level = 3; Evidence = 'fraca'; Tags = @('NV')
        Name = 'Travar faixa de clock da GPU (nvidia-smi -lgc) - ate reiniciar'
        Desc = 'Elimina a rampa de clock da GPU (P8 -> P0). Mais calor/consumo enquanto travado. Some no reboot. Uso avancado.'
        Apply = { [void](Action-NvClocks) } }
}

# ---------------------------------------------------------------------
#  FORTNITE: INI
# ---------------------------------------------------------------------
function Read-IniFile {
    param([string]$Path)
    $b = [IO.File]::ReadAllBytes($Path)
    if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { $enc = [Text.Encoding]::Unicode }
    else { $enc = New-Object Text.UTF8Encoding($false) }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([IO.File]::ReadAllLines($Path, $enc))
    return @{ Path = $Path; Enc = $enc; Lines = $lines; Changes = @() }
}
function Set-IniKey {
    param($Ini, [string]$Sec, [string]$Key, [string]$Val, [bool]$Add)
    $L = $Ini.Lines
    $cur = ''; $found = $false; $secIdx = -1
    for ($i = 0; $i -lt $L.Count; $i++) {
        $ln = $L[$i].Trim()
        if ($ln -match '^\[(.+)\]$') { $cur = $Matches[1]; if ($cur -eq $Sec) { $secIdx = $i }; continue }
        if ($cur -eq $Sec -and $ln.StartsWith($Key + '=', [StringComparison]::OrdinalIgnoreCase)) {
            $found = $true
            $old = $ln.Substring($Key.Length + 1)
            if ($old -ne $Val) { $L[$i] = $Key + '=' + $Val; $Ini.Changes += ('{0}: {1} -> {2}' -f $Key, $old, $Val) }
        }
    }
    if ($found -or -not $Add) { return }
    if ($secIdx -ge 0) { $L.Insert($secIdx + 1, $Key + '=' + $Val) } else { $L.Add('[' + $Sec + ']'); $L.Add($Key + '=' + $Val) }
    $Ini.Changes += ('{0}: (novo) {1}' -f $Key, $Val)
}
function Remove-IniKey {
    param($Ini, [string]$Sec, [string]$Key)
    $L = $Ini.Lines
    $cur = ''
    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($raw in $L) {
        $ln = $raw.Trim()
        if ($ln -match '^\[(.+)\]$') { $cur = $Matches[1]; $out.Add($raw); continue }
        if ($cur -eq $Sec -and $ln.StartsWith($Key + '=', [StringComparison]::OrdinalIgnoreCase)) { $Ini.Changes += ('{0}: removido' -f $Key); continue }
        $out.Add($raw)
    }
    $Ini.Lines = $out
}
function Save-IniFile {
    param($Ini)
    if ($script:Dry) { Say-Dry ('gravar ' + $Ini.Path + ' (' + $Ini.Changes.Count + ' alteracoes)'); return $true }
    try {
        if ((Get-Item -LiteralPath $Ini.Path).IsReadOnly) { Say-Bad 'O INI esta somente-leitura (congelado). Libere em Fortnite > Congelar/liberar INI.'; return $false }
        [IO.File]::WriteAllLines($Ini.Path, $Ini.Lines, $Ini.Enc)
        return $true
    } catch { Say-Bad ('Nao salvou o INI (Fortnite aberto?): ' + $_.Exception.Message); return $false }
}
function Test-FortniteRunning { return [bool](Get-Process -Name 'FortniteClient-Win64-Shipping' -ErrorAction SilentlyContinue) }
function Apply-FnIni {
    param([int]$Fps)
    $path = $script:HW.Fn.Ini
    $ini = Read-IniFile $path
    $m = '/Script/FortniteGame.FortGameUserSettings'
    $fpsTxt = ('{0}.000000' -f $Fps)
    $main = @(
        @('bUseVSync', 'False'), @('bShowFPS', 'True'), @('bMotionBlur', 'False'), @('bShowGrass', 'False'),
        @('FrameRateLimit', $fpsTxt), @('FortAntiAliasingMethod', 'Disabled'), @('bRayTracing', 'False'), @('bUseNanite', 'False'),
        @('bEnableDLSSFrameGeneration', 'False'),
        @('DesiredGlobalIlluminationQuality', '0'), @('DesiredReflectionQuality', '0'),
        @('PreNaniteGlobalIlluminationQuality', '0'), @('PreNaniteReflectionQuality', '0'),
        @('FullscreenMode', '0'), @('LastConfirmedFullscreenMode', '0'), @('PreferredFullscreenMode', '0'))
    foreach ($kv in $main) { Set-IniKey $ini $m $kv[0] $kv[1] $false }
    foreach ($q in @('sg.TextureQuality', 'sg.ShadowQuality', 'sg.EffectsQuality', 'sg.PostProcessQuality', 'sg.AntiAliasingQuality')) { Set-IniKey $ini 'ScalabilityGroups' $q '0' $true }
    Set-IniKey $ini 'ScalabilityGroups' 'sg.GlobalIlluminationQuality' '0' $false
    Set-IniKey $ini 'ScalabilityGroups' 'sg.ReflectionQuality' '0' $false
    Set-IniKey $ini 'PerformanceMode' 'MeshQuality' '0' $false
    return $ini
}
function Action-FnIni {
    $path = $script:HW.Fn.Ini
    if (-not (Test-Path -LiteralPath $path)) { Say-Bad 'GameUserSettings.ini nao encontrado. Abra o Fortnite 1x, entre numa partida, feche e tente de novo.'; return $false }
    if (Test-FortniteRunning) { Say-Warn 'O Fortnite esta ABERTO: ele sobrescreve o INI ao fechar. Feche o jogo antes.'; if (-not (Confirm-Action 'Continuar mesmo assim?' $false)) { return $false } }
    $hz = [int]$script:HW.Display.Hz
    $opts = @('Ilimitado (0)  - maximo FPS, com Reflex controla a fila')
    $vals = @(0)
    if ($hz -gt 0) { $opts += ('Igual ao Hz do monitor ({0})' -f $hz); $vals += $hz; $opts += ('Hz - 3 ({0})  - p/ G-Sync/FreeSync sem tearing' -f ($hz - 3)); $vals += ($hz - 3) }
    $j = Select-Option -Title 'LIMITE DE FPS' -Sub 'Preset Performance: VSync OFF, tudo Low, sem Nanite/RT/blur, tela cheia exclusiva. A resolucao atual e preservada.' -Options $opts -Descs @(
        'Bom quando a CPU nao alcanca o Hz do monitor. Se a GPU ficar em 95-100%, ligue o Reflex no jogo.',
        'Frametime mais estavel se o PC passa folgado do Hz.',
        'Cap logo abaixo do Hz mantem o VRR (G-Sync/FreeSync) ativo sem tearing.')
    if ($j -lt 0) { return $false }
    if (-not (Confirm-Action 'Aplicar o preset de performance no GameUserSettings.ini (com backup)?' $true)) { return $false }
    New-Backup-Copy $path 'GameUserSettings'
    $ini = Apply-FnIni -Fps $vals[$j]
    if ($ini.Changes.Count -eq 0) { Say-Ok 'O INI ja estava com estes valores.'; return $true }
    Say ('  {0} chave(s) alterada(s):' -f $ini.Changes.Count) 'White'
    foreach ($c in $ini.Changes) { Say ('   ' + $c) 'Gray' }
    if (Save-IniFile $ini) {
        Say-Ok 'INI atualizado.'
        Say-Info 'No jogo: Video > Modo de renderizacao = Desempenho (reinicia o jogo) e NVIDIA Reflex = Ligado + Impulso (se tiver).'
        Write-Log 'Fortnite INI performance'
        return $true
    }
    return $false
}
function Check-FnEngine {
    $p = $script:HW.Fn.EngineIni
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    return [bool](Select-String -LiteralPath $p -Pattern 'r.GTSyncType' -Quiet -ErrorAction SilentlyContinue)
}
function Apply-FnEngine {
    $p = $script:HW.Fn.EngineIni
    if (-not (Test-Path -LiteralPath $p)) {
        if ($script:Dry) { Say-Dry ('criar ' + $p) } else { try { [IO.File]::WriteAllText($p, '', (New-Object Text.UTF8Encoding($false))) } catch { Say-Bad $_.Exception.Message; return $false } }
    }
    if (-not $script:Dry) { New-Backup-Copy $p 'Engine' }
    $ini = if ($script:Dry -and -not (Test-Path -LiteralPath $p)) { @{ Path = $p; Enc = (New-Object Text.UTF8Encoding($false)); Lines = (New-Object 'System.Collections.Generic.List[string]'); Changes = @() } } else { Read-IniFile $p }
    Set-IniKey $ini 'SystemSettings' 'r.OneFrameThreadLag' '1' $true
    Set-IniKey $ini 'SystemSettings' 'r.GTSyncType' '1' $true
    Set-IniKey $ini 'SystemSettings' 'r.FinishCurrentFrame' '0' $true
    Set-IniKey $ini '/Script/Engine.GarbageCollectionSettings' 'TimeBetweenPurgingPendingKillObjects' '60' $true
    foreach ($c in $ini.Changes) { Say ('   ' + $c) 'Gray' }
    return (Save-IniFile $ini)
}
function Undo-FnEngine {
    $p = $script:HW.Fn.EngineIni
    if (-not (Test-Path -LiteralPath $p)) { return $true }
    $ini = Read-IniFile $p
    foreach ($k in @('r.OneFrameThreadLag', 'r.GTSyncType', 'r.FinishCurrentFrame')) { Remove-IniKey $ini 'SystemSettings' $k }
    Remove-IniKey $ini '/Script/Engine.GarbageCollectionSettings' 'TimeBetweenPurgingPendingKillObjects'
    if (Save-IniFile $ini) { Say-Ok 'Engine.ini: chaves removidas.'; return $true }
    return $false
}
function Check-FnFrozen {
    $p = $script:HW.Fn.Ini
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    return [bool](Get-Item -LiteralPath $p).IsReadOnly
}
function Apply-FnFreeze {
    foreach ($p in @($script:HW.Fn.Ini, $script:HW.Fn.EngineIni)) {
        if (Test-Path -LiteralPath $p) { if ($script:Dry) { Say-Dry ('somente-leitura ' + $p) } else { Set-ItemProperty -LiteralPath $p -Name IsReadOnly -Value $true } }
    }
    Say-Ok 'INIs congelados. Para mudar opcoes no jogo, libere antes (Desfazer).'
    return $true
}
function Undo-FnFreeze {
    foreach ($p in @($script:HW.Fn.Ini, $script:HW.Fn.EngineIni)) {
        if (Test-Path -LiteralPath $p) { if ($script:Dry) { Say-Dry ('liberar ' + $p) } else { Set-ItemProperty -LiteralPath $p -Name IsReadOnly -Value $false } }
    }
    Say-Ok 'INIs liberados.'
    return $true
}

# ---------------------------------------------------------------------
#  FORTNITE: lancador, foco, replays, resolucao
# ---------------------------------------------------------------------
function Get-EpicLauncher {
    foreach ($b in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $b) { continue }
        $p = Join-Path $b 'Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}
function Get-FortniteLaunchUri {
    $ns = 'fn'; $item = '4fe75bbc5a674f4f9b356b5c90567da5'; $app = 'Fortnite'
    try {
        $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.item' -ErrorAction SilentlyContinue)) {
            $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            if ($j.AppName -eq 'Fortnite' -and $j.CatalogNamespace -and $j.CatalogItemId) { $ns = [string]$j.CatalogNamespace; $item = [string]$j.CatalogItemId; $app = [string]$j.AppName; break }
        }
    } catch { }
    return ('com.epicgames.launcher://apps/{0}%3A{1}%3A{2}?action=launch&silent=true' -f $ns, $item, $app)
}
function Action-FnLaunch {
    $i = Select-Option -Title 'LAUNCH OPTIONS (Epic Launcher)' -Sub 'Onde colar: Launcher > foto do perfil > Configuracoes > Fortnite > Argumentos de linha de comando adicionais.' -Options @(
        '-NOSPLASH   (seguro)', '-NOSPLASH -USEALLAVAILABLECORES   (comunidade)', 'Limpar (deixar em branco)') -Descs @(
        'So pula o video de abertura. Zero risco. Escolha de renderizacao (DX12/Desempenho) se faz DENTRO do jogo, nao aqui.',
        '-USEALLAVAILABLECORES e argumento da comunidade Unreal: efeito NAO comprovado no Fortnite atual. Inofensivo. Removi -malloc=system (pode piorar) e -NOTEXTURESTREAMING (estoura VRAM em GPU de 4-6 GB) das versoes antigas deste script.',
        'Copia texto vazio.')
    if ($i -lt 0) { return $false }
    $txt = @('-NOSPLASH', '-NOSPLASH -USEALLAVAILABLECORES', '')[$i]
    if ($script:Dry) { Say-Dry ('clipboard: ' + $txt) } else { try { Set-Clipboard -Value $txt; Say-Ok ('Copiado para a area de transferencia: "' + $txt + '"') } catch { Say-Warn 'Nao consegui copiar; digite manualmente.' } }
    $l = Get-EpicLauncher
    if ($l -and (Confirm-Action 'Abrir o Epic Launcher agora?' $true)) { if (-not $script:Dry) { Start-Process -FilePath $l } }
    return $true
}
function Action-FnFocus {
    $drains = @('Discord', 'chrome', 'Spotify', 'msedge', 'Teams', 'ms-teams', 'OneDrive', 'Steam', 'EpicWebHelper')
    $run = @()
    foreach ($d in $drains) { $ps = @(Get-Process -Name $d -ErrorAction SilentlyContinue); if ($ps.Count -gt 0) { $run += $d } }
    if ($run.Count -gt 0) {
        Say ('  Programas abertos que roubam CPU/GPU: ' + ($run -join ', ')) 'White'
        Say '  ATENCAO: Chrome/Edge fecham (abas voltam ao reabrir, mas formularios e downloads em andamento se perdem).' 'Yellow'
        if (Confirm-Action 'Fechar esses programas agora?' $false) {
            if ($script:Dry) { Say-Dry ('encerrar ' + ($run -join ', ')) }
            else {
                foreach ($d in $run) { Get-Process -Name $d -ErrorAction SilentlyContinue | ForEach-Object { try { [void]$_.CloseMainWindow() } catch { } } }
                Start-Sleep -Seconds 4
                foreach ($d in $run) { Get-Process -Name $d -ErrorAction SilentlyContinue | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { } } }
                Say-Ok 'Programas fechados.'
            }
        }
    } else { Say-Ok 'Nenhum dreno conhecido aberto.' }
    if (-not (Confirm-Action 'Abrir o Fortnite agora pelo Epic Launcher?' $true)) { return $true }
    $uri = Get-FortniteLaunchUri
    if ($script:Dry) { Say-Dry ('abrir ' + $uri); return $true }
    try { Start-Process $uri } catch { Say-Bad ('Nao consegui abrir o launcher: ' + $_.Exception.Message); return $false }
    Say '  Aguardando o processo do jogo (ate 120 s)...' 'DarkGray'
    $p = $null
    for ($t = 0; $t -lt 60 -and -not $p; $t++) { Start-Sleep -Seconds 2; $p = Get-Process -Name 'FortniteClient-Win64-Shipping' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $p) { Say-Warn 'O jogo ainda nao abriu (login/atualizacao?). Se voce aplicou "Prioridade ALTA fixa", ela vale quando abrir.'; return $true }
    try { $p.PriorityClass = 'High'; Say-Ok 'Prioridade High aplicada ao Fortnite.' } catch { Say-Info 'O Easy Anti-Cheat nao deixa mudar a prioridade de fora (normal). Use "Prioridade ALTA fixa" no menu Windows.' }
    return $true
}
function Action-FnReplays {
    Say '  A gravacao de replay se desliga NO JOGO: Configuracoes > Jogo > Replays > Gravar replays = DESLIGADO.' 'White'
    $demos = Join-Path $env:LOCALAPPDATA 'FortniteGame\Saved\Demos'
    $files = @(Get-ChildItem -LiteralPath $demos -Filter '*.replay' -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { Say-Info 'Nao ha replays salvos.'; return $true }
    $mb = [math]::Round((($files | Measure-Object Length -Sum).Sum) / 1MB, 0)
    if (-not (Confirm-Action ('Apagar {0} replay(s) antigo(s) ({1} MB)? Isso NAO da p/ desfazer.' -f $files.Count, $mb) $false 'Red')) { return $true }
    if ($script:Dry) { Say-Dry ('apagar ' + $files.Count + ' replays'); return $true }
    foreach ($f in $files) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    Say-Ok 'Replays apagados.'
    return $true
}
function Action-FnVerify {
    Say '  No Epic Launcher: Biblioteca > Fortnite > ... > Gerenciar > Verificar. Arquivo corrompido = crash/stutter.' 'White'
    $l = Get-EpicLauncher
    if ($l -and (Confirm-Action 'Abrir o Epic Launcher?' $true)) { if (-not $script:Dry) { Start-Process -FilePath $l } }
    if (Test-Path -LiteralPath $script:HW.Fn.ConfigDir) { if (Confirm-Action 'Abrir a pasta de configuracoes do Fortnite?' $false) { if (-not $script:Dry) { Start-Process explorer.exe $script:HW.Fn.ConfigDir } } }
    return $true
}

# --- resolucao esticada ---------------------------------------------------
function Get-NativeFile { return (Join-Path $script:BackupDir 'display_native.txt') }
function Save-NativeDisplay {
    $f = Get-NativeFile
    if (Test-Path -LiteralPath $f) { return }
    Detect-Display
    $d = $script:HW.Display
    if ($d.W -le 0) { return }
    if ($script:Dry) { Say-Dry ('salvar nativa {0}x{1}@{2}' -f $d.W, $d.H, $d.Hz); return }
    Set-Content -LiteralPath $f -Value ('{0} {1} {2}' -f $d.W, $d.H, $d.Hz) -Encoding ASCII
    Say-Ok ('Resolucao nativa salva: {0}x{1} @ {2} Hz' -f $d.W, $d.H, $d.Hz)
}
function Sync-FnResolution {
    param([int]$W, [int]$H)
    $path = $script:HW.Fn.Ini
    if (-not (Test-Path -LiteralPath $path)) { Say-Warn 'GameUserSettings.ini nao achado (abra o Fortnite 1x). Windows ja trocado.'; return $false }
    New-Backup-Copy $path 'GameUserSettings'
    $ini = Read-IniFile $path
    $m = '/Script/FortniteGame.FortGameUserSettings'
    foreach ($k in @('ResolutionSizeX', 'LastUserConfirmedResolutionSizeX', 'DesiredScreenWidth', 'LastUserConfirmedDesiredScreenWidth')) { Set-IniKey $ini $m $k ([string]$W) $false }
    foreach ($k in @('ResolutionSizeY', 'LastUserConfirmedResolutionSizeY', 'DesiredScreenHeight', 'LastUserConfirmedDesiredScreenHeight')) { Set-IniKey $ini $m $k ([string]$H) $false }
    foreach ($k in @('FullscreenMode', 'LastConfirmedFullscreenMode', 'PreferredFullscreenMode')) { Set-IniKey $ini $m $k '0' $false }
    if (Save-IniFile $ini) { Say-Ok ('Fortnite INI em {0}x{1} (tela cheia exclusiva).' -f $W, $H); return $true }
    return $false
}
function Show-ScalingHelp {
    $l = @('#Escala da imagem (para a resolucao esticada preencher a tela sem barras pretas)')
    if (Test-Tag 'NV') { $l += @('', '#NVIDIA', 'Painel de Controle NVIDIA > Ajustar tamanho e posicao da area de trabalho > Escala: TELA CHEIA, Executar escala em: GPU, marque "Substituir o modo de escala definido por jogos e programas". Aplicar.', 'Criar o modo: Alterar resolucao > Personalizar > Criar resolucao personalizada.') }
    if (Test-Tag 'AMD') { $l += @('', '#AMD', 'AMD Software > Configuracoes > Tela: GPU Scaling = LIGADO, Scaling Mode = Full Panel (painel cheio). Resolucoes personalizadas na mesma aba.') }
    if (Test-Tag 'INTELGPU') { $l += @('', '#Intel', 'Intel Graphics Software > Sistema > Tela > Escala = TELA CHEIA e marque substituir configuracoes do aplicativo.') }
    $l += @('', '#Monitor', 'No menu OSD do monitor: escala = CHEIA/FULL (nao "Aspecto"/"1:1").', '', '#Fortnite', 'Modo de janela = Tela cheia (exclusivo), nao "Tela cheia em janela".')
    Show-Text 'ESCALA / ESTICAR RESOLUCAO' $l
}
function Menu-StretchRes {
    while ($true) {
        Detect-Display
        $d = $script:HW.Display
        $items = @()
        foreach ($w in @(1440, 1650, 1680, 1720, 1750)) {
            $extra = ''
            if ($w -eq 1720) { $extra = ' (a do Peterbot; boa p/ comecar)' }
            if ($w -eq 1440) { $extra = ' (classica 4:3 - modelos mais largos)' }
            $items += @{ Label = ('Preset {0}x1080{1}' -f $w, $extra); Desc = 'Menos pixels = mais FPS e modelos mais largos; custo: imagem mais borrada e menos visao lateral. Windows E Fortnite mudam juntos p/ nao dar conflito. Se o modo nao existir no driver, o script explica como criar (CRU / painel da GPU). Presets sao para monitor 1080p.'; Badges = @(); W = $w }
        }
        $items += @{ Label = 'Reverter para a resolucao nativa (Windows + Fortnite)'; Desc = 'Usa a nativa salva na 1a vez que voce aplicou um preset.'; Badges = @() }
        $items += @{ Label = 'Tela ficou quadrada / barras pretas? (como esticar)'; Desc = 'Guia de escala por marca de GPU.'; Badges = @() }
        $items += @{ Label = 'Abrir CRU (instala via winget se faltar)'; Desc = 'Custom Resolution Utility do ToastyX.'; Badges = @() }
        $items += @{ Label = 'Voltar'; Desc = ''; Badges = @() }
        $i = Show-Menu -Title 'RESOLUCOES ESTICADAS' -Sub ('Agora: {0}x{1} @ {2} Hz' -f $d.W, $d.H, $d.Hz) -Items $items
        if ($i -lt 0 -or $i -eq ($items.Count - 1)) { return }
        if ($i -le 4) {
            $w = $items[$i].W
            Save-NativeDisplay
            Detect-Display
            $hz = $script:HW.Display.Hz
            $modes = @([FnoNative]::AllModes())
            $want = ('{0}x1080@{1}' -f $w, $hz)
            if ($modes -notcontains $want) {
                Say-Warn ('O modo {0} ainda nao existe no driver.' -f $want)
                Say-Info 'Crie-o em: NVIDIA (Alterar resolucao > Personalizar) | AMD (Tela > Resolucoes personalizadas) | CRU (Add > Detailed).'
                Say-Info 'Depois reinicie o driver (restart64.exe do CRU) e rode este preset de novo.'
                Pause-Key; continue
            }
            if (-not (Confirm-Action ('Trocar Windows e Fortnite para {0}x1080 @ {1} Hz?' -f $w, $hz) $true)) { continue }
            if ($script:Dry) { Say-Dry ('SetMode {0}x1080@{1}' -f $w, $hz); [void](Sync-FnResolution $w 1080); Pause-Key; continue }
            $t = [FnoNative]::SetMode([uint32]$w, [uint32]1080, [uint32]$hz, $true)
            if ($t -ne 0) { Say-Bad ('O driver recusou o modo (codigo ' + $t + ').'); Pause-Key; continue }
            [void][FnoNative]::SetMode([uint32]$w, [uint32]1080, [uint32]$hz, $false)
            Start-Sleep -Milliseconds 1500
            [void](Sync-FnResolution $w 1080)
            Write-Log ('Resolucao esticada {0}x1080' -f $w)
            Say-Info 'Falta so o ESCALA (item "Tela ficou quadrada?") se aparecerem barras pretas.'
            Pause-Key
        } elseif ($i -eq 5) {
            $f = Get-NativeFile
            $nw = 1920; $nh = 1080; $nz = [int]$script:HW.Display.Hz
            if (Test-Path -LiteralPath $f) { $parts = (Get-Content -LiteralPath $f -Raw).Trim() -split '\s+'; if ($parts.Count -ge 3) { $nw = [int]$parts[0]; $nh = [int]$parts[1]; $nz = [int]$parts[2] } }
            else { Say-Warn 'Sem nativa salva; usando 1920x1080.' }
            if ($script:Dry) { Say-Dry ('SetMode {0}x{1}@{2}' -f $nw, $nh, $nz) } else { [void][FnoNative]::SetMode([uint32]$nw, [uint32]$nh, [uint32]$nz, $false) }
            [void](Sync-FnResolution $nw $nh)
            Pause-Key
        } elseif ($i -eq 6) { Show-ScalingHelp }
        elseif ($i -eq 7) {
            $cru = Find-AppExe -ExeName 'CRU.exe' -IdPrefix 'ToastyX.CustomResolutionUtility'
            if (-not $cru) { if (Confirm-Action 'CRU nao instalado. Instalar via winget?' $true) { [void](Install-Winget 'ToastyX.CustomResolutionUtility'); $cru = Find-AppExe -ExeName 'CRU.exe' -IdPrefix 'ToastyX.CustomResolutionUtility' } }
            if ($cru -and -not $script:Dry) { Start-Process -FilePath $cru }
            Pause-Key
        }
    }
}

# ---------------------------------------------------------------------
#  SISTEMA: limpeza, servicos, update, defender
# ---------------------------------------------------------------------
function Get-DirSizeMB {
    param([string]$P)
    try { $s = (Get-ChildItem -LiteralPath $P -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum; if ($s) { return [math]::Round($s / 1MB, 0) } } catch { }
    return 0
}
function Clear-DirContents {
    param([string]$P, [string[]]$Skip = @())
    if (-not (Test-Path -LiteralPath $P)) { return }
    foreach ($c in @(Get-ChildItem -LiteralPath $P -Force -ErrorAction SilentlyContinue)) {
        if ($Skip -contains $c.Name) { continue }
        try { Remove-Item -LiteralPath $c.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
}
function Action-Clean {
    $targets = @($env:TEMP, (Join-Path $env:windir 'Temp'), (Join-Path $env:LOCALAPPDATA 'FortniteGame\Saved\Logs'), (Join-Path $env:LOCALAPPDATA 'FortniteGame\Saved\Crashes'))
    $tot = 0
    foreach ($t in $targets) { $tot += (Get-DirSizeMB $t) }
    Say ('  Vai limpar arquivos temporarios (~{0} MB): TEMP do usuario, Windows\Temp, logs e crashes do Fortnite. Arquivos em uso sao pulados.' -f $tot) 'White'
    if (-not (Confirm-Action 'Limpar agora?' $true)) { return $false }
    $shader = Confirm-Action 'Tambem limpar o cache de shaders do DirectX (D3DSCache)? Use so se tem stutter/corrupcao: na 1a partida os shaders recompilam (mais lenta).' $false
    if ($script:Dry) { Say-Dry 'limpar temporarios'; if ($shader) { Say-Dry 'limpar D3DSCache' }; return $true }
    foreach ($t in $targets) { Clear-DirContents -P $t -Skip @('FortniteOtimizador') }
    if ($shader) { Clear-DirContents -P (Join-Path $env:LOCALAPPDATA 'D3DSCache'); Say-Ok 'D3DSCache limpo.' }
    [void](Invoke-Native -File 'ipconfig' -ArgList @('/flushdns'))
    Say-Ok 'Limpeza concluida.'
    return $true
}
function Action-Services {
    Say '  DiagTrack (telemetria) sera desativado. Spooler (impressao) e SysMain (Superfetch) so se voce confirmar.' 'White'
    Say '  O tipo de inicio original de cada servico e guardado e volta no Restaurar. Nunca mexe em EAC/rede/audio.' 'DarkGray'
    if (-not (Confirm-Action 'Desativar DiagTrack?' $true)) { return $false }
    $svc = @('DiagTrack')
    if (Confirm-Action 'Voce NAO usa impressora? Desativar o Spooler?' $false) { $svc += 'Spooler' }
    if (Confirm-Action 'Tem SSD e disco em 100% com stutter? Desativar SysMain (quem tem HDD deve MANTER)?' $false) { $svc += 'SysMain' }
    foreach ($s in $svc) {
        [void](Set-Reg -P ('HKLM\SYSTEM\CurrentControlSet\Services\' + $s) -N 'Start' -T 'DWord' -V 4)
        if (-not $script:Dry) { try { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue } catch { } }
        Say-Ok ('Servico desativado: ' + $s)
    }
    Save-State
    return $true
}
function Check-WuPause {
    $v = Get-Reg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime'
    if (-not $v) { return $false }
    try { return ([datetime]::Parse([string]$v).ToUniversalTime() -gt (Get-Date).ToUniversalTime()) } catch { return $false }
}
function Apply-WuPause {
    $t = (Get-Date).AddDays(1).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $ok = Set-Reg -P 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -N 'PauseUpdatesExpiryTime' -T 'String' -V $t
    if ($ok) { Say-Ok ('Atualizacoes pausadas ate ' + $t + ' (UTC).') }
    return $ok
}
function Undo-WuPause { return (Undo-Regs @((Rg 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime' 'String' 'x'))) }
function Get-DefenderList { return (Join-Path $script:BackupDir 'defender_exclusions.txt') }
function Check-Defender {
    $f = Get-DefenderList
    return (Test-Path -LiteralPath $f)
}
function Apply-Defender {
    $paths = @()
    if ($script:HW.Fn.Dir) { $paths += $script:HW.Fn.Dir }
    $paths += (Join-Path $env:LOCALAPPDATA 'FortniteGame')
    foreach ($p in $paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        if ($script:Dry) { Say-Dry ('Add-MpPreference -ExclusionPath ' + $p); continue }
        try {
            Add-MpPreference -ExclusionPath $p -ErrorAction Stop
            Add-Content -LiteralPath (Get-DefenderList) -Value $p
            Say-Ok ('Excluido do Defender: ' + $p)
        } catch { Say-Bad ('Defender recusou (antivirus de terceiros ativo?): ' + $_.Exception.Message) }
    }
    return $true
}
function Undo-Defender {
    $f = Get-DefenderList
    if (-not (Test-Path -LiteralPath $f)) { Say-Info 'Sem exclusoes registradas.'; return $true }
    foreach ($p in @(Get-Content -LiteralPath $f)) {
        if (-not $p) { continue }
        if ($script:Dry) { Say-Dry ('Remove-MpPreference ' + $p); continue }
        try { Remove-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue } catch { }
    }
    if (-not $script:Dry) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    Say-Ok 'Exclusoes removidas.'
    return $true
}
function Action-Startup {
    Say '  Programas que iniciam com o Windows (desative o que nao usa em Ctrl+Shift+Esc > Inicializar):' 'White'
    try { Get-CimInstance Win32_StartupCommand -ErrorAction Stop | Select-Object Name, Command | Format-Table -AutoSize -Wrap | Out-String -Width 110 | ForEach-Object { Say $_ 'Gray' } } catch { Say-Warn $_.Exception.Message }
    return $true
}
function Action-Disks {
    try { Get-PhysicalDisk | Select-Object FriendlyName, MediaType, @{n = 'GB'; e = { [math]::Round($_.Size / 1GB, 0) } } | Format-Table -AutoSize | Out-String -Width 110 | ForEach-Object { Say $_ 'Gray' } } catch { }
    Say '  Fortnite no SSD = carregamento bem mais rapido e menos stutter ao carregar skins/mapa.' 'Gray'
    Say '  Se estiver no HDD: Epic Launcher > Fortnite > ... > Mover para SSD. Em SSD nunca desfragmente (so TRIM, automatico).' 'Gray'
    return $true
}

function Register-FnSysTweaks {
    Add-Tweak @{ Id = 'fn_ini'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = 'forte'
        Name = 'GameUserSettings.ini: preset de PERFORMANCE (backup automatico)'
        Desc = 'Edita as chaves reais do Fortnite (por secao): VSync OFF, sombras/efeitos/pos-processo/AA/texturas Low, sem Nanite/RayTracing/blur/frame generation, tela cheia exclusiva, mostrar FPS. Mostra cada chave alterada e preserva a resolucao. Feche o jogo antes (ele sobrescreve o INI ao sair). Maior ganho de FPS em PC fraco.'
        Apply = { [void](Action-FnIni) } }
    Add-Tweak @{ Id = 'fn_engine'; Group = 'fn'; Level = 3; Evidence = 'nenhuma'
        Name = 'Engine.ini: r.OneFrameThreadLag / GTSyncType / GC (NAO COMPROVADO)'
        Desc = 'r.OneFrameThreadLag=1 ja e o padrao da Unreal Engine e a Epic nao documenta Engine.ini como suportado (pode ignorar ou reverter). Efeito pratico desconhecido/nulo. Mantido so por compatibilidade; o desfazer remove exatamente as chaves adicionadas.'
        Check = { Check-FnEngine }; Apply = { Apply-FnEngine }; Undo = { Undo-FnEngine } }
    Add-Tweak @{ Id = 'fn_freeze'; Group = 'fn'; Level = 2; Evidence = '-'; NoBulk = $true
        Name = 'Congelar os INIs (somente-leitura) p/ o jogo nao desfazer o preset'
        Desc = 'Com somente-leitura, mudar opcoes DENTRO do jogo nao salva. Fluxo certo: configure tudo, congele, jogue; para mudar, libere (Desfazer) antes.'
        Check = { Check-FnFrozen }; Apply = { Apply-FnFreeze }; Undo = { Undo-FnFreeze } }
    Add-Tweak @{ Id = 'fn_res'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = 'media'
        Name = 'Resolucao esticada (presets de pro) - Windows + Fortnite juntos'
        Desc = 'Presets 1440/1650/1680/1720/1750 x 1080. Troca a resolucao do Windows (API nativa, sem baixar nircmd) e sincroniza o INI do Fortnite. Guarda a nativa p/ reverter. Explica como criar o modo (CRU/NVIDIA/AMD) e como esticar sem barras pretas.'
        Apply = { Menu-StretchRes } }
    Add-Tweak @{ Id = 'fn_launch'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = 'fraca'
        Name = 'Launch options do Epic Launcher (copia p/ area de transferencia)'
        Desc = 'Versao corrigida: so -NOSPLASH e (opcional) -USEALLAVAILABLECORES. Removidos os argumentos que podiam PIORAR (-malloc=system, -NOTEXTURESTREAMING).'
        Apply = { [void](Action-FnLaunch) } }
    Add-Tweak @{ Id = 'fn_focus'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = 'media'
        Name = 'MODO FOCO: fecha drenos (Discord/Chrome/...) e abre o Fortnite'
        Desc = 'Lista o que esta aberto e so fecha com sua confirmacao (pede pra fechar normal, depois forca). Abre o jogo pelo launcher e espera o processo aparecer (sem tempo fixo de 45 s).'
        Apply = { [void](Action-FnFocus) } }
    Add-Tweak @{ Id = 'fn_replays'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = '-'
        Name = 'Replays: desligar no jogo + apagar replays antigos'
        Desc = 'A gravacao de replay grava em disco durante a partida; desligue em Configuracoes > Jogo > Replays. O script pode apagar os .replay antigos (pede confirmacao, nao tem desfazer).'
        Apply = { [void](Action-FnReplays) } }
    Add-Tweak @{ Id = 'fn_verify'; Group = 'fn'; Kind = 'action'; Level = 1; Evidence = '-'
        Name = 'Verificar arquivos do jogo + abrir pasta de configuracoes'
        Desc = 'Arquivo corrompido causa crash/stutter. Abre o Epic Launcher e a pasta WindowsClient.'
        Apply = { [void](Action-FnVerify) } }

    Add-Tweak @{ Id = 'clean'; Group = 'sys'; Kind = 'action'; Level = 1; Evidence = 'fraca'
        Name = 'Limpeza: temporarios, logs/crashes do Fortnite, DNS (+ shaders opcional)'
        Desc = 'Libera espaco e remove logs. O cache de shaders do DirectX so deve ser limpo com stutter/corrupcao (recompila na 1a partida). Arquivos em uso sao pulados.'
        Apply = { [void](Action-Clean) } }
    Add-Tweak @{ Id = 'bgapps'; Group = 'sys'; Level = 1; Evidence = 'fraca'
        Name = 'Sugestoes/apps em 2o plano do Windows OFF'
        Desc = 'Desliga instalacao silenciosa de apps, sugestoes do menu e pesquisa Bing. So chaves de registro, nao desinstala nada.'
        RegsFn = { Get-BgAppsRegs } }
    Add-Tweak @{ Id = 'delivery'; Group = 'sys'; Level = 1; Evidence = 'fraca'
        Name = 'Delivery Optimization OFF (nao enviar/receber updates de outros PCs)'
        Desc = 'Evita o Windows usar sua rede/disco para distribuir atualizacoes. Ganho pequeno, principalmente em internet limitada.'
        RegsFn = { Get-DeliveryRegs } }
    Add-Tweak @{ Id = 'startup'; Group = 'sys'; Kind = 'action'; Level = 1; Evidence = '-'
        Name = 'Ver programas que iniciam com o Windows'
        Desc = 'Lista o que inicia junto (Discord, Spotify, OneDrive...). Desative o que nao usa para jogar.'
        Apply = { [void](Action-Startup) } }
    Add-Tweak @{ Id = 'services'; Group = 'sys'; Kind = 'action'; Level = 2; Evidence = 'fraca'
        Name = 'Servicos pesados: DiagTrack / Spooler / SysMain (com backup)'
        Desc = 'DiagTrack = telemetria. Spooler so se nao usa impressora. SysMain so em SSD com disco em 100%. O inicio original e guardado.'
        Apply = { [void](Action-Services) } }
    Add-Tweak @{ Id = 'wupause'; Group = 'sys'; Level = 2; Evidence = 'fraca'; NoBulk = $true
        Name = 'Pausar o Windows Update por 24 h (so enquanto for jogar)'
        Desc = 'Mesmo mecanismo do botao "Pausar atualizacoes" do Windows. Evita download/instalacao em fundo durante a partida.'
        Check = { Check-WuPause }; Apply = { Apply-WuPause }; Undo = { Undo-WuPause } }
    Add-Tweak @{ Id = 'defender'; Group = 'sys'; Level = 2; Evidence = 'fraca'; NoBulk = $true
        Name = 'Windows Defender: excluir SO as pastas do Fortnite'
        Desc = 'AVISO DE SEGURANCA: exclusao reduz a protecao nessas pastas. So as pastas do jogo (instalacao + %LOCALAPPDATA%\FortniteGame). Ganho pequeno com o Defender padrao; maior com antivirus de terceiros pesado.'
        Check = { Check-Defender }; Apply = { Apply-Defender }; Undo = { Undo-Defender } }
    Add-Tweak @{ Id = 'disks'; Group = 'sys'; Kind = 'action'; Level = 1; Evidence = '-'
        Name = 'SSD ou HD? (onde o Fortnite esta)'
        Desc = 'Mostra o tipo dos seus discos e o que fazer.'
        Apply = { [void](Action-Disks) } }
}

# =====================================================================
#  PLANO DE ENERGIA COMPLETO (gerado na hora, por perfil de CPU)
#  - Nada e baixado: o plano e construido com powercfg a partir do plano
#    base do proprio Windows e cada configuracao e conferida ANTES.
#  - Perfis: classic | hybrid | ryzen | x3d2   (notebook usa base Balanced)
# =====================================================================
$script:PLAN_P = '54533251-82be-4824-96c1-47b60b740d00'   # subgrupo Processador
$script:UltimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:HighPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'

$script:PlanProfiles = @{
    classic = @{ Label = 'Intel classico / outros (base Ultimate Performance)'
        Desc = 'Nucleos sempre acordados (sem core parking), clock minimo 100%, boost agressivo, EPP maximo desempenho. E o perfil "tudo no talo" para CPUs sem nucleos hibridos.' }
    hybrid  = @{ Label = 'Intel hibrido P+E (12a geracao ou mais nova) - base Balanced'
        Desc = 'NAO trava o clock minimo (relatos mostram que "Alto desempenho" faz os E-cores assumirem o trabalho e gera stutter). Sem core parking, boost agressivo, EPP maximo e agendador preferindo os P-cores.' }
    ryzen   = @{ Label = 'AMD Ryzen (1 CCD) - base Balanced'
        Desc = 'A AMD recomenda a base Balanced para o CPPC funcionar. Aqui: boost agressivo, EPP maximo desempenho, nucleos desestacionados e clock minimo deixado ao CPPC (o Ryzen sobe em microssegundos).' }
    x3d2    = @{ Label = 'Ryzen X3D de 2 CCDs (7900X3D/7950X3D/9900X3D/9950X3D) - base Balanced'
        Desc = 'NAO mexe no core parking: o driver 3D V-Cache da AMD usa o parking para prender o jogo no CCD com cache extra (plano de Alto desempenho quebra isso). So aplica boost agressivo, EPP maximo e as economias de USB/PCIe/Wi-Fi.' }
}

function Get-PlanProfile {
    $c = $script:HW.Cpu
    if ($c.DualCcdX3D) { return 'x3d2' }
    if ($c.Vendor -eq 'AMD') { return 'ryzen' }
    if ($c.IntelHybrid) { return 'hybrid' }
    return 'classic'
}

# Uma configuracao = @{ N nome; Sub; Set; V valor (AC); Why }
function New-PlanSetting {
    param([string]$N, [string]$Sub, [string]$Set, [int]$V, [string]$Why)
    @{ N = $N; Sub = $Sub; Set = $Set; V = $V; Why = $Why }
}
function Get-PlanSettings {
    param([string]$Prof)
    $P = $script:PLAN_P
    $s = @()
    # ---- processador: comum a todos ----
    $s += New-PlanSetting 'Estado maximo do processador' $P 'bc5038f7-23e0-4960-96da-33abaf5935ec' 100 'Sem limite de clock.'
    $s += New-PlanSetting 'Modo de boost do processador = Agressivo' $P 'be337238-0d82-4146-a960-4f3749d470c7' 2 'Sobe o clock mais rapido.'
    $s += New-PlanSetting 'Politica de boost = maximo' $P '45bcc044-d885-43e2-8605-ee0ec6e96b59' 100 'Favorece boost sobre eficiencia.'
    $s += New-PlanSetting 'EPP (preferencia energia/desempenho) = desempenho' $P '36687f9e-e3a5-4dbf-b1dc-15eb381c6863' 0 'Intel Speed Shift / AMD CPPC escolhem clock alto.'
    $s += New-PlanSetting 'EPP classe 1 (nucleos eficientes) = desempenho' $P '36687f9f-e3a5-4dbf-b1dc-15eb381c6863' 0 'So existe em CPUs hibridas.'
    $s += New-PlanSetting 'Resfriamento do sistema = ativo' $P '94d3a615-a899-4ac5-ae2b-e4d8f634367f' 1 'Liga a ventoinha antes de reduzir clock.'
    $s += New-PlanSetting 'Dica de latencia: desempenho do processador' $P '619b7505-003b-4e82-b7a6-4dd29c300971' 100 'Tarefas sensiveis a latencia recebem clock maximo.'
    # ---- por perfil ----
    if ($Prof -eq 'classic') {
        if ($script:HW.Laptop) {
            # notebook: 100% fixo esquenta o chassi e o boost cai quando mais precisa
            $s += New-PlanSetting 'Estado minimo do processador = 5% (notebook: preserva o boost)' $P '893dee8e-2bef-41e0-89c6-b55d0929964c' 5 'Em notebook, clock travado no maximo esquenta e reduz o boost no jogo.'
        } else {
            $s += New-PlanSetting 'Estado minimo do processador = 100%' $P '893dee8e-2bef-41e0-89c6-b55d0929964c' 100 'Clock nunca cai (zero rampa).'
        }
        $s += New-PlanSetting 'Nucleos minimos ativos = 100% (sem parking)' $P '0cc5b647-c1df-4637-891a-dec35c318583' 100 'Nenhum nucleo estacionado.'
        $s += New-PlanSetting 'Nucleos maximos ativos = 100%' $P 'ea062031-0e34-4ff1-9b6d-eb1059334028' 100 ''
        $s += New-PlanSetting 'Dica de latencia: desestacionar nucleos' $P '616cdaa5-695e-4545-97ad-97dc2d1bdd88' 100 ''
    } elseif ($Prof -eq 'hybrid') {
        $s += New-PlanSetting 'Estado minimo do processador = 5% (deixa o HWP decidir)' $P '893dee8e-2bef-41e0-89c6-b55d0929964c' 5 'Evita travar E-cores em clock alto.'
        $s += New-PlanSetting 'Nucleos minimos ativos = 100% (sem parking)' $P '0cc5b647-c1df-4637-891a-dec35c318583' 100 ''
        $s += New-PlanSetting 'Nucleos minimos ativos classe 1 = 100%' $P '0cc5b647-c1df-4637-891a-dec35c318584' 100 ''
        $s += New-PlanSetting 'Nucleos maximos ativos = 100%' $P 'ea062031-0e34-4ff1-9b6d-eb1059334028' 100 ''
        $s += New-PlanSetting 'Politica de agendamento hibrido = preferir P-cores' $P '93b8b6dc-0698-4d1c-9ee4-0644e900c85d' 2 'Threads pesadas nos nucleos de desempenho.'
        $s += New-PlanSetting 'Politica de agendamento (tarefas curtas) = preferir P-cores' $P 'bae08b81-2d5e-4688-ad6a-13243356654b' 2 ''
        $s += New-PlanSetting 'Dica de latencia: desestacionar nucleos' $P '616cdaa5-695e-4545-97ad-97dc2d1bdd88' 100 ''
    } elseif ($Prof -eq 'ryzen') {
        $s += New-PlanSetting 'Estado minimo do processador = 5% (CPPC decide)' $P '893dee8e-2bef-41e0-89c6-b55d0929964c' 5 'Recomendacao AMD: nao travar o minimo.'
        $s += New-PlanSetting 'Nucleos minimos ativos = 100% (sem parking)' $P '0cc5b647-c1df-4637-891a-dec35c318583' 100 ''
        $s += New-PlanSetting 'Nucleos maximos ativos = 100%' $P 'ea062031-0e34-4ff1-9b6d-eb1059334028' 100 ''
        $s += New-PlanSetting 'Dica de latencia: desestacionar nucleos' $P '616cdaa5-695e-4545-97ad-97dc2d1bdd88' 100 ''
    } else {
        # x3d2: NAO mexe em core parking nem em "desestacionar"
        $s += New-PlanSetting 'Estado minimo do processador = 5% (CPPC decide)' $P '893dee8e-2bef-41e0-89c6-b55d0929964c' 5 'Recomendacao AMD: nao travar o minimo.'
    }
    # ---- perifericos e barramentos: comum a todos ----
    $s += New-PlanSetting 'USB: suspensao seletiva = desativada' '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' 0 'Mouse/teclado nao dormem.'
    $s += New-PlanSetting 'USB 3: gerenciamento de energia do link = desligado' '2a737441-1930-4402-8d77-b2bebba308a3' 'd4e98f31-5ffe-4ce1-be31-1b38b384c009' 0 'Sem latencia de saida de estado de baixa energia.'
    $s += New-PlanSetting 'PCI Express: ASPM = desligado' '501a4d13-42af-4429-9fd1-a8218c268e20' 'ee12f906-d277-404b-b6da-e5fa1a576df5' 0 'GPU/NVMe sem economia de link.'
    $s += New-PlanSetting 'Disco rigido: nunca desligar' '0012ee47-9041-4b5d-9b77-535fba8b1442' '6738e2c4-e8a5-4a42-b16a-e040e769756e' 0 'Sem espera de spin-up.'
    $s += New-PlanSetting 'Adaptador sem fio: desempenho maximo' '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' '12bbebe6-58d6-4636-95bb-3217ef867c1a' 0 'Wi-Fi sem economia (menos jitter).'
    return $s
}

function Get-PlanText {
    param([string]$Plan)
    return ((Invoke-Native -File 'powercfg' -ArgList @('/qh', $Plan) -Read).Output).ToLower()
}
function Get-PlanAcValue {
    param([string]$Plan, [string]$Sub, [string]$Set)
    $o = (Invoke-Native -File 'powercfg' -ArgList @('/qh', $Plan, $Sub, $Set) -Read).Output
    $m = [regex]::Matches($o, '0x[0-9a-fA-F]{8}')
    if ($m.Count -ge 2) { return [Convert]::ToInt64($m[$m.Count - 2].Value, 16) }
    return $null
}

function New-PowerPlanFromBase {
    param([string]$Kind, [string]$Active)
    $bases = @($script:BalancedGuid)
    if ($Kind -eq 'ultimate') { $bases = @($script:UltimateGuid, $script:HighPerfGuid, $script:BalancedGuid) }
    foreach ($b in $bases) {
        $r = Invoke-Native -File 'powercfg' -ArgList @('-duplicatescheme', $b)
        if ($r.Dry) { return '00000000-0000-0000-0000-000000000000' }
        $g = Get-Guid $r.Output
        if ($g) { return $g }
    }
    if ($Active) {
        $r = Invoke-Native -File 'powercfg' -ArgList @('-duplicatescheme', $Active)
        if ($r.Dry) { return '00000000-0000-0000-0000-000000000000' }
        return (Get-Guid $r.Output)
    }
    return $null
}

function Apply-PowerPlan {
    param([string]$Prof = '')
    if (-not $Prof) { $Prof = Get-PlanProfile }
    $def = $script:PlanProfiles[$Prof]
    Say ('  Perfil: ' + $def.Label) 'White'
    $act = Get-ActivePlan
    $existing = Find-PlanByName $script:PlanName

    # guarda o plano original (so a 1a vez)
    if (-not $script:State.Other.ContainsKey('PowerOrig')) {
        $orig = $act
        if ($act -and $existing -and ($act -eq $existing)) {
            $lf = Join-Path $script:BackupDir 'energia_original.txt'
            if (Test-Path -LiteralPath $lf) { $o = Get-Guid (Get-Content -LiteralPath $lf -Raw); if ($o) { $orig = $o } }
        }
        if (-not $script:Dry) { $script:State.Other['PowerOrig'] = $orig; Save-State }
    }
    $origG = $script:BalancedGuid
    if ($script:State.Other.ContainsKey('PowerOrig') -and $script:State.Other['PowerOrig'] -and ($script:State.Other['PowerOrig'] -ne $existing)) { $origG = [string]$script:State.Other['PowerOrig'] }

    # base: Ultimate so no perfil classico e fora de notebook; senao Balanced
    $kind = 'balanced'
    if ($Prof -eq 'classic' -and -not $script:HW.Laptop) { $kind = 'ultimate' }
    $prev = $null
    if ($script:State.Other.ContainsKey('PlanProfile')) { $prev = [string]$script:State.Other['PlanProfile'] }
    $prevLap = $null
    if ($script:State.Other.ContainsKey('PlanBase')) { $prevLap = [string]$script:State.Other['PlanBase'] }

    if ($existing -and ($prev -ne $Prof -or $prevLap -ne $kind)) {
        Say-Info 'Recriando o plano com a base certa para este perfil...'
        if ($act -eq $existing) { [void](Invoke-Native -File 'powercfg' -ArgList @('-setactive', $origG)) }
        [void](Invoke-Native -File 'powercfg' -ArgList @('-delete', $existing))
        $existing = $null
    }
    $g = $existing
    if (-not $g) {
        $g = New-PowerPlanFromBase -Kind $kind -Active $act
        if (-not $g) { Say-Bad 'Nao consegui criar o plano de energia.'; return $false }
        [void](Invoke-Native -File 'powercfg' -ArgList @('-changename', $g, $script:PlanName, ('Criado pelo Fortnite Otimizador - perfil ' + $Prof)))
    }

    # configuracoes: so aplica o que existe neste Windows e confere depois
    $qtext = ''
    if ($script:Dry) { $qtext = Get-PlanText $act } else { $qtext = Get-PlanText $g }
    $ok = 0; $skip = 0; $bad = 0
    foreach ($st in (Get-PlanSettings $Prof)) {
        if ($qtext -and ($qtext -notmatch $st.Set)) { $skip++; Say ('   [--] {0}  (nao existe neste Windows: ignorado)' -f $st.N) 'DarkGray'; continue }
        $r = Invoke-Native -File 'powercfg' -ArgList @('-setacvalueindex', $g, $st.Sub, $st.Set, [string]$st.V)
        if ($r.Dry) { $ok++; continue }
        if ($r.ExitCode -ne 0) { $bad++; Say ('   [X]  {0}  (powercfg recusou)' -f $st.N) 'Red'; continue }
        $now = Get-PlanAcValue -Plan $g -Sub $st.Sub -Set $st.Set
        if ($null -ne $now -and [int64]$now -eq [int64]$st.V) { $ok++; Say ('   [OK] {0}' -f $st.N) 'Green' }
        else { $bad++; Say ('   [!]  {0}  (esperado {1}, ficou {2})' -f $st.N, $st.V, $now) 'Yellow' }
    }
    $r = Invoke-Native -File 'powercfg' -ArgList @('-setactive', $g)
    if (-not $r.Dry -and $r.ExitCode -ne 0) { Say-Bad ('powercfg -setactive falhou: ' + $r.Output.Trim()); return $false }

    # Power Throttling do Windows (so desktop; em notebook custa bateria)
    if (-not $script:HW.Laptop) {
        [void](Set-Reg -P 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -N 'PowerThrottlingOff' -T 'DWord' -V 1)
    }
    if (-not $script:Dry) {
        $script:State.Other['PlanProfile'] = $Prof
        $script:State.Other['PlanBase'] = $kind
        Save-State
    }
    Say-Ok ('Plano "{0}" ativo: {1} configuracao(oes) aplicada(s), {2} ignorada(s) por nao existir neste Windows, {3} com problema.' -f $script:PlanName, $ok, $skip, $bad)
    Write-Log ('Plano de energia perfil ' + $Prof)
    return ($bad -eq 0)
}

function Action-PlanExport {
    $g = Find-PlanByName $script:PlanName
    if (-not $g) { Say-Warn 'Aplique o plano primeiro (item 1).'; return $false }
    $dst = Join-Path $script:ToolsDir 'Fortnite_Otimizador.pow'
    if ($script:Dry) { Say-Dry ('powercfg /export ' + $dst); return $true }
    if (-not (Test-Path -LiteralPath $script:ToolsDir)) { [void](New-Item -ItemType Directory -Force -Path $script:ToolsDir) }
    Remove-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
    $r = Invoke-Native -File 'powercfg' -ArgList @('/export', $dst, $g)
    if ($r.ExitCode -eq 0 -and (Test-Path -LiteralPath $dst)) {
        Say-Ok ('Plano exportado: ' + $dst)
        Say-Info 'Para usar em outro PC: powercfg /import "caminho\Fortnite_Otimizador.pow" (ou pelo item "Importar"). Atencao: o plano exportado e do SEU perfil de CPU.'
        return $true
    }
    Say-Bad ('Falhou ao exportar: ' + $r.Output.Trim())
    return $false
}
function Action-PlanImport {
    Say '  Importa um plano de energia (.pow) que voce ja tenha (por exemplo o exportado por este programa).' 'White'
    Say '  Um .pow so contem configuracoes de energia (nao executa codigo), mas importe apenas de fontes em que confia.' 'Yellow'
    if (-not $script:UseKeys -or $script:AutoActive) { Say-Info 'Entrada de caminho indisponivel neste modo.'; return $false }
    $p = Read-Host (L '  Caminho do arquivo .pow (arraste o arquivo para ca; vazio = cancelar)')
    $p = ([string]$p).Trim().Trim('"')
    if (-not $p) { return $false }
    if (-not (Test-Path -LiteralPath $p) -or ([IO.Path]::GetExtension($p) -ne '.pow')) { Say-Bad 'Arquivo nao encontrado ou nao e .pow.'; return $false }
    if ((Get-Item -LiteralPath $p).Length -gt 1MB) { Say-Bad 'Arquivo grande demais para ser um plano de energia.'; return $false }
    $r = Invoke-Native -File 'powercfg' -ArgList @('/import', $p)
    $g = Get-Guid $r.Output
    if (-not $g) { Say-Bad ('powercfg nao importou: ' + $r.Output.Trim()); return $false }
    Say-Ok ('Plano importado: ' + $g)
    if (-not $script:State.Other.ContainsKey('PowerOrig')) { $script:State.Other['PowerOrig'] = (Get-ActivePlan); Save-State }
    if (Confirm-Action 'Ativar o plano importado agora? (o original fica salvo p/ voltar)' $true) { [void](Invoke-Native -File 'powercfg' -ArgList @('-setactive', $g)); Say-Ok 'Ativado.' }
    return $true
}
function Show-PlanDetails {
    param([string]$Prof)
    $def = $script:PlanProfiles[$Prof]
    $sys = Get-PlanText (Get-ActivePlan)
    $l = @(('#Perfil: ' + $def.Label), $def.Desc, '')
    $base = 'Balanced'
    if ($Prof -eq 'classic' -and -not $script:HW.Laptop) { $base = 'Ultimate Performance (fallback: Alto desempenho)' }
    if ($script:HW.Laptop) { $l += '~Notebook detectado: base Balanced (a bateria nao e afetada, so a tomada).' }
    $l += @(('#' + (L 'Base do plano') + ': ' + (L $base)), '', '#Configuracoes (na tomada / AC):')
    foreach ($st in (Get-PlanSettings $Prof)) {
        if ($sys -and ($sys -notmatch $st.Set)) { $l += ('~' + $st.N + '  -> ignorada: nao existe neste Windows') }
        else {
            $t = '+' + $st.N + ' = ' + $st.V
            if ($st.Why) { $t += '   (' + $st.Why + ')' }
            $l += $t
        }
    }
    if (-not $script:HW.Laptop) { $l += '+Windows Power Throttling = desligado (registro PowerThrottlingOff=1)   (apps em 2o plano nao sao mais limitados)' }
    $l += @('', '~Nao inclui o modo "CPU sempre em C0" (item extremo separado) nem mexe em suspensao/tela (voce mantem os seus tempos).')
    Show-Text 'O QUE O PLANO CONFIGURA' $l
}

function Menu-Power {
    $sel = 0
    $prof = Get-PlanProfile
    while ($true) {
        $def = $script:PlanProfiles[$prof]
        $items = @(
            @{ Label = 'APLICAR o plano recomendado para o meu PC'; Desc = ('Perfil: ' + $def.Label + '. ' + $def.Desc + ' Seu plano atual NAO e alterado: o otimizador cria o plano "Fortnite Otimizador" e o Desfazer volta ao anterior.'); Badges = @(); Id = 'apply' },
            @{ Label = 'Escolher outro perfil de CPU (manual)'; Desc = 'Classico, Intel hibrido, Ryzen ou Ryzen X3D de 2 CCDs. Util se a deteccao errar ou se voce vai exportar o plano p/ outro PC.'; Badges = @(); Id = 'choose' },
            @{ Label = 'Ver tudo que este plano configura (com valores e motivos)'; Desc = 'Lista cada configuracao, o valor e se ela existe neste Windows. Nada e alterado.'; Badges = @(); Id = 'view' },
            @{ Label = 'Exportar o plano para arquivo .pow (compartilhar)'; Desc = 'Gera Fortnite_Tools\Fortnite_Otimizador.pow com powercfg /export.'; Badges = @(); Id = 'export' },
            @{ Label = 'Importar um plano .pow'; Desc = 'Importa um .pow que voce escolher (o exportado por este programa ou outro em que confia).'; Badges = @(); Id = 'import' },
            @{ Label = 'Voltar ao plano de energia original'; Desc = 'Reativa o plano que estava em uso antes.'; Badges = @(); Id = 'undo' },
            @{ Label = 'Voltar'; Desc = ''; Badges = @(); Id = 'back' }
        )
        $i = Show-Menu -Title 'PLANO DE ENERGIA' -Sub ('Perfil selecionado: ' + $def.Label) -Items $items -Selected $sel -Art 'power'
        if ($i -lt 0 -or $items[$i].Id -eq 'back') { return }
        $sel = $i
        Invoke-Safe {
            switch ($items[$i].Id) {
                'apply'  { if (Confirm-Action ('Aplicar o perfil "' + $prof + '" agora?') $true) { [void](Apply-PowerPlan -Prof $prof); Pause-Key } }
                'choose' {
                    $keys = @('classic', 'hybrid', 'ryzen', 'x3d2')
                    $opts = @(); $descs = @()
                    foreach ($k in $keys) { $opts += $script:PlanProfiles[$k].Label; $descs += $script:PlanProfiles[$k].Desc }
                    $j = Select-Option -Title 'PERFIL DE CPU' -Options $opts -Descs $descs -Selected ([Array]::IndexOf($keys, $prof)) -Sub ('Detectado: ' + $script:PlanProfiles[(Get-PlanProfile)].Label)
                    if ($j -ge 0) { $prof = $keys[$j] }
                }
                'view'   { Show-PlanDetails $prof }
                'export' { [void](Action-PlanExport); Pause-Key }
                'import' { [void](Action-PlanImport); Pause-Key }
                'undo'   { [void](Undo-Power); Pause-Key }
            }
        }
    }
}

# Teste REAL e descartavel: cria um plano temporario (nunca ativado), aplica cada
# configuracao, le de volta e apaga. Usado no -SelfTest.
function Test-PowerPlanReal {
    param([string]$Prof)
    $old = $script:Dry
    $script:Dry = $false
    $g = $null
    try {
        $g = New-PowerPlanFromBase -Kind 'balanced' -Active (Get-ActivePlan)
        if (-not $g) { return @{ Skipped = $true; Why = 'nao consegui criar plano temporario' } }
        [void](Invoke-Native -File 'powercfg' -ArgList @('-changename', $g, 'FNO_SCRATCH_TEST', 'teste'))
        $q = Get-PlanText $g
        $ok = 0; $skip = 0; $bad = @()
        foreach ($st in (Get-PlanSettings $Prof)) {
            if ($q -notmatch $st.Set) { $skip++; continue }
            $r = Invoke-Native -File 'powercfg' -ArgList @('-setacvalueindex', $g, $st.Sub, $st.Set, [string]$st.V)
            if ($r.ExitCode -ne 0) { $bad += ($st.N + ' (recusado: ' + $r.Output.Trim() + ')'); continue }
            $now = Get-PlanAcValue -Plan $g -Sub $st.Sub -Set $st.Set
            if ($null -ne $now -and [int64]$now -eq [int64]$st.V) { $ok++ } else { $bad += ($st.N + ' (esperado ' + $st.V + ', ficou ' + $now + ')') }
        }
        return @{ Skipped = $false; Ok = $ok; Skip = $skip; Bad = $bad }
    } finally {
        if ($g) { [void](Invoke-Native -File 'powercfg' -ArgList @('-delete', $g)) }
        $script:Dry = $old
    }
}

# =====================================================================
#  Cada item traz evidencia honesta. Fontes nos comentarios.
# =====================================================================

# "Otimizacoes para jogos em janela" (Win11): DX10/11 em janela/sem borda
# passam para o modelo FLIP (menos latencia). Microsoft:
# support.microsoft.com/windows/optimizations-for-windowed-games-in-windows-11
# Mesma string guarda outros tokens (AutoHDREnable, VRROptimizeEnable...):
# so o token SwapEffectUpgradeEnable e trocado, o resto e preservado.
function Get-WinOptRegs {
    $p = 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = [string](Get-Reg $p 'DirectXUserGlobalSettings')
    return @(Rg $p 'DirectXUserGlobalSettings' 'String' (Set-DxToken $cur 'SwapEffectUpgradeEnable' '1'))
}
function Set-DxToken {
    param([string]$Cur, [string]$Key, [string]$Val)
    $parts = @()
    $found = $false
    foreach ($t in ($Cur -split ';')) {
        $t = $t.Trim()
        if (-not $t) { continue }
        $kv = $t -split '=', 2
        if ($kv[0] -eq $Key) { $parts += ($Key + '=' + $Val); $found = $true } else { $parts += $t }
    }
    if (-not $found) { $parts += ($Key + '=' + $Val) }
    return (($parts -join ';') + ';')
}

# NVIDIA: DisableDynamicPstate=1 prende a GPU no P0 (clock maximo) no driver,
# acima do "Preferir desempenho maximo". Evidencia fraca p/ latencia; custa
# energia/calor o tempo todo. So desktop.
function Get-NvClassKeys {
    $out = @()
    $base = 'SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    try {
        $k = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64').OpenSubKey($base)
        if ($k) {
            foreach ($n in $k.GetSubKeyNames()) {
                if ($n -notmatch '^\d{4}$') { continue }
                try {
                    $s = $k.OpenSubKey($n)
                    if ($s -and ([string]$s.GetValue('ProviderName') -match 'NVIDIA')) { $out += ('HKLM\' + $base + '\' + $n) }
                    if ($s) { $s.Close() }
                } catch { }
            }
            $k.Close()
        }
    } catch { }
    return $out
}
function Get-NvPstateRegs {
    $r = @()
    foreach ($p in (Get-NvClassKeys)) { $r += Rg $p 'DisableDynamicPstate' 'DWord' 1 }
    return $r
}

# Mitigacoes Spectre/Meltdown OFF. Microsoft: FeatureSettingsOverride=3 e
# Mask=3 desliga as mitigacoes de CVE-2017-5715/5754. Ganho: CPUs antigas
# (ate ~2018) em partes do kernel; CPU atual ~0. Perda de seguranca real.
function Get-SpectreRegs {
    $mm = 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    return @((Rg $mm 'FeatureSettingsOverride' 'DWord' 3), (Rg $mm 'FeatureSettingsOverrideMask' 'DWord' 3))
}

function Register-ExtraTweaks {
    Add-Tweak @{ Id = 'winopt'; Group = 'gpuall'; Level = 1; Evidence = 'forte'; Tags = @('WIN11')
        Name = 'Otimizacoes para jogos em janela (modelo FLIP no DX10/11)'
        Desc = 'Configuracao oficial do Windows 11: jogos DirectX 10/11 em janela ou sem borda passam a apresentar quadros pelo modelo "flip", que tem menos latencia e libera VRR. HONESTO: no Fortnite atual (DirectX 12 e Modo Desempenho, que virou DX12 no patch 37.00) NAO muda nada; vale para outros jogos DX11 e para quem ainda usa DX11. Preserva os outros ajustes da mesma chave (Auto HDR, VRR).'
        RegsFn = { Get-WinOptRegs } }
    Add-Tweak @{ Id = 'nv_pstate'; Group = 'gpu'; Level = 2; Evidence = 'fraca'; Tags = @('NV', 'DESKTOP'); Reboot = $true; NoBulk = $true
        Name = 'NVIDIA: travar a GPU no P0 (DisableDynamicPstate) - clock maximo sempre'
        Desc = 'Registro do driver que impede a GPU de baixar o clock, ate no desktop. Mais agressivo que "Preferir desempenho maximo" (que ja vem no perfil do Fortnite). Ganho de latencia real e pequeno (o Reflex "Ligado + Impulso" faz quase o mesmo so durante o jogo). Custo: +20 a 40 W parado, mais calor e ventoinha. So desktop. Precisa reiniciar.'
        RegsFn = { Get-NvPstateRegs } }
    Add-Tweak @{ Id = 'spectre'; Group = 'cpu'; Level = 3; Evidence = 'mista'; Reboot = $true
        Name = 'Mitigacoes Spectre/Meltdown OFF  -  REDUZ SEGURANCA'
        Desc = 'Desliga protecoes do kernel contra ataques de execucao especulativa (FeatureSettingsOverride=3). Ganho medido so em CPUs antigas (Intel ate a 8a/9a geracao, Ryzen 1000/2000), e mais em disco/rede do que em FPS; em CPU recente (Intel 12a+ / Ryzen 5000+) o ganho e praticamente zero. Custo: um programa malicioso pode ler memoria de outro processo. Nao recomendado para PC de uso geral. Reversivel.'
        RegsFn = { Get-SpectreRegs } }
}

# ---------------------------------------------------------------------
#  Alertas extras do Diagnostico (somente leitura). Retorna a contagem.
# ---------------------------------------------------------------------
$script:OverlayApps = @(
    @{ P = 'Discord'; N = 'Discord (desligue o overlay em Configuracoes > Overlay do jogo)' },
    @{ P = 'steam'; N = 'Steam (overlay e gravacao desligados se nao usar)' },
    @{ P = 'Overwolf'; N = 'Overwolf' },
    @{ P = 'Medal'; N = 'Medal.tv (grava em segundo plano)' },
    @{ P = 'obs64'; N = 'OBS Studio' },
    @{ P = 'ArmouryCrate'; N = 'Armoury Crate (ASUS)' },
    @{ P = 'iCUE'; N = 'Corsair iCUE' },
    @{ P = 'RazerCentralService'; N = 'Razer Synapse' },
    @{ P = 'SignalRgb'; N = 'SignalRGB' },
    @{ P = 'NZXT CAM'; N = 'NZXT CAM' },
    @{ P = 'MSI.CentralServer'; N = 'MSI Center' },
    @{ P = 'wallpaper64'; N = 'Wallpaper Engine' },
    @{ P = 'wallpaper32'; N = 'Wallpaper Engine' }
)
function Get-UpdateRevision {
    try {
        $v = (Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'Update Revision' -ErrorAction Stop).'Update Revision'
        if ($v -is [byte[]] -and $v.Length -ge 8) { return [BitConverter]::ToUInt32($v, 4) }
    } catch { }
    return $null
}
function Test-AmdChipsetInstalled {
    foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        try {
            foreach ($k in @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)) {
                $dn = [string]$k.GetValue('DisplayName')
                if ($dn -match 'AMD Chipset Software|AMD Chipset Drivers') { return $true }
            }
        } catch { }
    }
    return $false
}
function Show-ExtraAlerts {
    $hw = $script:HW
    $n = 0
    $cpu = [string]$hw.Cpu.Name
    # AMD: driver de chipset (CPPC preferred cores, PPM, plano da AMD)
    if ($hw.Cpu.Vendor -eq 'AMD') {
        if (-not (Test-AmdChipsetInstalled)) { Say-Warn 'Driver de CHIPSET da AMD nao encontrado: sem ele o "nucleo preferido" (CPPC) do Windows nao funciona direito. Baixe em amd.com/support (chipset da sua placa-mae).'; $n++ }
        if ($hw.Cpu.IsX3D) {
            $svc = Get-Service -Name 'AMD3DVCacheSvc' -ErrorAction SilentlyContinue
            if ($hw.Cpu.DualCcdX3D -and -not $svc) { Say-Warn 'Ryzen X3D de 2 CCDs sem o servico "AMD 3D V-Cache Performance Optimizer": instale/atualize o chipset da AMD, senao o jogo pode rodar no CCD sem cache.'; $n++ }
            if ($hw.Cpu.DualCcdX3D) {
                $gb = $null
                try { $gb = Get-AppxPackage -Name 'Microsoft.XboxGamingOverlay' -ErrorAction Stop } catch { }
                if (-not $gb) { Say-Warn 'Xbox Game Bar ausente: no X3D de 2 CCDs ela ajuda o driver da AMD a detectar o jogo. Reinstale pelo menu Restaurar.'; $n++ }
            }
        }
        # fTPM: travadas de 1-2 s corrigidas no AGESA 1.2.0.7 (AMD PA-410, maio/2022)
        try {
            $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
            $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
            if ($tpm -and ([string]$tpm.ManufacturerIdTxt -match 'AMD') -and $bios.ReleaseDate -and $bios.ReleaseDate -lt (Get-Date '2022-06-01')) {
                Say-Warn ('fTPM da AMD ativo com BIOS de {0:dd/MM/yyyy}: BIOS anteriores ao AGESA 1.2.0.7 causam travadas de 1-2 s (audio e mouse congelam). Atualize a BIOS.' -f $bios.ReleaseDate); $n++
            }
        } catch { }
    }
    # Intel 13a/14a geracao desktop: instabilidade por voltagem (microcode 0x12B+)
    if ($hw.Cpu.Vendor -eq 'INTEL' -and -not $hw.Laptop -and $cpu -match 'i[579]-1[34]\d{3}') {
        $rev = Get-UpdateRevision
        if ($null -ne $rev -and $rev -lt 0x12B) { Say-Warn ('Intel 13a/14a geracao com microcode 0x{0:X} (antigo). A Intel corrigiu a degradacao por voltagem no 0x12B/0x12F: atualize a BIOS e selecione "Intel Default Settings".' -f $rev); $n++ }
        elseif ($null -eq $rev) { Say-Info 'Intel 13a/14a geracao: confirme BIOS com microcode 0x12B ou mais novo (correcao oficial de instabilidade).'; $n++ }
    }
    # Notebook com iGPU + dGPU: MUX / Advanced Optimus
    if ($hw.Laptop -and $hw.Gpus.Count -gt 1 -and @($hw.Gpus | Where-Object { $_.Discrete }).Count -gt 0) {
        Say-Info 'Notebook com duas GPUs: se tiver MUX switch / "somente GPU dedicada" no software do fabricante, ligue para jogar. Passar a imagem pela integrada adiciona latencia e tira FPS.'; $n++
    }
    # Programas em segundo plano/overlays que pesam no 1% low
    $run = @()
    try {
        $names = @(Get-Process -ErrorAction Stop | ForEach-Object { $_.ProcessName })
        foreach ($a in $script:OverlayApps) { if ($names -contains $a.P -and $run -notcontains $a.N) { $run += $a.N } }
    } catch { }
    if ($run.Count) { Say-Info ('Abertos agora (overlays/RGB/gravacao somam custo): ' + ($run -join '; ') + '. Feche o que nao usa durante a partida.'); $n++ }
    return $n
}

# =====================================================================
#  GUIAS (texto). Prefixos: # titulo | + bom | ! aviso | ~ nota
# =====================================================================
function Get-GuideInGame {
    return @(
        '#VIDEO > TELA',
        '+Modo de janela: TELA CHEIA. Menor latencia e sem passar pelo compositor.',
        '+VSync: DESLIGADO no jogo (ligado adiciona 1 a 2 quadros de atraso). Excecao: G-SYNC/FreeSync, ver guia da sua GPU.',
        '+Limite de FPS: ilimitado, ou 3 abaixo do Hz se usa G-SYNC/FreeSync. Nunca muito abaixo da capacidade do PC "por estabilidade": FPS baixo = mais atraso.',
        '+Taxa de atualizacao: o MAXIMO do monitor (item "Taxa de atualizacao" no menu Input Lag).',
        '',
        '#VIDEO > MODO DE RENDERIZACAO',
        '+Desde o patch 37.00 (ago/2025) o Modo DESEMPENHO roda em DirectX 12 e substituiu o antigo Desempenho DX11. E o que da mais FPS e o frametime mais estavel em PC fraco, notebook e CPU hibrida.',
        '+DirectX 12 com tudo em Baixo: para GPU recente que quer um pouco mais de imagem. Distribui melhor o trabalho entre os nucleos que o DX11 antigo.',
        '~Na 1a partida apos update/driver novo o jogo compila shaders: ha engasgos que somem depois. Deixe o jogo terminar de compilar no lobby.',
        '',
        '#VIDEO > GRAFICOS',
        '+Resolucao 3D: 100%. Se precisar de FPS, baixe de 10 em 10.',
        '+Sombras, efeitos, pos-processamento, texturas: Baixo. Motion blur, Ray Tracing, Nanite, Lumen/GI e Reflexos: DESLIGADOS.',
        '~Upscaling (DLSS/FSR/XeSS/TSR): renderiza em resolucao menor. Se a GPU e o gargalo, mais FPS = menos latencia; o TSR custa alguns ms por quadro, prefira DLSS/FSR/XeSS se tiver.',
        '!Frame Generation (DLSS FG, FSR FG, AFMF): ADICIONA latencia (insere quadro interpolado). Desligue no competitivo.',
        '+Mostrar FPS: ligado.',
        '',
        '#LATENCIA POR MARCA DE GPU (o que o Fortnite suporta de verdade)',
        '+NVIDIA Reflex: "Ligado + Impulso". Ligado ja remove a fila de renderizacao; o Impulso tambem impede a GPU de baixar o clock entre quadros (ganho extra quando a GPU NAO esta em 99%, ex.: notebook, menus, FPS travado).',
        '+Com Reflex ligado, o "Modo de baixa latencia" do painel NVIDIA e ignorado (nao faz mal deixar).',
        '!AMD Anti-Lag 2: o Fortnite NAO tem (lista oficial da AMD so traz CS2, Dota 2 e Ghost of Tsushima). O Anti-Lag classico do driver so funciona em DX11, e o Fortnite atual e DX12.',
        '!Intel XeLL (Xe Low Latency): sem confirmacao oficial no Fortnite. Nao conte com ele.',
        '',
        '#COMO SABER SE AJUDOU',
        '~Nao confie em sensacao. Use o CapFrameX (menu Programas) e compare FPS medio, 1% low e frametime antes/depois de cada mudanca.'
    )
}
function Get-GuideHardware {
    return @(
        '#O QUE TEM MAIS IMPACTO QUE QUALQUER TWEAK DE REGISTRO',
        '',
        '#Monitor',
        '+Use o Hz MAXIMO (60 Hz = 16,7 ms entre quadros; 144 Hz = 6,9 ms; 240 Hz = 4,2 ms).',
        '+Cabo DisplayPort (HDMI antigo limita o Hz). Overdrive MEDIO no menu do monitor: alto demais gera rastro invertido (so visual).',
        '~ULMB/strobing (piscar o backlight) reduz o BORRAO de movimento, nao a latencia de clique-a-foton. Nao combine com overdrive alto.',
        '',
        '#Mouse e teclado',
        '+Polling 1000 Hz. 4000/8000 Hz so com CPU forte, porta USB direta da placa-mae (traseira), e cobram CPU.',
        '+DPI fixo (400 a 1600) e sensibilidade no jogo. Sem hub USB. Sem fio: dongle 2,4 GHz perto, nunca Bluetooth.',
        '',
        '#Memoria RAM',
        '+2 pentes (dual channel) com XMP/EXPO LIGADO. Pente unico ou RAM em velocidade JEDEC (2133/2400 DDR4, 4800 DDR5) derruba o 1% low; com GPU integrada a perda chega a 40-60%.',
        '',
        '#Notebook',
        '+Na tomada, sempre. Se tiver MUX switch / "GPU dedicada somente" / Advanced Optimus no software do fabricante (Armoury Crate, MSI Center, Legion Vantage...), ligue para jogar: passar a imagem pela integrada adiciona latencia e tira FPS.',
        '+Windows 11 "Taxa de atualizacao dinamica": troque para o Hz maximo fixo (Configuracoes > Sistema > Tela > Tela avancada), senao a tela pode cair para 60 Hz.',
        '~Intel: "Panel Self Refresh" (Intel Graphics Software > Energia) pode dar travadinha no mouse quando a tela "acorda". Desligue jogando na tomada.',
        '',
        '#Programas em segundo plano',
        '+Cada overlay custa pouco sozinho, mas soma: Discord (overlay), Steam (overlay), gravadores (Medal, OBS, Overwolf) e suites RGB (Armoury Crate, iCUE, Synapse, SignalRGB). Feche o que nao usa. O Diagnostico lista os que estao abertos.',
        '',
        '#Armazenamento e temperatura',
        '+Fortnite em SSD. Throttling termico causa stutter: limpe a poeira, confira a pasta termica, veja temperaturas no HWiNFO.'
    )
}
function Get-GuideBios {
    return @(
        '#TODOS OS PCs',
        '+XMP/EXPO LIGADO (a RAM vem rodando abaixo da velocidade anunciada).',
        '+Resizable BAR ligado se a GPU suportar (RTX 30+, RX 6000+, Intel Arc; na Arc e praticamente obrigatorio).',
        '+BIOS atualizada. Anote o valor original de tudo que mudar; nomes variam por fabricante.',
        '',
        '#INTEL (CPU)',
        '!13a e 14a geracao (i5/i7/i9 13xxx/14xxx desktop): atualize a BIOS para microcode 0x12B ou mais novo e escolha "Intel Default Settings". E a correcao oficial da Intel para degradacao por voltagem (travamentos que parecem stutter). O Diagnostico confere seu microcode.',
        '+Core Ultra 200S (Arrow Lake): Windows e BIOS atualizados corrigiram a latencia de memoria do lancamento. O perfil "200S Boost" e opcional (overclock oficial; aumenta limites).',
        '+Turbo Boost e Speed Shift (HWP) ligados. Turbo Boost Max 3.0: mantenha o driver/servico (manda o jogo para os nucleos mais rapidos).',
        '~12a geracao ou mais nova (nucleos P + E): o Windows as vezes poe a thread do jogo num E-core. Se tiver stutter: algumas placas tem "Legacy Game Compatibility Mode" (Scroll Lock liga/desliga os E-cores) ou use o Process Lasso para prender o Fortnite nos P-cores.',
        '~C-States: padrao (ligado) e o mais equilibrado. Desligar tira o atraso de despertar, mas esquenta; evidencia de ganho media/fraca. Meca com o LatencyMon.',
        '~Hyper-Threading: manter ligado, salvo se voce mediu ganho desligando.',
        '',
        '#AMD RYZEN',
        '+EXPO ligado (se a placa/kit tiver "EXPO Ultra Low Latency", melhor ainda). Resizable BAR (SAM) ligado.',
        '+CPPC e "CPPC Preferred Cores" ligados + driver de CHIPSET da AMD instalado (sem ele o nucleo preferido nao funciona). O Diagnostico confere.',
        '!fTPM: BIOS com AGESA anterior ao 1.2.0.7 causa travadas de 1-2 s (audio e mouse congelam). Atualize a BIOS.',
        '+AM5 com DDR5-6000: FCLK ~2000 MHz e UCLK = MCLK (1:1). A regra antiga "tudo 1:1:1" e do AM4/DDR4.',
        '+PBO ligado; Curve Optimizer negativo (com teste de estabilidade) da mais boost sustentado.',
        '~Global C-State Control: deixe o padrao (Auto/Enabled). Desligar tem resultado misto e reduz o boost.',
        '~SMT: manter ligado. Testes controlados no Fortnite nao mostram ganho desligando.',
        '~Ryzen X3D com 2 CCDs (7900X3D/7950X3D/9900X3D/9950X3D): Game Mode e Xbox Game Bar ATIVOS + servico "AMD 3D V-Cache Performance Optimizer" (vem com o chipset). Este otimizador respeita isso sozinho.'
    )
}
function Get-GuideNvidia {
    return @(
        '#NO JOGO (mais importante que o painel)',
        '+NVIDIA Reflex: "Ligado + Impulso" (GTX 900 ou mais nova). Com Reflex, o limitador automatico e a fila ficam por conta dele.',
        '',
        '#PAINEL DE CONTROLE NVIDIA > Gerenciar config. 3D > Configuracoes de programa > Fortnite',
        '+Modo de gerenciamento de energia: Preferir desempenho maximo.',
        '+Modo de baixa latencia: Ultra (vale para jogos SEM Reflex; no Fortnite o Reflex assume).',
        '+Filtragem de textura - qualidade: Alto desempenho.',
        '+Otimizacao com threads: Automatico (so tem efeito em DX11/OpenGL; o Fortnite atual e DX12).',
        '+Cache de shader (Configuracoes globais): padrao do driver ou Ilimitado em SSD. Evita engasgo de recompilacao; nao muda latencia.',
        '',
        '#G-SYNC (se o monitor tem)',
        '+Receita Blur Busters: G-SYNC ligado + V-SYNC LIGADO no painel (desligado no jogo) + Reflex ligado (limita sozinho uns FPS abaixo do Hz). Sem tearing e com latencia quase igual a FPS livre.',
        '~Latencia absoluta minima: sem G-SYNC, V-SYNC desligado e FPS livre (aceita tearing).',
        '',
        '#O item "Perfil de baixa latencia" (menu GPU) aplica o painel sozinho, via NVIDIA Profile Inspector.',
        '',
        '#APP NVIDIA',
        '+Overlay, Instant Replay e gravacao em segundo plano: DESLIGADOS.',
        '',
        '#DRIVER',
        '+Stutter/erros: DDU no Modo Seguro + driver Game Ready recente (menu Programas). NVCleanstall instala so o driver, sem extras.',
        '~Frame Generation (RTX 40/50) exige HAGS ligado e aumenta a latencia: nao use no competitivo.',
        '~Forcar Resizable BAR em jogo fora da lista (flags do Profile Inspector) tem efeito variavel: as vezes nada, raramente instavel. Nao faz parte do perfil.'
    )
}
function Get-GuideAmd {
    return @(
        '#O QUE FUNCIONA NO FORTNITE',
        '!Anti-Lag 2: o Fortnite NAO suporta (precisa integracao no jogo; lista oficial da AMD: CS2, Dota 2, Ghost of Tsushima).',
        '~Anti-Lag (classico, do driver): so age em DX11. Com o Fortnite em DX12/Modo Desempenho ele nao faz efeito; pode deixar ligado sem problema.',
        '!Nunca use Anti-Lag+ (foi removido dos drivers apos banimentos em outros jogos).',
        '',
        '#AMD SOFTWARE: ADRENALIN > Jogos > Fortnite',
        '+Radeon Chill: DESLIGADO (quando a acao comeca, a subida de FPS atrasa justo na hora que importa).',
        '+Radeon Boost e HYPR-RX: DESLIGADOS (o Boost muda a resolucao durante o movimento).',
        '+Aguardar atualizacao vertical: "Desligado, a menos que o aplicativo especifique".',
        '+Enhanced Sync: DESLIGADO se voce usa FreeSync + limite de FPS (o normal). So faz sentido sem FreeSync e com FPS acima do Hz.',
        '+FreeSync ligado + limite de FPS 3 abaixo do Hz (no jogo).',
        '+Frame Rate Target Control: DESLIGADO (use o limitador do jogo).',
        '+AFMF / Fluid Motion Frames: DESLIGADO (adiciona latencia).',
        '+Filtragem de textura: Desempenho. Cache de shader: Otimizado pela AMD. Resetar o cache so se tiver engasgos depois de trocar driver.',
        '+GPU Scaling LIGADO e Scaling Mode Full Panel se usar resolucao esticada.',
        '',
        '~A AMD nao tem API/linha de comando oficial para essas opcoes. O "FlipQueueSize" por registro circula em guias, mas drivers atuais podem ignorar: nao aplicamos o que nao da para confirmar.',
        '+Driver: Adrenalin recente. Se trocou de marca de GPU, use DDU antes.'
    )
}
function Get-GuideIntelGpu {
    return @(
        '#INTEL (graficos integrados UHD/Iris/Arc integrado e placas Arc)',
        '+Graficos integrados: use o Modo DESEMPENHO do Fortnite (o mais leve).',
        '+A iGPU usa a RAM do sistema: DUAL CHANNEL e com XMP e a mudanca de maior impacto (single channel corta 40-60% do desempenho).',
        '+Placas Arc (A/B): Resizable BAR LIGADO na BIOS. A Intel diz que e praticamente obrigatorio.',
        '+Intel Graphics Software: modo de energia desempenho maximo; sync desligado.',
        '!"Baixa latencia" (XeLL) so age se o jogo integrar o XeLL; no Fortnite nao ha confirmacao.',
        '~Notebook: Panel Self Refresh DESLIGADO na tomada (Intel Graphics Software > Sistema > Energia): pode causar travadinhas.',
        '+Feche navegadores/overlays: a iGPU divide calor e memoria com a CPU.',
        '~Notebook: na tomada e com o exe do Fortnite marcado como "Alto desempenho" (item no menu Input Lag).'
    )
}
function Get-GuideNet {
    return @(
        '#O QUE REALMENTE BAIXA O PING',
        '+Cabo Ethernet (Cat5e ou melhor) direto no roteador.',
        '+Servidor certo: no Fortnite, Configuracoes > Jogo > Regiao de matchmaking = a mais proxima (Brasil).',
        '+Nao baixar/streamar junto (bufferbloat). Se o roteador tiver SQM/QoS (fq_codel/cake), ligue; ou limite a banda a ~90%.',
        '+Reinicie o roteador de vez em quando e mantenha o firmware atualizado.',
        '',
        '#SE PRECISA USAR WI-FI',
        '+Banda 5 GHz ou 6 GHz (Wi-Fi 6E), perto do roteador e sem paredes; canal limpo.',
        '+Roaming do adaptador no minimo e economia de energia do adaptador em desempenho maximo (item "Adaptador de rede").',
        '+Feche apps que usam rede e desligue VPN durante a partida.',
        '',
        '#COMO MEDIR',
        '~No Diagnostico ha um teste de ping/jitter para os servidores da Epic (ICMP; o jogo usa UDP, entao serve como base). Jitter abaixo de 10 ms e bom.',
        '',
        '#O QUE TEM POUCO OU NENHUM EFEITO',
        '~Nagle, reserva de QoS de 20% e NetworkThrottlingIndex: o gameplay e UDP; ganhos pequenos ou nulos. Estao no menu como opcionais e reversiveis.'
    )
}
function Get-GuideMyths {
    return @(
        '#MITOS E PLACEBO (circulam em "packs de otimizacao")',
        '~Nada aqui e aplicado pelo otimizador. A lista existe para voce nao perder tempo nem seguranca.',
        '',
        '#WINDOWS',
        '!DisablePagingExecutive=1: afeta um grupo minusculo de drivers; com pouca RAM pode piorar.',
        '!LargeSystemCache=1: feito para servidor de arquivos. A propria Microsoft desaconselha em PC de jogo.',
        '!SvcHostSplitThresholdInKB: muda o isolamento de servicos, nao latencia.',
        '!Desligar a compressao de memoria (MMAgent): teste controlado nao achou ganho; com 8-16 GB pode piorar.',
        '!useplatformtick / useplatformclock (HPET forcado): os tweaks de timer com mais relatos de PIORAR input lag. O otimizador nunca liga; o BCDEdit avancado so REMOVE o useplatformclock se alguem forcou.',
        '!IRQ priority / "IRQ8Priority": chave sem efeito no Windows moderno.',
        '',
        '#CPU',
        '!Desligar SMT/Hyper-Threading "por latencia": no Fortnite a diferenca fica dentro da margem de erro.',
        '!Desligar mitigacoes Spectre em CPU recente: ganho ~0 e perda real de seguranca (em CPU antiga ha algum ganho; item de risco no menu CPU).',
        '!Overclock de ring/uncore "para FPS": reduz latencia de cache no papel, quase nada no jogo, e aumenta o risco de instabilidade.',
        '',
        '#GPU',
        '!Desligar HDCP ou telemetria da NVIDIA: zero efeito no jogo (HDCP so afeta video protegido).',
        '!Desligar ULPS numa GPU AMD unica: so importa em CrossFire ou notebook hibrido.',
        '!"Threaded Optimization sempre ON": resultado misto, pode piorar frametime em jogo leve.',
        '!Limitar FPS muito abaixo do que o PC aguenta "por consistencia": aumenta a latencia. Limite so 3 abaixo do Hz (com VRR) ou use o Reflex.',
        '!DisableDynamicPstate "obrigatorio": quase igual ao "Preferir desempenho maximo" no jogo; so aumenta consumo parado (opcional no menu GPU).',
        '',
        '#REDE',
        '!"Liberar os 20% de banda reservada do QoS": o Windows nao reserva banda assim para jogos.',
        '!TCP tweaks para ping in-game: o Fortnite joga por UDP; TCP so pesa em login/loja/downloads.'
    )
}

function Show-Guide {
    param([string]$Id)
    switch ($Id) {
        'ingame' { Show-Text 'GUIA IN-GAME FORTNITE' (Get-GuideInGame) }
        'hw'     { Show-Text 'GUIA DE HARDWARE (impacto real)' (Get-GuideHardware) }
        'bios'   { Show-Text 'GUIA DE BIOS (Intel / AMD Ryzen)' (Get-GuideBios) }
        'nv'     { Show-Text 'GUIA NVIDIA' (Get-GuideNvidia) }
        'amd'    { Show-Text 'GUIA AMD RADEON' (Get-GuideAmd) }
        'intel'  { Show-Text 'GUIA INTEL GRAFICOS' (Get-GuideIntelGpu) }
        'net'    { Show-Text 'GUIA DE REDE (cabo e Wi-Fi)' (Get-GuideNet) }
        'myths'  { Show-Text 'MITOS E PLACEBO' (Get-GuideMyths) }
    }
}

# =====================================================================
#  MENUS, DIAGNOSTICO, APLICAR TUDO, RESTAURAR
# =====================================================================
$script:NeedReboot = $false

function Invoke-Safe {
    param([scriptblock]$Block)
    try { & $Block }
    catch {
        if ($_.Exception.Message -eq 'AUTOKEYS_DONE') { throw }
        Say-Bad ('Erro inesperado: ' + $_.Exception.Message)
        Write-Log ('EXC ' + $_.Exception.ToString())
        Pause-Key
    }
}

# ---------------------------------------------------------------------
#  Item de menu a partir de um tweak
# ---------------------------------------------------------------------
function Get-LevelBadge {
    param([int]$Level)
    switch ($Level) {
        0 { return (New-Badge '[GUIA]' 'Cyan') }
        1 { return (New-Badge '[SEGURO]' 'Green') }
        2 { return (New-Badge '[AVANCADO]' 'Yellow') }
        default { return (New-Badge '[RISCO ALTO]' 'Red') }
    }
}
function Get-TweakMeta {
    param($T)
    $m = ''
    if ($T.Evidence -and $T.Evidence -ne '-') { $m = (L 'Evidencia') + ': ' + (L $T.Evidence) + '  ' }
    if ($T.Reboot) { $m = $m + (L '[precisa REINICIAR]') }
    return $m
}
function New-TweakItem {
    param($T)
    $na = -not (Test-Applicable $T.Tags)
    $st = ''
    if ($T.Kind -ne 'action') { $st = Get-TweakState $T }
    if ($na) { $st = 'NA' }
    $listB = @()
    foreach ($b in (Get-TagBadges $T.Tags)) { if ($b.T -ne '[TODOS]' -and $b.T -ne '[DESKTOP]' -and $b.T -ne '[WIN11]') { $listB += $b } }
    $listB += (Get-LevelBadge $T.Level)
    $full = @(Get-TagBadges $T.Tags)
    $full += (Get-LevelBadge $T.Level)
    $desc = $T.Desc
    if ($na) { $desc = (L '(Nao se aplica ao hardware detectado neste PC - marque "Sim" na confirmacao se quiser forcar.)') + '  ' + (L $desc) }
    return @{ Label = $T.Name; Desc = $desc; Badges = $listB; DBadges = $full; State = $st; Na = $na; Meta = (Get-TweakMeta $T); Tweak = $T }
}

# ---------------------------------------------------------------------
#  Executar um tweak (aplicar / desfazer)
# ---------------------------------------------------------------------
function Invoke-TweakApply {
    param($T)
    $ok = $true
    if ($T.Apply) { $r = & $T.Apply; if ($r -is [bool]) { $ok = $r } elseif ($r -is [array] -and $r.Count -gt 0 -and $r[-1] -is [bool]) { $ok = $r[-1] } }
    elseif ($T.RegsFn) { $ok = Apply-Regs @(& $T.RegsFn) }
    Save-State
    return $ok
}
function Invoke-TweakUndo {
    param($T)
    if ($T.Undo) { $r = & $T.Undo; return $true }
    if ($T.RegsFn) {
        $any = Undo-Regs @(& $T.RegsFn)
        if (-not $any) { Say-Warn 'Nao ha valor original salvo por esta versao (foi aplicado por outra versao ou por voce?). Use Restaurar > backups do v1.5.' }
        else { Say-Ok 'Valor original restaurado.' }
        return $any
    }
    Say-Info 'Este item nao tem desfazer proprio.'
    return $false
}
function Run-Tweak {
    param($T)
    Clear-Ui
    Show-Banner $T.Name
    $w = Get-UiWidth
    Say ''
    foreach ($l in (Wrap-Text $T.Desc ($w - 6))) { Say ('  ' + $l) 'Gray' }
    $meta = Get-TweakMeta $T
    $tg = @(); foreach ($b in (Get-TagBadges $T.Tags)) { $tg += (L $b.T) }
    Write-Out ('  ' + ($tg -join ' ') + ' ' + (L (Get-LevelBadge $T.Level).T) + '  ' + $meta) 'DarkCyan'
    $na = -not (Test-Applicable $T.Tags)
    if ($na) {
        Say ''
        Say-Warn ('Este item e para outro hardware. Detectado aqui: ' + (Get-HwSummaryLine))
        if (-not (Confirm-Action 'Aplicar mesmo assim?' $false)) { return }
    }
    $did = $false
    try {
        if ($T.Kind -eq 'action') {
            $r = & $T.Apply
            $did = $true
        } else {
            $state = Get-TweakState $T
            if ($state -eq 'ON') {
                if (Confirm-Action 'Ja esta aplicado. Desfazer (voltar ao valor original)?' $false) { [void](Invoke-TweakUndo $T) }
            } else {
                $def = ($T.Level -lt 3)
                if (Confirm-Action 'Aplicar agora?' $def) {
                    if (Invoke-TweakApply $T) { $did = $true; Say-Ok 'Aplicado.' } else { Say-Warn 'Nao foi possivel aplicar tudo (veja acima).' }
                }
            }
        }
    } catch {
        if ($_.Exception.Message -eq 'AUTOKEYS_DONE') { throw }
        Say-Bad ('Erro inesperado: ' + $_.Exception.Message)
        Write-Log ('EXC ' + $T.Id + ' ' + $_.Exception.ToString())
    }
    Save-State
    if ($did -and $T.Reboot) { $script:NeedReboot = $true; Say-Info 'Reinicie o PC para este item valer.' }
    Pause-Key
}

# ---------------------------------------------------------------------
#  Menu de um grupo de tweaks
# ---------------------------------------------------------------------
function Menu-Group {
    param([string]$Group, [string]$Title, [string]$Sub, [string[]]$GuideIds = @(), [string]$Art = '')
    $sel = 0
    while ($true) {
        $list = @($script:Tweaks | Where-Object { $_.Group -eq $Group })
        $items = @()
        $heads = @{ 1 = '== SEGUROS (recomendados) =='; 2 = '== AVANCADOS (efeito moderado / opcionais) =='; 3 = '== RISCO ALTO / EXPERIMENTAIS (so se souber o que faz) ==' }
        foreach ($lv in 1, 2, 3) {
            $sub2 = @($list | Where-Object { $_.Level -eq $lv })
            if ($sub2.Count -eq 0) { continue }
            $items += @{ Header = $true; Label = $heads[$lv] }
            foreach ($t in $sub2) { $items += (New-TweakItem $t) }
        }
        if ($GuideIds.Count -gt 0) {
            $items += @{ Header = $true; Label = '== GUIAS ==' }
            foreach ($g in $GuideIds) { $items += (New-GuideItem $g) }
        }
        $items += @{ Label = 'Voltar'; Desc = 'Volta ao menu principal.'; Badges = @() }
        $i = Show-Menu -Title $Title -Sub $Sub -Items $items -Selected $sel -Art $Art
        if ($i -lt 0 -or $i -eq ($items.Count - 1)) { return }
        $sel = $i
        $it = $items[$i]
        if ($it.Guide) { Show-Guide $it.Guide; continue }
        if ($it.Tweak) { Invoke-Safe { Run-Tweak $it.Tweak } }
    }
}
function New-GuideItem {
    param([string]$Id)
    $map = @{
        'ingame' = @{ L = 'Guia: configuracao dentro do jogo (Fortnite)'; T = @('ALL') }
        'hw'     = @{ L = 'Guia: hardware fisico (monitor, mouse, rede, RAM)'; T = @('ALL') }
        'bios'   = @{ L = 'Guia: BIOS (Intel e AMD Ryzen)'; T = @('INTEL', 'RYZEN') }
        'nv'     = @{ L = 'Guia: NVIDIA (Painel de Controle / App / Reflex)'; T = @('NV') }
        'amd'    = @{ L = 'Guia: AMD Radeon (Adrenalin)'; T = @('AMD') }
        'intel'  = @{ L = 'Guia: Intel graficos (iGPU / Arc)'; T = @('INTELGPU') }
        'net'    = @{ L = 'Guia: rede (cabo e Wi-Fi)'; T = @('ALL') }
        'myths'  = @{ L = 'Guia: MITOS e placebo (o que NAO fazer)'; T = @('ALL') }
    }
    $m = $map[$Id]
    $na = -not (Test-Applicable $m.T)
    $st = ''
    if ($na) { $st = 'NA' }
    return @{ Label = $m.L; Desc = 'Texto de referencia, nao altera nada no PC.'; Badges = (Get-TagBadges $m.T); DBadges = (Get-TagBadges $m.T); State = $st; Na = $na; Guide = $Id; Meta = '[GUIA]' }
}

function Menu-Gpu {
    $sel = 0
    while ($true) {
        $items = @()
        $items += @{ Header = $true; Label = ('== SUA GPU: ' + (Get-GpuLabel) + ' ==') }
        $items += @{ Header = $true; Label = '== NVIDIA (automatizado) ==' }
        foreach ($t in @($script:Tweaks | Where-Object { $_.Group -eq 'gpu' })) { $items += (New-TweakItem $t) }
        $items += (New-GuideItem 'nv')
        $items += @{ Header = $true; Label = '== AMD RADEON (guia: a AMD nao tem API oficial p/ automatizar) ==' }
        $items += (New-GuideItem 'amd')
        $items += @{ Header = $true; Label = '== INTEL GRAFICOS ==' }
        $items += (New-GuideItem 'intel')
        $items += @{ Header = $true; Label = '== TODAS AS MARCAS ==' }
        foreach ($id in @('winopt', 'hags', 'mpo')) { $t = Get-Tweak $id; if ($t) { $items += (New-TweakItem $t) } }
        $items += @{ Label = 'Voltar'; Desc = ''; Badges = @() }
        $i = Show-Menu -Title 'GPU: NVIDIA / AMD / INTEL' -Sub 'Cada item traz a etiqueta da marca. Itens de outra marca aparecem apagados.' -Items $items -Selected $sel -Art 'gpu'
        if ($i -lt 0 -or $i -eq ($items.Count - 1)) { return }
        $sel = $i
        $it = $items[$i]
        if ($it.Guide) { Show-Guide $it.Guide; continue }
        if ($it.Tweak) { Invoke-Safe { Run-Tweak $it.Tweak } }
    }
}

function Menu-Guides {
    $ids = @('ingame', 'hw', 'bios', 'nv', 'amd', 'intel', 'net', 'myths')
    $sel = 0
    while ($true) {
        $items = @()
        foreach ($g in $ids) { $items += (New-GuideItem $g) }
        $items += @{ Label = 'Voltar'; Desc = ''; Badges = @() }
        $i = Show-Menu -Title 'GUIAS' -Sub 'Referencia por marca e por tipo de hardware. Nao altera nada.' -Items $items -Selected $sel -Art 'guides'
        if ($i -lt 0 -or $i -eq ($items.Count - 1)) { return }
        $sel = $i
        Show-Guide $items[$i].Guide
    }
}

# ---------------------------------------------------------------------
#  Diagnostico
# ---------------------------------------------------------------------
function Test-EpicPing {
    param([string]$HostName, [int]$Count = 8)
    try { [void][Net.Dns]::GetHostAddresses($HostName) } catch { return @{ Ok = $false; Msg = 'nome nao resolve' } }
    $p = New-Object Net.NetworkInformation.Ping
    $t = @(); $lost = 0
    for ($i = 0; $i -lt $Count; $i++) {
        try { $r = $p.Send($HostName, 1000); if ($r.Status -eq 'Success') { $t += [int]$r.RoundtripTime } else { $lost++ } } catch { $lost++ }
        Start-Sleep -Milliseconds 120
    }
    if ($t.Count -eq 0) { return @{ Ok = $false; Msg = 'sem resposta ICMP (o jogo usa UDP; pode estar bloqueado)' } }
    $m = $t | Measure-Object -Minimum -Maximum -Average
    return @{ Ok = $true; Min = $m.Minimum; Max = $m.Maximum; Avg = [math]::Round($m.Average, 1); Jitter = ($m.Maximum - $m.Minimum); Loss = [math]::Round(100.0 * $lost / $Count, 0) }
}
function Show-PingTest {
    Clear-Ui
    Show-Banner 'TESTE DE PING / JITTER (servidores da Epic)'
    Say '  ICMP e uma base aproximada (o jogo usa UDP). Bom: ping BR abaixo de 30 ms, jitter abaixo de 10 ms, perda 0%.' 'DarkGray'
    Say ''
    $regions = @(@('Brasil', 'br'), @('NA-Leste', 'nae'), @('NA-Oeste', 'naw'), @('NA-Central', 'nac'), @('Europa', 'eu'), @('Asia', 'asia'), @('Oriente Medio', 'me'), @('Oceania', 'oce'))
    Say ('  {0,-14} {1,6} {2,6} {3,6} {4,8} {5,6}' -f 'Regiao', 'min', 'media', 'max', 'jitter', 'perda') 'White'
    foreach ($r in $regions) {
        $host2 = ('ping-{0}.ds.on.epicgames.com' -f $r[1])
        Say ('  {0,-14} ...' -f $r[0]) 'DarkGray' -NoNewLine
        $res = Test-EpicPing -HostName $host2 -Count 6
        Write-Host ("`r" + (' ' * 60) + "`r") -NoNewline
        if ($res.Ok) {
            $c = 'Green'
            if ($res.Avg -gt 60) { $c = 'Yellow' }
            if ($res.Avg -gt 120) { $c = 'Red' }
            Say ('  {0,-14} {1,6} {2,6} {3,6} {4,8} {5,5}%' -f $r[0], $res.Min, $res.Avg, $res.Max, $res.Jitter, $res.Loss) $c
        } else { Say ('  {0,-14} {1}' -f $r[0], $res.Msg) 'DarkGray' }
    }
    if ($script:HW.Net.Kind -eq 'WIFI') { Say ''; Say-Warn 'Voce esta no Wi-Fi: espere jitter maior que no cabo. Se possivel, teste com Ethernet.' }
    Pause-Key
}
function Show-HwSummary {
    Clear-Ui
    Show-Banner 'DIAGNOSTICO DO SISTEMA'
    Detect-All
    $hw = $script:HW
    $lap = 'nao'; if ($hw.Laptop) { $lap = 'SIM' }
    Say ''
    Say ('  SISTEMA   {0} {1} (build {2}) | notebook: {3}' -f $hw.Os.Caption, $hw.Os.Display, $hw.Os.Build, $lap) 'White'
    foreach ($g in $hw.Gpus) { Say ('  GPU       {0}  [{1}]  driver {2}' -f $g.Name, $g.Vendor, $g.Driver) 'White' }
    if ($hw.Gpus.Count -eq 0) { Say '  GPU       nao detectada' 'Yellow' }
    $x = ''
    if ($hw.Cpu.IsX3D) { $x = ' | X3D' }
    if ($hw.Cpu.DualCcdX3D) { $x = $x + ' (2 CCDs)' }
    if ($hw.Cpu.IntelHybrid) { $x = $x + ' | hibrida P+E' }
    Say ('  CPU       {0}  [{1}]  {2} nucleos / {3} threads{4}' -f $hw.Cpu.Name, $hw.Cpu.Vendor, $hw.Cpu.Cores, $hw.Cpu.Threads, $x) 'White'
    Say ('  MEMORIA   {0} GB {1} @ {2} MT/s  ({3} pente(s))' -f $hw.Ram.TotalGB, $hw.Ram.Type, $hw.Ram.Speed, $hw.Ram.Modules) 'White'
    Say ('  REDE      {0}: {1}  ({2})  {3}' -f $hw.Net.Kind, $hw.Net.Name, $hw.Net.Desc, $hw.Net.Link) 'White'
    Say ('  TELA      {0}x{1} @ {2} Hz  (maximo oferecido nesta resolucao: {3} Hz)' -f $hw.Display.W, $hw.Display.H, $hw.Display.Hz, $hw.Display.MaxHz) 'White'
    if ($hw.Fn.Exe) { Say ('  FORTNITE  {0}' -f $hw.Fn.Exe) 'White' } else { Say '  FORTNITE  instalacao nao encontrada' 'Yellow' }
    Say ('  POWER     plano ativo: ' + (Get-ActivePlan)) 'DarkGray'
    Say ''
    Say '  O QUE CHAMA ATENCAO NO SEU PC:' 'Yellow'
    $n = 0
    if ($hw.Display.MaxHz -gt $hw.Display.Hz -and $hw.Display.Hz -gt 0) { Say-Warn ('Tela em {0} Hz mas o Windows oferece {1} Hz: use "Taxa de atualizacao no MAXIMO" (menu Input Lag).' -f $hw.Display.Hz, $hw.Display.MaxHz); $n++ }
    if ($hw.Ram.Modules -eq 1) { Say-Warn 'Apenas 1 pente de RAM = single channel (perde desempenho, muito pior com GPU integrada).'; $n++ }
    if (($hw.Ram.Type -eq 'DDR4' -and $hw.Ram.Speed -gt 0 -and $hw.Ram.Speed -le 2400) -or ($hw.Ram.Type -eq 'DDR5' -and $hw.Ram.Speed -gt 0 -and $hw.Ram.Speed -le 4800)) {
        Say-Warn ('Sua RAM roda a {0} MT/s (velocidade padrao JEDEC). Se o kit e mais rapido, ligue o XMP/EXPO na BIOS.' -f $hw.Ram.Speed); $n++
    }
    if ($hw.Net.Kind -eq 'WIFI') { Say-Warn 'Voce joga no Wi-Fi: cabo Ethernet e o maior ganho possivel de estabilidade (menos jitter).'; $n++ }
    if ($hw.Laptop) { Say-Warn 'Notebook: use na tomada e confirme que o Fortnite roda na GPU dedicada.'; $n++ }
    if ($hw.Gpus.Count -gt 1) { Say-Info 'Mais de uma GPU: garanta que o jogo usa a dedicada (item "Fortnite sempre na GPU de alto desempenho").'; $n++ }
    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        if ([int]$dg.VirtualizationBasedSecurityStatus -eq 2) { Say-Info 'VBS/Integridade de memoria esta ATIVA (custa FPS em alguns jogos; e uma troca com seguranca).'; $n++ }
    } catch { }
    $hags = Get-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    if ($null -ne $hags) { $hs = 'desligado'; if ([int]$hags -eq 2) { $hs = 'ligado' }; Say-Info ((L 'HAGS (agendamento por hardware)') + ': ' + (L $hs)) }
    $n += (Show-ExtraAlerts)
    if ($n -eq 0) { Say-Ok 'Nada de errado saltou aos olhos.' }
    Pause-Key
}
function Show-TimerScreen {
    Clear-Ui
    Show-Banner 'TIMER DO WINDOWS'
    Say ''
    Show-TimerStatus
    Say ''
    Say ('  ' + (L 'Task de timer forcado') + ': ' + (L $(if (Test-TimerTask) { 'ATIVA' } else { 'nao' }))) 'Gray'
    $g = Get-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests'
    Say ('  GlobalTimerResolutionRequests: ' + $(if ($null -ne $g) { $g } else { 'nao definido' })) 'Gray'
    Pause-Key
}
function Show-AllStates {
    $lines = @('#Estado de cada otimizacao neste PC (ON = aplicada, OFF = nao aplicada, - = nao se aplica ao hardware)', '')
    foreach ($t in $script:Tweaks) {
        if ($t.Kind -eq 'action') { continue }
        $st = Get-TweakState $t
        if (-not (Test-Applicable $t.Tags)) { $st = ' - ' } elseif ($st -eq 'ON') { $st = 'ON ' } elseif ($st -eq 'OFF') { $st = 'OFF' } else { $st = ' ? ' }
        $lines += ('[{0}] {1}' -f $st, $t.Name)
    }
    Show-Text 'ESTADO DAS OTIMIZACOES' $lines
}
function Menu-Diag {
    $sel = 0
    while ($true) {
        $items = @(
            @{ Label = 'Resumo do hardware e alertas do seu PC'; Desc = 'GPU, CPU, RAM, rede, tela, Fortnite e o que chama atencao (RAM em velocidade baixa, Wi-Fi, Hz abaixo do maximo...).'; Badges = @(); Id = 'hw' },
            @{ Label = 'Estado de todas as otimizacoes (ON / OFF)'; Desc = 'Confere o que ja esta aplicado agora, lendo o sistema.'; Badges = @(); Id = 'states' },
            @{ Label = 'Teste de ping e jitter (servidores da Epic)'; Desc = 'Mede ping, jitter e perda para as regioes da Epic (ICMP).'; Badges = @(); Id = 'ping' },
            @{ Label = 'Medir o timer do Windows (Sleep 1 ms)'; Desc = 'Mostra a resolucao do timer e o quanto Sleep(1) realmente demora.'; Badges = @(); Id = 'timer' },
            @{ Label = 'Voltar'; Desc = ''; Badges = @(); Id = 'back' }
        )
        $i = Show-Menu -Title 'DIAGNOSTICO' -Sub (Get-HwSummaryLine) -Items $items -Selected $sel -Art 'diag'
        if ($i -lt 0 -or $items[$i].Id -eq 'back') { return }
        $sel = $i
        switch ($items[$i].Id) {
            'hw'     { Invoke-Safe { Show-HwSummary } }
            'states' { Invoke-Safe { Show-AllStates } }
            'ping'   { Invoke-Safe { Show-PingTest } }
            'timer'  { Invoke-Safe { Show-TimerScreen } }
        }
    }
}

# ---------------------------------------------------------------------
#  Aplicar tudo (por nivel)
# ---------------------------------------------------------------------
function Get-BulkList {
    param([int]$MaxLevel)
    $out = @()
    foreach ($t in $script:Tweaks) {
        if ($t.Kind -ne 'toggle' -or $t.NoBulk) { continue }
        if ($t.Level -lt 1 -or $t.Level -gt $MaxLevel) { continue }
        if (-not (Test-Applicable $t.Tags)) { continue }
        $out += $t
    }
    return $out
}
function New-RestorePoint {
    if ($script:Dry) { Say-Dry 'Checkpoint-Computer'; return }
    Say '  Criando ponto de restauracao (pode levar ~30 s; ok se falhar)...' 'DarkGray'
    try {
        $w = $null
        Checkpoint-Computer -Description 'Fortnite_Otimizador' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningVariable w -WarningAction SilentlyContinue
        if ($w) { Say-Info 'O Windows so cria 1 ponto a cada 24 h; seguimos com os backups proprios.' } else { Say-Ok 'Ponto de restauracao criado.' }
    } catch { Say-Info 'Ponto de restauracao nao criado (Protecao do Sistema desligada?). Seguimos com os backups proprios.' }
}
function Invoke-Bulk {
    param([int]$MaxLevel)
    Clear-Ui
    $title = 'APLICAR TUDO SEGURO'
    if ($MaxLevel -ge 2) { $title = 'APLICAR SEGURO + AVANCADO' }
    Show-Banner $title
    $list = @(Get-BulkList $MaxLevel)
    $todo = @()
    Say ''
    Say ('  Para o SEU hardware (' + (Get-HwSummaryLine) + '):') 'White'
    foreach ($t in $list) {
        $st = Get-TweakState $t
        $ja = L '[ja aplicado]'; $ap = L '[aplicar]'; $pw = [Math]::Max($ja.Length, $ap.Length) + 1
        if ($st -eq 'ON') { Write-Out ('   ' + $ja.PadRight($pw) + (L $t.Name)) 'DarkGray' }
        else { Write-Out ('   ' + $ap.PadRight($pw) + (L $t.Name)) 'Gray'; $todo += $t }
    }
    Say ''
    Say '  Nao entram (fazem perguntas, derrubam a rede ou sao de risco alto): HAGS, LSO, Win32PrioritySeparation, congelar INI, pausar Update, exclusoes do Defender, VBS, MPO, BCDEdit, HID, C0, GPU travada no P0, Spectre.' 'DarkGray'
    if ($todo.Count -eq 0) { Say-Ok 'Nada a fazer: tudo ja esta aplicado.'; Pause-Key; return }
    if (-not (Confirm-Action ('Aplicar {0} otimizacao(oes)? Cada uma guarda o original antes (desfaz em Restaurar).' -f $todo.Count) $true)) { return }
    New-RestorePoint
    $ok = 0; $fail = 0
    foreach ($t in $todo) {
        Say ('  > ' + $t.Name) 'White'
        try { if (Invoke-TweakApply $t) { $ok++; if ($t.Reboot) { $script:NeedReboot = $true } } else { $fail++ } }
        catch { if ($_.Exception.Message -eq 'AUTOKEYS_DONE') { throw }; $fail++; Say-Bad $_.Exception.Message }
    }
    Save-State
    Say ''
    if ($script:Fancy -and $fail -eq 0) { [void](Write-Block (Join-Blocks @((Get-SpriteBlock 'crown'), (Get-BigBlock 'GG' 'yellow')) 4 4)) }
    Say-Ok ('Concluido: {0} aplicada(s), {1} com falha.' -f $ok, $fail)
    Say-Info 'REINICIE o PC. Depois: Fortnite > preset de performance (INI) e o guia in-game.'
    Write-Log ('Bulk nivel {0}: {1} ok, {2} falhas' -f $MaxLevel, $ok, $fail)
    Pause-Key
}
function Menu-Bulk {
    $items = @(
        @{ Label = 'Aplicar TUDO SEGURO (nivel 1) para o meu hardware'; Desc = 'So os itens marcados [SEGURO], filtrados pelo seu hardware (NVIDIA/AMD/Intel, Ryzen, Wi-Fi...). Cria ponto de restauracao e guarda o valor original de tudo.'; Badges = @(); Id = 1 },
        @{ Label = 'Aplicar SEGURO + AVANCADO (niveis 1 e 2)'; Desc = 'Inclui os de efeito moderado (prioridade fixa do jogo, timer forcado, USB, rede...). Nunca inclui os de risco alto nem os que derrubam a rede.'; Badges = @(); Id = 2 },
        @{ Label = 'Voltar'; Desc = ''; Badges = @(); Id = 0 }
    )
    $i = Show-Menu -Title 'APLICAR TUDO' -Sub (Get-HwSummaryLine) -Items $items -Art 'bulk'
    if ($i -lt 0 -or $items[$i].Id -eq 0) { return }
    Invoke-Safe { Invoke-Bulk $items[$i].Id }
}

# ---------------------------------------------------------------------
#  Restaurar
# ---------------------------------------------------------------------
function Restore-Legacy {
    $dir = $script:BackupDir
    $regs = @(Get-ChildItem -LiteralPath $dir -Filter '*.reg' -ErrorAction SilentlyContinue)
    $novos = Join-Path $dir 'valores_novos.txt'
    $novoKeys = @(Get-ChildItem -LiteralPath $dir -Filter '*.novo' -ErrorAction SilentlyContinue)
    $pw = Join-Path $dir 'energia_original.txt'
    $sv = Join-Path $dir 'servicos_original.txt'
    if ($regs.Count -eq 0 -and -not (Test-Path -LiteralPath $novos) -and $novoKeys.Count -eq 0 -and -not (Test-Path -LiteralPath $sv)) { Say-Info 'Nenhum backup do v1.5 encontrado.'; return $false }
    Say ('  Backups do v1.5: {0} arquivo(s) .reg, {1} chave(s) criada(s).' -f $regs.Count, $novoKeys.Count) 'Gray'
    foreach ($f in $regs) { $r = Invoke-Native -File 'reg' -ArgList @('import', $f.FullName); if ($r.Dry -or $r.ExitCode -eq 0) { Say-Ok ('Importado: ' + $f.Name) } else { Say-Warn ('Falhou: ' + $f.Name) } }
    if (Test-Path -LiteralPath $novos) {
        foreach ($l in @(Get-Content -LiteralPath $novos)) {
            $parts = $l -split '\|', 2
            if ($parts.Count -eq 2 -and $parts[0]) { [void](Invoke-Native -File 'reg' -ArgList @('delete', $parts[0], '/v', $parts[1], '/f')) }
        }
    }
    foreach ($f in $novoKeys) { $k = (Get-Content -LiteralPath $f.FullName -TotalCount 1); if ($k) { [void](Invoke-Native -File 'reg' -ArgList @('delete', $k.Trim(), '/f')) } }
    if (Test-Path -LiteralPath $pw) { $g = Get-Guid (Get-Content -LiteralPath $pw -Raw); if ($g) { [void](Invoke-Native -File 'powercfg' -ArgList @('-setactive', $g)); Say-Ok 'Plano de energia original reativado.' } }
    if (Test-Path -LiteralPath $sv) {
        foreach ($l in @(Get-Content -LiteralPath $sv)) {
            $p = $l.Trim() -split '\s+'
            if ($p.Count -ge 2 -and $p[1] -match '^0x[0-9a-fA-F]+$') { [void](Invoke-Native -File 'reg' -ArgList @('add', ('HKLM\SYSTEM\CurrentControlSet\Services\' + $p[0]), '/v', 'Start', '/t', 'REG_DWORD', '/d', ([string][Convert]::ToInt32($p[1], 16)), '/f')) }
        }
        Say-Ok 'Tipo de inicio dos servicos restaurado.'
    }
    if (-not $script:Dry) {
        $arch = Join-Path $dir 'v1.5_restaurado'
        try {
            [void](New-Item -ItemType Directory -Force -Path $arch)
            foreach ($f in @($regs + $novoKeys)) { Move-Item -LiteralPath $f.FullName -Destination $arch -Force }
            foreach ($f in @($novos, $pw, $sv)) { if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination $arch -Force } }
            Say-Info 'Backups antigos movidos para a subpasta "v1.5_restaurado".'
        } catch { }
    }
    return $true
}
function Restore-Everything {
    Say '  Desfazendo (nesta ordem): itens desta versao, depois backups do v1.5.' 'White'
    $o = $script:State.Other
    if ($o.ContainsKey('PowerOrig') -or (Test-PowerPlanActive)) { [void](Undo-Power) }
    if ($o.ContainsKey('Nic')) { [void](Undo-Nic) }
    if ($o.ContainsKey('Dns')) { [void](Undo-Dns) }
    if ($o.ContainsKey('Tcp')) { [void](Undo-Tcp) }
    if ($o.ContainsKey('Lso')) { [void](Undo-Lso) }
    if ($o.ContainsKey('Tunnels')) { [void](Undo-Tunnels) }
    if ($o.ContainsKey('UsbPower')) { [void](Undo-UsbPower) }
    if ($o.ContainsKey('Bcd')) { [void](Undo-Bcd) }
    if ($o.ContainsKey('NvClocks')) { $smi = Get-NvSmi; if ($smi) { [void](Invoke-Native -File $smi -ArgList @('-i', '0', '-rgc')) }; if (-not $script:Dry) { $script:State.Other.Remove('NvClocks') } }
    if (Test-TimerTask) { [void](Undo-TimerForce) }
    if (Test-Path -LiteralPath (Join-Path $script:BackupDir 'audio_fx_backup.json')) { [void](Undo-AudioFx) }
    if (Test-Path -LiteralPath (Get-DefenderList)) { [void](Undo-Defender) }
    if (Check-FnFrozen) { [void](Undo-FnFreeze) }
    if (Check-FnEngine) { [void](Undo-FnEngine) }
    $n = Restore-AllRegs
    Say-Ok ('{0} valor(es) de registro restaurado(s).' -f $n)
    [void](Restore-Legacy)
    Save-State
    Write-Log 'Restaurar tudo'
    Say ''
    Say-Ok 'Pronto. REINICIE o PC para tudo voltar a valer.'
    $script:NeedReboot = $true
    return $true
}
function Restore-FnIni {
    $wc = $script:HW.Fn.ConfigDir
    $any = $false
    foreach ($f in @('GameUserSettings.ini', 'Engine.ini')) {
        $p = Join-Path $wc $f
        if (Test-Path -LiteralPath ($p + '.bak')) {
            if ($script:Dry) { Say-Dry ('restaurar ' + $f); $any = $true; continue }
            try { Set-ItemProperty -LiteralPath $p -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue; Copy-Item -LiteralPath ($p + '.bak') -Destination $p -Force; Say-Ok ('Restaurado: ' + $f); $any = $true } catch { Say-Bad $_.Exception.Message }
        }
    }
    if (-not $any) { Say-Info 'Nenhum .bak dos INIs do Fortnite encontrado.' }
}
function Menu-Restore {
    $sel = 0
    while ($true) {
        $items = @(
            @{ Label = 'DESFAZER TUDO (esta versao + backups do v1.5)'; Desc = 'Restaura cada valor de registro ao original exato, plano de energia, rede (DNS/TCP/adaptador/LSO/tuneis), USB, BCDEdit, timer forcado, audio, Defender e INIs. Depois aplica os backups .reg do v1.5 (se existirem). Reinicie depois.'; Badges = @(); Id = 'all' },
            @{ Label = 'So os backups do v1.5 (arquivos .reg antigos)'; Desc = 'Reimporta os .reg, apaga valores/chaves que o v1.5 criou e volta o plano de energia e os servicos.'; Badges = @(); Id = 'legacy' },
            @{ Label = 'INIs do Fortnite (GameUserSettings.ini / Engine.ini)'; Desc = 'Volta os arquivos ao .bak feito na 1a alteracao.'; Badges = @(); Id = 'ini' },
            @{ Label = 'So o plano de energia'; Desc = 'Reativa o plano que estava ativo antes do "Fortnite Otimizador".'; Badges = @(); Id = 'power' },
            @{ Label = 'Resolucao nativa (Windows + Fortnite)'; Desc = 'Volta a resolucao salva antes dos presets esticados.'; Badges = @(); Id = 'res' },
            @{ Label = 'Reinstalar a Xbox Game Bar (versoes antigas desinstalavam)'; Desc = 'Abre a pagina da Game Bar na Microsoft Store.'; Badges = @(); Id = 'bar' },
            @{ Label = 'Resetar TODOS os planos de energia p/ o padrao de fabrica'; Desc = 'Apaga planos personalizados (inclusive o "Fortnite Otimizador"). Destrutivo.'; Badges = @(); Id = 'plans' },
            @{ Label = 'Abrir a pasta de backups'; Desc = $script:BackupDir; Badges = @(); Id = 'open' },
            @{ Label = 'Voltar'; Desc = ''; Badges = @(); Id = 'back' }
        )
        $i = Show-Menu -Title 'RESTAURAR / DESFAZER' -Sub ('Backups em: ' + $script:BackupDir) -Items $items -Selected $sel -Art 'restore'
        if ($i -lt 0 -or $items[$i].Id -eq 'back') { return }
        $sel = $i
        Invoke-Safe {
            switch ($items[$i].Id) {
                'all'    { if (Confirm-Action 'Desfazer TUDO que este otimizador (e o v1.5) alterou?' $false) { [void](Restore-Everything); Pause-Key } }
                'legacy' { if (Confirm-Action 'Aplicar os backups .reg do v1.5?' $false) { [void](Restore-Legacy); Pause-Key } }
                'ini'    { Restore-FnIni; Pause-Key }
                'power'  { [void](Undo-Power); Pause-Key }
                'res'    {
                    $f = Get-NativeFile
                    if (-not (Test-Path -LiteralPath $f)) { Say-Info 'Sem resolucao nativa salva.' }
                    else { $p = (Get-Content -LiteralPath $f -Raw).Trim() -split '\s+'; if ($script:Dry) { Say-Dry ('SetMode ' + $p[0] + 'x' + $p[1] + '@' + $p[2]) } else { [void][FnoNative]::SetMode([uint32]$p[0], [uint32]$p[1], [uint32]$p[2], $false); [void](Sync-FnResolution ([int]$p[0]) ([int]$p[1])) } }
                    Pause-Key
                }
                'bar'    { if (-not $script:Dry) { Start-Process 'ms-windows-store://pdp/?ProductId=9NZKPSTSNW4P' } else { Say-Dry 'abrir Store' }; Pause-Key }
                'plans'  { if (Confirm-Action 'Isto APAGA planos de energia personalizados. Continuar?' $false 'Red') { [void](Invoke-Native -File 'powercfg' -ArgList @('-restoredefaultschemes')); Say-Ok 'Planos de fabrica.'; Pause-Key } }
                'open'   { if (-not $script:Dry) { Start-Process explorer.exe $script:BackupDir } else { Say-Dry 'abrir pasta' } }
            }
        }
    }
}

# ---------------------------------------------------------------------
#  Menu principal
# ---------------------------------------------------------------------
function Main-Menu {
    $sel = 0
    while ($true) {
        $items = @(
            @{ Label = 'Diagnostico (hardware, alertas, ping, timer)'; Desc = 'Detecta GPU/CPU/RAM/rede/tela, avisa o que esta fora do ideal (Hz abaixo do maximo, RAM lenta, Wi-Fi...) e mede ping, jitter e o timer.'; Badges = @(); Id = 'diag' },
            @{ Label = 'Input Lag: tela, mouse, USB, MSI, jogo, seguranca'; Desc = 'Taxa de atualizacao maxima, Game Mode, mouse, USB/HID, MSI Mode, FSO, HAGS, audio e itens de risco (VBS, MPO, BCDEdit).'; Badges = @(); Id = 'lag' },
            @{ Label = 'CPU / Energia / Timer / Prioridades'; Desc = 'Plano de energia proprio, timer do Windows, prioridade do Fortnite, C-states. Detecta Intel x Ryzen (X3D tratado a parte).'; Badges = (Get-TagBadges @('INTEL', 'RYZEN')); Id = 'cpu' },
            @{ Label = 'GPU: NVIDIA / AMD / Intel'; Desc = 'Perfil de baixa latencia via NVIDIA Profile Inspector (automatico), overlay, clock. Guias para AMD e Intel. Cada item mostra a marca.'; Badges = (Get-TagBadges @('NV', 'AMD', 'INTELGPU')); Id = 'gpu' },
            @{ Label = 'Rede: Ethernet e Wi-Fi'; Desc = 'Adaptador (por palavra-chave do driver), DNS, TCP, tuneis, LSO, reset. Detecta se voce esta no cabo ou no Wi-Fi.'; Badges = (Get-TagBadges @('WIFI', 'ETH')); Id = 'net' },
            @{ Label = 'Fortnite: INI, launch options, foco, resolucao esticada'; Desc = 'Preset de performance no GameUserSettings.ini, modo foco, resolucoes esticadas de pro, replays, verificar arquivos.'; Badges = @(); Id = 'fn' },
            @{ Label = 'Sistema: limpeza, servicos, update, Defender'; Desc = 'Temporarios, apps em 2o plano, servicos pesados, pausar update, exclusoes do Defender, SSD x HD.'; Badges = @(); Id = 'sys' },
            @{ Label = 'Programas e integracoes (winget)'; Desc = 'Instala e abre por aqui: NVIDIA Profile Inspector, CapFrameX, LatencyMon, ISLC, HWiNFO, Process Lasso, DDU, CRU...'; Badges = @(); Id = 'apps' },
            @{ Label = 'APLICAR TUDO (para o meu hardware)'; Desc = 'Aplica em lote os itens SEGUROS (ou seguros + avancados) filtrados pelo seu hardware, com ponto de restauracao e backup de cada valor.'; Badges = @(); Id = 'bulk' },
            @{ Label = 'Guias: jogo, BIOS, hardware, por marca'; Desc = 'Texto de referencia: configuracao in-game, BIOS Intel/Ryzen, NVIDIA/AMD/Intel, rede, hardware fisico.'; Badges = @(); Id = 'guides' },
            @{ Label = 'Restaurar / desfazer'; Desc = 'Volta tudo ao original: valores de registro exatos, energia, rede, INIs, e os backups da versao 1.5.'; Badges = @(); Id = 'restore' },
            @{ Label = 'Sair'; Desc = ''; Badges = @(); Id = 'exit' }
        )
        $sub = Get-HwSummaryLine
        if ($script:NeedReboot) { $sub = '[!] REINICIO PENDENTE   ' + $sub }
        $i = Show-Menu -Title 'MENU PRINCIPAL' -Sub $sub -Items $items -Selected $sel -Art 'logo' -Foot 'Setas: mover | Enter: escolher | Esc: sair | 0-9: pular'
        if ($i -lt 0) { if (Confirm-Action 'Sair do otimizador?' $true) { return } else { continue } }
        $sel = $i
        switch ($items[$i].Id) {
            'diag'    { Invoke-Safe { Menu-Diag } }
            'lag'     { Invoke-Safe { Menu-Group -Art 'lag' -Group 'lag' -Title 'INPUT LAG' -Sub 'Tela, mouse, USB, MSI, jogo e seguranca. Etiquetas mostram a que hardware cada item se aplica.' -GuideIds @('hw') } }
            'cpu'     { Invoke-Safe { Menu-Group -Art 'cpu' -Group 'cpu' -Title 'CPU / ENERGIA / TIMER' -Sub ('CPU detectada: ' + $script:HW.Cpu.Name) -GuideIds @('bios') } }
            'gpu'     { Invoke-Safe { Menu-Gpu } }
            'net'     { Invoke-Safe { Menu-Group -Art 'net' -Group 'net' -Title 'REDE: ETHERNET / WI-FI' -Sub ('Conexao principal: ' + $script:HW.Net.Kind + '  ' + $script:HW.Net.Desc) -GuideIds @('net') } }
            'fn'      { Invoke-Safe { Menu-Group -Art 'fn' -Group 'fn' -Title 'FORTNITE' -Sub 'Feche o jogo antes de editar os INIs.' -GuideIds @('ingame') } }
            'sys'     { Invoke-Safe { Menu-Group -Art 'sys' -Group 'sys' -Title 'SISTEMA' -Sub 'Limpeza, servicos, update e Defender.' } }
            'apps'    { Invoke-Safe { Menu-Apps } }
            'bulk'    { Invoke-Safe { Menu-Bulk } }
            'guides'  { Invoke-Safe { Menu-Guides } }
            'restore' { Invoke-Safe { Menu-Restore } }
            'exit'    { if (Confirm-Action 'Sair do otimizador?' $true) { return } }
        }
    }
}

# =====================================================================
#  SPLASH (caveira) com carregamento REAL da deteccao, SELF-TEST, ENTRADA
# =====================================================================
$script:SkullA = @'
                      :::!~!!!!!:.
                  .xUHWH!! !!?M88WHX:.
                .X*#M@$!!  !X!M$$$$$$WWx:.
               :!!!!!!?H! :!$!$$$$$$$$$$8X:
              !!~  ~:~!! :~!$!#$$$$$$$$$$8X:
             :!~::!H!<   ~.U$X!?R$$$$$$$$MM!
             ~!~!!!!~~ .:XW$$$U!!?$$$$$$RMM!
               !:~~~ .:!M"T#$$$$WX??#MRRMMM!
               ~?WuxiW*`   `"#$$$$8!!!!??!!!
             :X- M$$$$       `"T#$T~!8$WUXU~
            :%`  ~#$$$m:        ~!~ ?$$$$$$
          :!`.-   ~T$$$$8xx.  .xWW- ~""##*"
.....   -~~:<` !    ~?T#$$@@W@*?$$      /`
W$@@M!!! .!~~ !!     .:XUW$W!~ `"~:    :
#"~~`.:x%`!!  !H:   !WM$$$$Ti.: .!WUn+!`
:::~:!!`:X~ .: ?H.!u "$$$B$$$!W:U!T$$M~
.~~   :X@!.-~   ?@WTWo("*$$$W$TH$! `
Wi.~!X$?!-~    : ?$$$B$Wu("**$RM!
$R@i.~~ !     :   ~$$$$$B$$en:``
?MXT@Wx.~    :     ~"##*$$$$M~
'@

function Get-SkullFrame {
    param([bool]$Alt)
    $lines = @($script:SkullA -split "`r?`n")
    if (-not $Alt) { return $lines }
    $o = @()
    foreach ($l in $lines) { $o += ($l.Replace('!', [string][char]1).Replace('~', '!').Replace([string][char]1, '~')) }
    return $o
}
$script:SkullColors = @('White', 'White', 'Cyan', 'Cyan', 'Cyan', 'Cyan', 'DarkCyan', 'DarkCyan', 'DarkCyan', 'DarkCyan', 'DarkCyan', 'DarkCyan', 'Blue', 'Blue', 'Blue', 'Blue', 'DarkGray', 'DarkGray', 'DarkGray', 'DarkGray')
function Get-SplashPanel {
    param([string]$Msg, [int]$Pct, [string]$Hint, [int]$Step)
    $g = $script:G
    $in = 34
    $p = @{}
    $t = @()
    $t += , @(@{ T = (Center (L 'FORTNITE OTIMIZADOR') $in); F = 'White' })
    $t += , @(@{ T = (Center ('v' + $script:Version + '  ' + $g.Dot + '  ' + (L 'input lag no minimo')) $in); F = 'Yellow' })
    $tb = New-BoxBlock $t $in 'Cyan'
    for ($i = 0; $i -lt $tb.Lines.Count; $i++) { $p[2 + $i] = $tb.Lines[$i] }
    $spin = @('|', '/', '-', '\')[$Step % 4]
    if ($Pct -ge 100) { $spin = $g.Chk }
    $p[7] = @(@{ T = ($spin + ' '); F = 'Magenta' }, @{ T = (L $Msg); F = 'Yellow' })
    $len = 28
    $n = [int]([Math]::Round($len * [Math]::Min(100, $Pct) / 100))
    $p[9] = @(@{ T = '['; F = 'DarkGray' }, @{ T = ($g.Full * $n); F = 'Green' }, @{ T = ($g.Sh1 * ($len - $n)); F = 'DarkGray' }, @{ T = '] '; F = 'DarkGray' }, @{ T = ('{0,3}%' -f $Pct); F = 'White' })
    $p[11] = @(@{ T = (L $Hint); F = 'DarkGray' })
    $c = @()
    $c += , @(@{ T = '  Made by: '; F = 'Magenta' }, @{ T = $script:CreditBy; F = 'Yellow' })
    $c += , @(@{ T = '  Discord: '; F = 'Cyan' }, @{ T = $script:CreditDiscord; F = 'Green' })
    $cb = New-BoxBlock $c $in 'Magenta'
    for ($i = 0; $i -lt $cb.Lines.Count; $i++) { $p[14 + $i] = $cb.Lines[$i] }
    return $p
}
function Show-SplashFrame {
    param([int]$Step, [string]$Msg, [int]$Pct, [string]$Hint)
    $w = Get-UiWidth
    $frame = Get-SkullFrame (($Step % 2) -eq 1)
    $panel = Get-SplashPanel $Msg $Pct $Hint $Step
    if ($script:CanCursor) { Set-Cur 0 0 }
    $logo = Get-ArtBlock 'logo' $w ((Get-UiHeight) - 25)
    if ($logo) { [void](Write-Block $logo $w) }
    Say (' ' * $w)
    for ($i = 0; $i -lt $frame.Count; $i++) {
        $c = $script:SkullColors[[Math]::Min($i, $script:SkullColors.Count - 1)]
        Write-Host ('  ' + ($frame[$i]).PadRight(50)) -NoNewline -ForegroundColor $c
        $segs = New-Object System.Collections.ArrayList
        if ($panel.ContainsKey($i)) { foreach ($s in @($panel[$i])) { Add-Seg $segs $s.T $s.F $s.B } }
        Write-SegLine $segs ([Math]::Max(0, $w - 52))
    }
}
function Show-Splash {
    if ($script:CanCursor) { Clear-Screen }
    $steps = @(
        @{ M = 'Lendo o sistema operacional...'; B = { Detect-Os } },
        @{ M = 'Detectando GPU (NVIDIA / AMD / Intel)...'; B = { Detect-Gpu } },
        @{ M = 'Detectando CPU e memoria...'; B = { Detect-Cpu } },
        @{ M = 'Detectando rede (cabo / Wi-Fi)...'; B = { Detect-Net } },
        @{ M = 'Lendo a taxa de atualizacao da tela...'; B = { Detect-Display } },
        @{ M = 'Procurando o Fortnite...'; B = { Detect-Fortnite } }
    )
    $n = $steps.Count
    for ($i = 0; $i -lt $n; $i++) {
        Show-SplashFrame -Step $i -Msg $steps[$i].M -Pct ([int](100 * $i / $n)) -Hint 'Aguarde...'
        & $steps[$i].B
    }
    Show-SplashFrame -Step 0 -Msg 'Pronto!' -Pct 100 -Hint 'Pressione qualquer tecla para iniciar...'
    Say ''
    Say ('  ' + (Get-HwSummaryLine)) 'White'
    if ($script:HW.Errors.Count -gt 0) { foreach ($e in $script:HW.Errors) { Say-Warn ('Deteccao parcial: ' + $e) } }
    if ($script:Dry -and $env:FNO_SHOT -ne '1') { Say '  MODO TESTE: nada sera gravado no sistema.' 'Yellow' }
    if ($ScreenDump) { Save-ScreenDump }
    if (-not $NoSplash -and -not $script:AutoActive -and $script:UseKeys) { [void](Read-Key) }
}

# ---------------------------------------------------------------------
#  SELF-TEST (usado no desenvolvimento: -SelfTest)
# ---------------------------------------------------------------------
$script:TPass = 0
$script:TFail = 0
function T {
    param([string]$Name, [scriptblock]$Body)
    try {
        $res = @(& $Body)
        if ($res.Count -eq 0 -or $res[-1] -ne $true) { $script:TFail++; Write-Host ('  FAIL  ' + $Name + '  (resultado: ' + ($res -join ',') + ')') -ForegroundColor Red }
        else { $script:TPass++; Write-Host ('  ok    ' + $Name) -ForegroundColor Green }
    } catch {
        $script:TFail++
        Write-Host ('  FAIL  ' + $Name + '  -> ' + $_.Exception.Message) -ForegroundColor Red
    }
}
function Invoke-SelfTest {
    Write-Host ''
    Write-Host '=== SELF-TEST ===' -ForegroundColor Cyan
    $script:Dry = $true
    Detect-All
    Register-WindowsTweaks; Register-NetTweaks; Register-GpuTweaks; Register-FnSysTweaks; Register-ExtraTweaks

    T 'hardware detectado (GPU/CPU/RAM/rede/tela)' { ($script:HW.Gpu -ne $null) -and $script:HW.Cpu.Name -and $script:HW.Ram.TotalGB -gt 0 -and $script:HW.Display.W -gt 0 }
    T 'catalogo: Ids unicos' { $ids = @($script:Tweaks | ForEach-Object { $_.Id }); ($ids | Select-Object -Unique).Count -eq $ids.Count }
    T 'catalogo: campos obrigatorios' {
        $bad = @($script:Tweaks | Where-Object { -not $_.Name -or -not $_.Desc -or -not $_.Group -or $null -eq $_.Level -or -not $_.Tags -or (@('toggle', 'action') -notcontains $_.Kind) })
        if ($bad.Count) { Write-Host ('     faltando: ' + (($bad | ForEach-Object { $_.Id }) -join ',')) -ForegroundColor Red }
        $bad.Count -eq 0
    }
    T 'catalogo: toggle tem Apply ou RegsFn; action tem Apply' {
        $bad = @($script:Tweaks | Where-Object { ($_.Kind -eq 'toggle' -and -not $_.Apply -and -not $_.RegsFn) -or ($_.Kind -eq 'action' -and -not $_.Apply) })
        $bad.Count -eq 0
    }
    T 'catalogo: descricoes so ASCII' {
        $bad = @($script:Tweaks | Where-Object { ($_.Name + $_.Desc) -match '[^\x00-\x7F]' })
        if ($bad.Count) { Write-Host ('     nao-ascii: ' + (($bad | ForEach-Object { $_.Id }) -join ',')) -ForegroundColor Red }
        $bad.Count -eq 0
    }
    foreach ($t in $script:Tweaks) {
        $tt = $t
        if ($tt.RegsFn) {
            T ('regs bem formados: ' + $tt.Id) { $r = @(& $tt.RegsFn); $ok = $true; foreach ($x in $r) { if (-not $x.P -or -not $x.N -or -not $x.T -or $null -eq $x.V) { $ok = $false } }; $ok }
        }
        if ($tt.Kind -eq 'toggle') {
            T ('estado (leitura): ' + $tt.Id) { $s = Get-TweakState $tt; @('ON', 'OFF', '') -contains $s }
        }
        T ('item de menu: ' + $tt.Id) { $it = New-TweakItem $tt; $it.Label -and $it.Desc -and ($null -ne $it.Badges) }
    }
    # aplicar/desfazer em DRY-RUN
    $script:AutoActive = $true
    $script:UseKeys = $true
    foreach ($t in $script:Tweaks) {
        if ($t.Kind -ne 'toggle') { continue }
        $tt = $t
        T ('dry-run aplicar+desfazer: ' + $tt.Id) {
            $script:KeyQueue.Clear(); $script:KeyQueue.Enqueue('enter')
            $null = Invoke-TweakApply $tt
            $null = Invoke-TweakUndo $tt
            $true
        }
    }
    T 'bulk nivel 1 tem itens' { @(Get-BulkList 1).Count -gt 5 }
    T 'bulk nivel 2 > nivel 1' { @(Get-BulkList 2).Count -gt @(Get-BulkList 1).Count }
    T 'bulk nunca inclui risco alto / NoBulk' { @(Get-BulkList 2 | Where-Object { $_.Level -ge 3 -or $_.NoBulk }).Count -eq 0 }

    # registro: ida e volta numa chave de teste (HKCU) com estado isolado
    T 'registro: backup exato, restore, chave criada removida' {
        $old = @{ D = $script:Dry; S = $script:State; F = $script:StateFile; B = $script:BackupDir }
        try {
            $script:Dry = $false
            $script:BackupDir = Join-Path $env:TEMP 'FNO_SelfTest'
            [void](New-Item -ItemType Directory -Force -Path $script:BackupDir)
            $script:StateFile = Join-Path $script:BackupDir 'state_v2.json'
            Remove-Item -LiteralPath $script:StateFile -Force -ErrorAction SilentlyContinue
            Load-State
            $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\FNO_SelfTest\Sub'); $k.SetValue('E', 7, 'DWord'); $k.SetValue('S', 'orig', 'String'); $k.Close()
            $regs = @((Rg 'HKCU\Software\FNO_SelfTest\Sub' 'E' 'DWord' 4294967295), (Rg 'HKCU\Software\FNO_SelfTest\Sub' 'S' 'String' 'novo'), (Rg 'HKCU\Software\FNO_SelfTest\Sub' 'N' 'DWord' 1), (Rg 'HKCU\Software\FNO_SelfTest\Deep\A\B' 'X' 'DWord' 5))
            $a = Apply-Regs $regs
            $c1 = Test-Regs $regs
            Save-State; Load-State
            $u = Undo-Regs $regs
            $e = Get-Reg 'HKCU\Software\FNO_SelfTest\Sub' 'E'
            $s = Get-Reg 'HKCU\Software\FNO_SelfTest\Sub' 'S'
            $n = Get-Reg 'HKCU\Software\FNO_SelfTest\Sub' 'N'
            $deep = Open-RegKey 'HKCU\Software\FNO_SelfTest\Deep'
            $ok = $a -and $c1 -and $u -and ([int]$e -eq 7) -and ($s -eq 'orig') -and ($null -eq $n) -and ($null -eq $deep) -and -not (Test-Regs $regs)
            $ok
        } finally {
            try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\FNO_SelfTest', $false) } catch { }
            Remove-Item -LiteralPath (Join-Path $env:TEMP 'FNO_SelfTest') -Recurse -Force -ErrorAction SilentlyContinue
            $script:Dry = $old.D; $script:State = $old.S; $script:StateFile = $old.F; $script:BackupDir = $old.B
        }
    }

    # INI: preset em copia temporaria (UTF-16 e UTF-8), sem tocar no INI real
    foreach ($enc in @('utf16', 'utf8')) {
        $e2 = $enc
        T ('INI: preset em arquivo de teste (' + $e2 + ')') {
            $tmp = Join-Path $env:TEMP ('fno_gus_' + $e2 + '.ini')
            $txt = "[/Script/FortniteGame.FortGameUserSettings]`r`nbUseVSync=True`r`nFrameRateLimit=120.000000`r`nResolutionSizeX=1920`r`nFullscreenMode=1`r`n[ScalabilityGroups]`r`nsg.ShadowQuality=3`r`n"
            if ($e2 -eq 'utf16') { [IO.File]::WriteAllText($tmp, $txt, [Text.Encoding]::Unicode) } else { [IO.File]::WriteAllText($tmp, $txt, (New-Object Text.UTF8Encoding($false))) }
            $oldIni = $script:HW.Fn.Ini; $oldDry = $script:Dry
            try {
                $script:HW.Fn.Ini = $tmp
                $ini = Apply-FnIni -Fps 0
                $script:Dry = $false
                $saved = Save-IniFile $ini
                $script:Dry = $oldDry
                $bytes = [IO.File]::ReadAllBytes($tmp)
                $isU16 = ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)
                $back = Read-IniFile $tmp
                $t2 = ($back.Lines -join "`n")
                $ok = $saved -and ($t2 -match 'bUseVSync=False') -and ($t2 -match 'FrameRateLimit=0\.000000') -and ($t2 -match 'FullscreenMode=0') -and ($t2 -match 'ResolutionSizeX=1920') -and ($t2 -match 'sg\.ShadowQuality=0') -and ($t2 -match 'sg\.TextureQuality=0') -and ($isU16 -eq ($e2 -eq 'utf16'))
                if (-not $ok) { Write-Host $t2 -ForegroundColor DarkGray }
                $ok
            } finally { $script:HW.Fn.Ini = $oldIni; $script:Dry = $oldDry; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
    T 'INI: remover chave' {
        $ini = @{ Path = 'x'; Enc = [Text.Encoding]::UTF8; Lines = (New-Object 'System.Collections.Generic.List[string]'); Changes = @() }
        $ini.Lines.AddRange([string[]]@('[SystemSettings]', 'r.GTSyncType=1', 'r.Other=2'))
        Remove-IniKey $ini 'SystemSettings' 'r.GTSyncType'
        ($ini.Lines -join ',') -eq '[SystemSettings],r.Other=2'
    }
    T 'NVIDIA .nip: XML valido e IDs conferidos' {
        $xml = New-NipXml (Get-NpiSettings)
        $d = New-Object System.Xml.XmlDocument; $d.LoadXml($xml)
        $ids = @($d.SelectNodes('//ProfileSetting/SettingID') | ForEach-Object { [uint32]$_.InnerText })
        $want = @(0x1057EB71, 0x007BA09E, 0x10835000, 0x0005F543, 0x00CE2691, 0x0064B541)
        $ok = ($d.DocumentElement.Name -eq 'ArrayOfProfile') -and ($d.SelectSingleNode('//Profile/ProfileName').InnerText -eq 'Fortnite') -and (@($want | Where-Object { $ids -notcontains [uint32]$_ }).Count -eq 0)
        $ok
    }
    T 'NVIDIA .nip: desserializa com as MESMAS classes do Profile Inspector' {
        if (-not ('NipTest.Profile' -as [type])) {
            Add-Type -ReferencedAssemblies 'System.Xml' -TypeDefinition @'
using System; using System.Collections.Generic; using System.Xml.Serialization;
namespace NipTest {
  public enum SettingValueType : int { Dword, AnsiString, String, Binary, Qword }
  [Serializable] public class ProfileSetting { public string SettingNameInfo = ""; [XmlElement(ElementName = "SettingID")] public uint SettingId = 0; public string SettingValue = "0"; public SettingValueType ValueType = SettingValueType.Dword; }
  [Serializable] public class Profile { public string ProfileName = ""; public List<string> Executeables = new List<string>(); public List<ProfileSetting> Settings = new List<ProfileSetting>(); }
  [Serializable] public class Profiles : List<Profile> { }
}
'@
        }
        $tmp = Join-Path $env:TEMP 'fno_test.nip'
        [IO.File]::WriteAllText($tmp, (New-NipXml (Get-NpiSettings)), [Text.Encoding]::Unicode)
        $ser = New-Object System.Xml.Serialization.XmlSerializer([NipTest.Profiles])
        $fs = [IO.File]::OpenRead($tmp)
        try { $p = $ser.Deserialize($fs) } finally { $fs.Close(); Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        ($p.Count -eq 1) -and ($p[0].ProfileName -eq 'Fortnite') -and ($p[0].Settings.Count -eq 6) -and ($p[0].Executeables[0] -eq 'fortniteclient-win64-shipping.exe')
    }
    T 'ajustes do adaptador: leitura sem erro' { $null = Get-NicChanges; $true }
    T 'checks de rede (TCP/tuneis/LSO/USB): sem excecao' { $null = Check-Tcp; $null = Check-Tunnels; $null = Check-Lso; $null = Check-UsbPower; $true }
    T 'plano de energia: leitura' { (Get-ActivePlan) -match '^[0-9a-f-]{36}$' }
    T 'MSI: alvos e estado' { $t = @(Get-MsiTargets); ($t.Count -ge 1) -and (@('ON', 'OFF', 'PADRAO') -contains (Get-MsiState $t[0].Id)) }
    T 'timer: leitura e medicao' { $t = [FnoNative]::TimerInfo(); $s = [FnoNative]::MeasureSleep(5); ($t[1] -gt 0) -and ($s[0] -gt 0) }
    T 'tela: modos e modo atual' { ([FnoNative]::AllModes().Count -gt 0) -and ([FnoNative]::CurrentMode()[0] -gt 0) }
    T 'ping (localhost)' { $r = Test-EpicPing -HostName 'localhost' -Count 2; $r.Ok }
    T 'guias: todos com conteudo ASCII' {
        $ok = $true
        foreach ($g in @('InGame', 'Hardware', 'Bios', 'Nvidia', 'Amd', 'IntelGpu', 'Net', 'Myths')) {
            $l = @(& ('Get-Guide' + $g))
            if ($l.Count -lt 5) { $ok = $false }
            if (($l -join '') -match '[^\x00-\x7F]') { $ok = $false; Write-Host ('     nao-ascii no guia ' + $g) -ForegroundColor Red }
        }
        $ok
    }
    T 'programas (winget): IDs e campos' { $bad = @($script:Apps | Where-Object { -not $_.Id -or -not $_.Exe -or -not $_.Name -or -not $_.Match }); $bad.Count -eq 0 }
    T 'menu com setas (teclas simuladas)' {
        $script:KeyQueue.Clear()
        foreach ($k in 'down', 'down', 'enter') { $script:KeyQueue.Enqueue($k) }
        $items = @(@{ Label = 'a'; Badges = @() }, @{ Label = 'b'; Badges = @() }, @{ Label = 'c'; Badges = @() }, @{ Header = $true; Label = 'h' }, @{ Label = 'd'; Badges = @() })
        $r = Show-Menu -Title 't' -Items $items 6>$null
        $r -eq 2
    }
    T 'menu: cabecalho e ignorado; Esc volta -1' {
        $script:KeyQueue.Clear()
        foreach ($k in 'down', 'down', 'down', 'up', 'up', 'esc') { $script:KeyQueue.Enqueue($k) }
        $items = @(@{ Label = 'a'; Badges = @() }, @{ Header = $true; Label = 'h' }, @{ Label = 'b'; Badges = @() })
        $r = Show-Menu -Title 't' -Items $items 6>$null
        $script:KeyQueue.Clear()
        $r -eq -1
    }
    T 'confirmacao Sim/Nao com setas' {
        $script:KeyQueue.Clear()
        foreach ($k in 'right', 'enter') { $script:KeyQueue.Enqueue($k) }
        $a = Confirm-Action 'teste' $false 6>$null
        foreach ($k in 'n') { $script:KeyQueue.Enqueue($k) }
        $b = Confirm-Action 'teste' $true 6>$null
        ($a -eq $true) -and ($b -eq $false)
    }
    T 'guias: estilo de linha valido (cores existem)' {
        $ok = $true
        foreach ($g in @('InGame', 'Hardware', 'Bios', 'Nvidia', 'Amd', 'IntelGpu', 'Net', 'Myths')) {
            foreach ($l in @(& ('Get-Guide' + $g))) {
                $st = @(Get-TextLineStyle $l)
                if ($st.Count -ne 2 -or -not [Enum]::IsDefined([ConsoleColor], [string]$st[1])) { $ok = $false; Write-Host ('     estilo invalido: ' + $l) -ForegroundColor Red }
            }
        }
        $ok
    }
    # --- WALKER: roda cada otimizacao / menu em dry-run com teclas simuladas ---
    $keysMix = @('y', 'enter', 'y', 'enter', 'y', 'enter', 'y', 'enter', 'y', 'enter', 'y', 'enter', 'esc', 'esc', 'esc')
    foreach ($t in $script:Tweaks) {
        $tt = $t
        T ('walker: Run-Tweak ' + $tt.Id) {
            $script:KeyQueue.Clear(); foreach ($k in $keysMix) { $script:KeyQueue.Enqueue($k) }
            $script:BadMsgs = @()
            try { Run-Tweak $tt 6>$null } catch { if ($_.Exception.Message -ne 'AUTOKEYS_DONE') { throw } }
            $script:KeyQueue.Clear()
            $real = @($script:BadMsgs | Where-Object { $_ -match 'inesperado' })
            foreach ($bm in @($script:BadMsgs | Where-Object { $_ -notmatch 'inesperado' })) { Write-Host ('     nota: ' + $bm) -ForegroundColor DarkYellow }
            if ($real.Count) { Write-Host ('     ' + ($real -join ' | ')) -ForegroundColor Red }
            $real.Count -eq 0
        }
    }
    $menus = @(
        @{ N = 'Main-Menu'; K = @('enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'esc', 'y') },
        @{ N = 'Menu-Diag'; K = @('enter', 'enter', 'down', 'enter', 'enter', 'down', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'esc') },
        @{ N = 'Menu-Gpu'; K = @('esc') },
        @{ N = 'Menu-Apps'; K = @('enter', 'enter', 'esc', 'esc') },
        @{ N = 'Menu-Guides'; K = @('enter', 'enter', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'down', 'enter', 'enter', 'esc') },
        @{ N = 'Menu-Bulk'; K = @('enter', 'y', 'enter') },
        @{ N = 'Menu-Bulk2'; K = @('down', 'enter', 'y', 'enter') },
        @{ N = 'Menu-Restore'; K = @('enter', 'y', 'enter', 'down', 'enter', 'y', 'enter', 'down', 'enter', 'enter', 'esc') },
        @{ N = 'Menu-StretchRes'; K = @('enter', 'y', 'enter', 'down', 'down', 'down', 'down', 'down', 'enter', 'y', 'enter', 'down', 'enter', 'enter', 'esc') },
        @{ N = 'Menu-Msi'; K = @('enter', 'enter', 'down', 'enter', 'y', 'enter', 'esc') },
        @{ N = 'Menu-Bcd'; K = @('enter', 'enter', 'esc') }
    )
    foreach ($m in $menus) {
        $mm = $m
        T ('walker: ' + $mm.N) {
            $script:KeyQueue.Clear(); foreach ($k in $mm.K) { $script:KeyQueue.Enqueue($k) }
            $script:BadMsgs = @()
            $fn = $mm.N -replace '2$', ''
            try {
                if ($fn -eq 'Menu-Group') { Menu-Group -Group 'lag' -Title 'x' } else { & $fn 6>$null }
            } catch { if ($_.Exception.Message -ne 'AUTOKEYS_DONE') { throw } }
            $script:KeyQueue.Clear()
            $real = @($script:BadMsgs | Where-Object { $_ -match 'inesperado' })
            foreach ($bm in @($script:BadMsgs | Where-Object { $_ -notmatch 'inesperado' })) { Write-Host ('     nota: ' + $bm) -ForegroundColor DarkYellow }
            if ($real.Count) { Write-Host ('     ' + ($real -join ' | ')) -ForegroundColor Red }
            $real.Count -eq 0
        }
    }
    foreach ($grp in @('lag', 'cpu', 'net', 'fn', 'sys')) {
        $g2 = $grp
        T ('walker: Menu-Group ' + $g2) {
            $script:KeyQueue.Clear(); foreach ($k in @('enter', 'enter', 'esc', 'down', 'down', 'enter', 'y', 'enter', 'esc', 'esc')) { $script:KeyQueue.Enqueue($k) }
            $script:BadMsgs = @()
            try { Menu-Group -Group $g2 -Title 'x' -Sub 'y' -GuideIds @('hw') 6>$null } catch { if ($_.Exception.Message -ne 'AUTOKEYS_DONE') { throw } }
            $script:KeyQueue.Clear()
            @($script:BadMsgs | Where-Object { $_ -match 'inesperado' }).Count -eq 0
        }
    }
    T 'creditos aparecem em banner, menu, guia e despedida' {
        $o1 = (Show-Banner 'x' 6>&1 | ForEach-Object { [string]$_ }) -join ''
        $script:KeyQueue.Clear(); $script:KeyQueue.Enqueue('esc')
        $o2 = (Show-Menu -Title 't' -Items @(@{ Label = 'a'; Badges = @() }) 6>&1 | ForEach-Object { [string]$_ }) -join ''
        $script:KeyQueue.Clear()
        $script:KeyQueue.Enqueue('enter')
        $o3 = (Show-Text 'g' @('linha') 6>&1 | ForEach-Object { [string]$_ }) -join ''
        $ok = $true
        foreach ($o in @($o1, $o2, $o3)) { if ($o -notmatch 'Made by: ' -or $o -notmatch 'Lina' -or $o -notmatch 'Discord: ' -or $o -notmatch 'kali_linax') { $ok = $false } }
        $ok
    }
    T 'plano: configuracoes bem formadas (todos os perfis)' {
        $ok = $true
        foreach ($pf in @('classic', 'hybrid', 'ryzen', 'x3d2')) {
            $l = @(Get-PlanSettings $pf)
            if ($l.Count -lt 10) { $ok = $false }
            foreach ($x in $l) {
                if ($x.Sub -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' -or $x.Set -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' -or $x.V -isnot [int] -or -not $x.N) { $ok = $false; Write-Host ('     ruim: ' + $x.N) -ForegroundColor Red }
            }
            $dupe = @($l | Group-Object { $_.Set } | Where-Object { $_.Count -gt 1 })
            if ($dupe.Count) { $ok = $false; Write-Host ('     duplicada em ' + $pf) -ForegroundColor Red }
        }
        $ok
    }
    T 'plano: X3D 2 CCDs NAO mexe em core parking; classico trava minimo 100; hibrido prefere P-cores' {
        $CP = '0cc5b647-c1df-4637-891a-dec35c318583'; $CX = 'ea062031-0e34-4ff1-9b6d-eb1059334028'; $UP = '616cdaa5-695e-4545-97ad-97dc2d1bdd88'; $MN = '893dee8e-2bef-41e0-89c6-b55d0929964c'; $SP = '93b8b6dc-0698-4d1c-9ee4-0644e900c85d'
        $x = @(Get-PlanSettings 'x3d2'); $c = @(Get-PlanSettings 'classic'); $h = @(Get-PlanSettings 'hybrid'); $r = @(Get-PlanSettings 'ryzen')
        $a = (@($x | Where-Object { @($CP, $CX, $UP) -contains $_.Set }).Count -eq 0)
        $wantMin = 100; if ($script:HW.Laptop) { $wantMin = 5 }
        $b = ((@($c | Where-Object { $_.Set -eq $MN })[0]).V -eq $wantMin)
        $d = ((@($h | Where-Object { $_.Set -eq $MN })[0]).V -eq 5) -and ((@($h | Where-Object { $_.Set -eq $SP })[0]).V -eq 2)
        $e = ((@($r | Where-Object { $_.Set -eq $MN })[0]).V -eq 5) -and (@($r | Where-Object { $_.Set -eq $CP }).Count -eq 1)
        $a -and $b -and $d -and $e
    }
    T 'plano: deteccao de perfil por CPU (simulado)' {
        $old = $script:HW.Cpu
        try {
            $script:HW.Cpu = @{ Vendor = 'AMD'; DualCcdX3D = $true; IntelHybrid = $false }; $a = (Get-PlanProfile) -eq 'x3d2'
            $script:HW.Cpu = @{ Vendor = 'AMD'; DualCcdX3D = $false; IntelHybrid = $false }; $b = (Get-PlanProfile) -eq 'ryzen'
            $script:HW.Cpu = @{ Vendor = 'INTEL'; DualCcdX3D = $false; IntelHybrid = $true }; $c = (Get-PlanProfile) -eq 'hybrid'
            $script:HW.Cpu = @{ Vendor = 'INTEL'; DualCcdX3D = $false; IntelHybrid = $false }; $d = (Get-PlanProfile) -eq 'classic'
            $a -and $b -and $c -and $d
        } finally { $script:HW.Cpu = $old }
    }
    T 'plano: dry-run de cada perfil + exportar/detalhes' {
        $script:AutoActive = $true
        foreach ($pf in @('classic', 'hybrid', 'ryzen', 'x3d2')) { $null = Apply-PowerPlan -Prof $pf 6>$null }
        $null = Action-PlanExport 6>$null
        $script:KeyQueue.Clear(); $script:KeyQueue.Enqueue('enter')
        Show-PlanDetails 'x3d2' 6>$null
        $true
    }
    T 'plano: configuracoes existem neste Windows (informativo)' {
        $q = Get-PlanText (Get-ActivePlan)
        $miss = @()
        foreach ($pf in @('classic', 'hybrid', 'ryzen', 'x3d2')) { foreach ($x in (Get-PlanSettings $pf)) { if ($q -notmatch $x.Set -and $miss -notcontains $x.N) { $miss += $x.N } } }
        if ($miss.Count) { Write-Host ('     ausentes aqui (serao ignoradas): ' + ($miss -join ' | ')) -ForegroundColor DarkYellow }
        $q.Length -gt 1000
    }
    foreach ($pf in @('classic', 'hybrid', 'ryzen', 'x3d2')) {
        $pf2 = $pf
        T ('plano REAL (plano temporario descartavel): ' + $pf2) {
            $before = Get-ActivePlan
            $r = Test-PowerPlanReal $pf2
            $after = Get-ActivePlan
            $left = @((Invoke-Native -File 'powercfg' -ArgList @('/list') -Read).Output -split "`n" | Where-Object { $_ -match 'FNO_SCRATCH_TEST' }).Count
            if ($r.Skipped) { Write-Host ('     pulado: ' + $r.Why) -ForegroundColor DarkYellow; return ($before -eq $after) }
            Write-Host ('     ' + $pf2 + ': ok=' + $r.Ok + ' ignoradas=' + $r.Skip + ' problemas=' + $r.Bad.Count) -ForegroundColor DarkCyan
            foreach ($b in $r.Bad) { Write-Host ('     PROBLEMA: ' + $b) -ForegroundColor Red }
            ($r.Bad.Count -eq 0) -and ($before -eq $after) -and ($left -eq 0)
        }
    }
    T 'arte: letras grandes = ANSI Shadow original (FORT, 2 primeiras linhas)' {
        $r = @(ConvertTo-ShadowRows (Get-BigBitmap 'FORT') -Plain)
        ($r[0] -eq '#######+ ######+ ######+ ########+') -and ($r[1] -eq '##+====+##+===##+##+==##++==##+==+') -and ($r.Count -eq 6)
    }
    T 'arte: N (algoritmo da sombra confere com a fonte)' {
        $r = @(ConvertTo-ShadowRows (Get-BigBitmap 'N') -Plain)
        ($r[3] -eq '##|+##+##|') -and ($r[5] -eq '+=+  +===+')
    }
    T 'arte: sprites retangulares e cores validas' {
        $ok = $true
        foreach ($k in $script:Sprites.Keys) {
            $px = $script:Sprites[$k]; $w = $px[0].Length
            foreach ($row in $px) { if ($row.Length -ne $w -or $row -notmatch '^[0-9A-F.]+$') { $ok = $false; Write-Host ('     sprite ruim: ' + $k + ' -> ' + $row) -ForegroundColor Red } }
        }
        $ok
    }
    T 'arte: modo Unicode gera blocos/cabecalhos sem erro (todas as telas)' {
        $old = $script:Fancy
        try {
            Initialize-Glyphs -Force
            $script:ArtCache = @{}
            $ok = $true
            foreach ($k in @('logo') + @($script:ArtMap.Keys)) {
                foreach ($mh in @(99, 4)) {
                    $b = Get-ArtBlock $k 118 $mh
                    if (-not $b -or $b.W -gt 118 -or $b.Lines.Count -gt $mh) { $ok = $false; Write-Host ('     arte falhou: ' + $k + ' maxH ' + $mh) -ForegroundColor Red }
                }
            }
            $null = Get-SpriteBlock 'llama'
            $o = (Show-Goodbye 6>&1 | ForEach-Object { [string]$_ }) -join ''
            $script:KeyQueue.Clear(); $script:KeyQueue.Enqueue('esc')
            $o3 = (Show-Menu -Title 't' -Items @(@{ Label = 'a'; Badges = @() }) -Art 'lag' 6>&1 | ForEach-Object { [string]$_ }) -join ''
            $ok -and ($o -match 'kali_linax') -and ($o -match [string][char]0x2588) -and ($o3 -match [string][char]0x2588)
        } finally { if ($old) { Initialize-Glyphs -Force } else { Initialize-Glyphs -Ascii }; $script:ArtCache = @{} }
    }
    T 'DirectX: token SwapEffectUpgradeEnable preserva os outros' {
        ((Set-DxToken 'AutoHDREnable=1;VRROptimizeEnable=0;' 'SwapEffectUpgradeEnable' '1') -eq 'AutoHDREnable=1;VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;') -and ((Set-DxToken 'SwapEffectUpgradeEnable=0;X=1' 'SwapEffectUpgradeEnable' '1') -eq 'SwapEffectUpgradeEnable=1;X=1;') -and ((Set-DxToken '' 'SwapEffectUpgradeEnable' '1') -eq 'SwapEffectUpgradeEnable=1;')
    }
    T 'diagnostico: alertas extras rodam sem excecao' { $null = Show-ExtraAlerts 6>$null; $true }
    T 'NVIDIA: chaves de classe do adaptador (leitura)' { $k = @(Get-NvClassKeys); if ($script:HW.HasNvidia) { $k.Count -ge 1 } else { $true } }
    T 'idioma: dicionario, molde {0} e trechos' {
        $old = $script:UiLang
        try {
            Set-UiLang 'en'
            $a = ($script:EnDict.Count -gt 800)
            $b = ((L 'Voltar') -ne 'Voltar') -and ((L '  Voltar') -match '^  \S')
            $x = L ('Tela em {0} Hz.' -f 144)
            $c = ($x -match '144') -and ($x -notmatch 'Tela')
            Set-UiLang 'pt'
            $d = ((L 'Voltar') -eq 'Voltar')
            $a -and $b -and $c -and $d
        } finally { Set-UiLang $old }
    }
    T 'idioma: tela de escolha (setas + Enter, 1/2)' {
        $old = $script:UiLang
        try {
            $script:KeyQueue.Clear(); foreach ($k in 'down', 'enter') { $script:KeyQueue.Enqueue($k) }
            Select-Language 6>$null
            $e = $script:UiLang -eq 'en'
            $script:KeyQueue.Enqueue('1')
            Select-Language 6>$null
            $e -and ($script:UiLang -eq 'pt')
        } finally { Set-UiLang $old }
    }
    T 'idioma: TUDO em ingles (walker de menus, itens, guias, diagnostico)' {
        $old = $script:UiLang
        $script:L10nMiss = New-Object 'System.Collections.Generic.HashSet[string]'
        try {
            Set-UiLang 'en'
            $walk = @(
                @{ F = { Main-Menu }; K = @('enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'down', 'enter', 'esc', 'esc', 'y') },
                @{ F = { Menu-Diag }; K = @('enter', 'enter', 'down', 'enter', 'enter', 'down', 'down', 'enter', 'enter', 'esc') },
                @{ F = { Menu-Gpu }; K = @('end', 'esc') },
                @{ F = { Menu-Power }; K = @('down', 'down', 'enter', 'enter', 'esc') },
                @{ F = { Menu-Restore }; K = @('end', 'esc') },
                @{ F = { Menu-Bulk }; K = @('enter', 'y', 'enter') },
                @{ F = { Show-Goodbye }; K = @() }
            )
            foreach ($gid in @('ingame', 'hw', 'bios', 'nv', 'amd', 'intel', 'net', 'myths')) { $g2 = $gid; $walk += @{ F = [scriptblock]::Create("Show-Guide '$g2'"); K = @('enter') } }
            foreach ($grp in @('lag', 'cpu', 'net', 'fn', 'sys')) { $walk += @{ F = [scriptblock]::Create("Menu-Group -Group '$grp' -Title 'x' -Sub 'y' -GuideIds @('hw')"); K = @('end', 'esc') } }
            foreach ($w in $walk) {
                $script:KeyQueue.Clear(); foreach ($k in $w.K) { $script:KeyQueue.Enqueue($k) }
                try { & $w.F 6>$null } catch { if ($_.Exception.Message -ne 'AUTOKEYS_DONE') { throw } }
            }
            foreach ($t in $script:Tweaks) {
                $script:KeyQueue.Clear(); foreach ($k in $keysMix) { $script:KeyQueue.Enqueue($k) }
                try { Run-Tweak $t 6>$null } catch { if ($_.Exception.Message -ne 'AUTOKEYS_DONE') { throw } }
                $null = L $t.Name; $null = L $t.Desc
            }
            $script:KeyQueue.Clear()
            $miss = @($script:L10nMiss)
            if ($miss.Count) {
                try { [IO.File]::WriteAllText((Join-Path $env:TEMP 'fno_l10n_miss.txt'), ($miss -join "`r`n")) } catch { }
                foreach ($m in ($miss | Select-Object -First 25)) { Write-Host ('     PT: ' + $m) -ForegroundColor DarkYellow }
                Write-Host ('     total sem traducao: ' + $miss.Count + ' (lista em %TEMP%\fno_l10n_miss.txt)') -ForegroundColor DarkYellow
            }
            $miss.Count -eq 0
        } finally { $script:L10nMiss = $null; Set-UiLang $old; $script:KeyQueue.Clear() }
    }
    T 'wrap de texto' { $w = @(Wrap-Text 'aaa bbb ccc ddd eee' 8); ($w.Count -ge 2) -and (($w | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum -le 8) }
    $script:AutoActive = $false

    Write-Host ''
    $c = 'Green'; if ($script:TFail -gt 0) { $c = 'Red' }
    Write-Host ('=== {0} ok, {1} falha(s) ===' -f $script:TPass, $script:TFail) -ForegroundColor $c
    return $script:TFail
}

# ---------------------------------------------------------------------
#  ENTRADA
# ---------------------------------------------------------------------
function Show-Goodbye {
    $r = @()
    $r += , @(@{ T = ('  ' + (L 'Obrigado por usar o')); F = 'Gray' })
    $r += , @(@{ T = ('  ' + (L 'FORTNITE OTIMIZADOR') + ' '); F = 'White' }, @{ T = ('v' + $script:Version); F = 'Yellow' })
    $r += , @(@{ T = '' })
    $r += , @(@{ T = '  Made by: '; F = 'Magenta' }, @{ T = $script:CreditBy; F = 'Yellow' })
    $r += , @(@{ T = '  Discord: '; F = 'Cyan' }, @{ T = $script:CreditDiscord; F = 'Green' })
    $r += , @(@{ T = '' })
    $r += , @(@{ T = ('  ' + (L 'GG! Bom jogo.')); F = 'Cyan' })
    $blocks = @()
    if ($script:Fancy) { $blocks += (Get-SpriteBlock 'llama') }
    $blocks += (New-BoxBlock $r 40 'Magenta')
    [void](Write-Block (Join-Blocks $blocks 4 4))
}

function Start-Otimizador {
    Initialize-Ui
    # 1o de tudo: idioma (antes do carregamento)
    if (-not $SelfTest) {
        try { Select-Language } catch { if ($_.Exception.Message -eq 'AUTOKEYS_DONE') { return 0 }; throw }
        Set-UiTitle
    }
    if (-not $script:Admin -and -not $script:Dry -and -not $SelfTest) {
        Say ''
        Say '  [ERRO] Execute como ADMINISTRADOR (clique direito no .bat > Executar como administrador).' 'Red'
        Say '         Para so olhar/testar sem alterar nada, rode com o argumento -DryRun.' 'Gray'
        [void](Read-Host (L '  Enter para sair'))
        return 1
    }
    Load-State
    if ($SelfTest) { return (Invoke-SelfTest) }
    try {
        Show-Splash
        Register-WindowsTweaks; Register-NetTweaks; Register-GpuTweaks; Register-FnSysTweaks; Register-ExtraTweaks
        Main-Menu
    } catch {
        if ($_.Exception.Message -ne 'AUTOKEYS_DONE') {
            Say ''
            Say-Bad ('Erro fatal: ' + $_.Exception.Message)
            Write-Log ('FATAL ' + $_.Exception.ToString())
            [void](Read-Host (L '  Enter para sair'))
            return 2
        }
    } finally {
        Save-State
        try { [Console]::CursorVisible = $true } catch { }
    }
    if ($script:CanCursor) { Clear-Screen }
    Say ''
    Show-Goodbye
    if ($ScreenDump) { Save-ScreenDump }
    Say ''
    Say '  Ate mais! Se aplicou algo, REINICIE o PC.' 'Cyan'
    Say ('  Backups e log em: ' + $script:BackupDir) 'DarkGray'
    return 0
}

$script:ExitCode = Start-Otimizador
exit ([int]$script:ExitCode)
