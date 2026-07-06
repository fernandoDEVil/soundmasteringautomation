@echo off
title FFmpeg Auto Processor PRO
setlocal EnableDelayedExpansion

REM =====================================================
REM CONFIGURACION
REM =====================================================

set VOLUME_THRESHOLD=-20.0

REM =====================================================
REM VALIDAR INPUT
REM =====================================================

if "%~1"=="" (
    echo.
    echo Arrastra un video sobre este archivo .bat
    echo.
    pause
    exit /b
)

set "VIDEO=%~1"

if not exist "%VIDEO%" (
    echo.
    echo El programa se ha detenido.
    echo Archivo no encontrado.
    echo.
    pause
    exit /b
)

for %%F in ("%VIDEO%") do (
    set BASENAME=%%~nF
    set EXTENSION=%%~xF
)

set OUTPUT=%BASENAME%_youtube%EXTENSION%

echo.
echo =====================================================
echo FFmpeg Auto Processor PRO
echo =====================================================
echo.
echo Video:
echo %VIDEO%
echo.
echo Output:
echo %OUTPUT%
echo.
echo Puedes detener el programa con CTRL + X
echo.

REM =====================================================
REM DETECTAR SUBTITULOS
REM =====================================================

echo =====================================================
echo Buscando subtitulos...
echo =====================================================
echo.

ffmpeg -i "%VIDEO%" 2> streams.txt

set SUBINDEX=0
set ENGCOUNT=0
set SPACOUNT=0
set OTHERCOUNT=0

for /f "tokens=1,* delims=:" %%A in ('findstr /i "Subtitle" streams.txt') do (

    set "LINE=%%A:%%B"

    echo -----------------------------------------
    echo !LINE!
    echo -----------------------------------------

    REM =========================================
    REM INGLES
    REM =========================================

    echo !LINE! | findstr /i "(eng)" >nul

    if !errorlevel! == 0 (

        set /a ENGCOUNT+=1

        set SUBNAME=eng!ENGCOUNT!.srt

        echo.
        echo Extrayendo !SUBNAME!
        echo.

        ffmpeg -y -i "%VIDEO%" ^
        -map 0:s:!SUBINDEX! ^
        "!SUBNAME!"

        if errorlevel 1 (
            echo.
            echo El programa se ha detenido.
            goto :cleanup
        )
    )

    REM =========================================
    REM ESPAÑOL
    REM =========================================

    echo !LINE! | findstr /i "(spa)" >nul

    if !errorlevel! == 0 (

        set /a SPACOUNT+=1

        if !SPACOUNT! == 1 (
            set SUBNAME=spa.srt
        ) else (
            set SUBNAME=spa!SPACOUNT!.srt
        )

        echo.
        echo Extrayendo !SUBNAME!
        echo.

        ffmpeg -y -i "%VIDEO%" ^
        -map 0:s:!SUBINDEX! ^
        "!SUBNAME!"

        if errorlevel 1 (
            echo.
            echo El programa se ha detenido.
            goto :cleanup
        )
    )

    REM =========================================
    REM OTROS IDIOMAS
    REM =========================================

    echo !LINE! | findstr /i "(eng)" >nul

    if not !errorlevel! == 0 (

        echo !LINE! | findstr /i "(spa)" >nul

        if not !errorlevel! == 0 (

            set /a OTHERCOUNT+=1

            set SUBNAME=sub!OTHERCOUNT!.srt

            echo.
            echo Extrayendo !SUBNAME!
            echo.

            ffmpeg -y -i "%VIDEO%" ^
            -map 0:s:!SUBINDEX! ^
            "!SUBNAME!"

            if errorlevel 1 (
                echo.
                echo El programa se ha detenido.
                goto :cleanup
            )
        )
    )

    set /a SUBINDEX+=1
)

echo.
echo =====================================================
echo Subtitulos procesados correctamente
echo =====================================================
echo.

REM =====================================================
REM VOLUMEDETECT
REM =====================================================

echo =====================================================
echo Detectando volumen...
echo =====================================================
echo.

ffmpeg ^
-hide_banner ^
-i "%VIDEO%" ^
-map 0:a:0 ^
-af volumedetect ^
-f null NUL 2> volume.txt

type volume.txt

if errorlevel 1 (
    echo.
    echo El programa se ha detenido.
    goto :cleanup
)

REM =====================================================
REM EXTRAER mean_volume
REM =====================================================

set MEANVOL=

for /f "tokens=2 delims=:" %%A in ('findstr /i "mean_volume" volume.txt') do (
    set MEANVOL=%%A
)

echo.
echo =====================================================
echo Volumen detectado:
echo !MEANVOL!
echo =====================================================
echo.

REM =====================================================
REM PRIMERA PASADA LOUDNORM
REM =====================================================

echo =====================================================
echo Primera pasada loudnorm
echo =====================================================
echo.
echo Mostrando progreso en vivo...
echo.

ffmpeg ^
-hide_banner ^
-stats ^
-i "%VIDEO%" ^
-map 0:a:0 ^
-af loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json ^
-f null NUL 2> loudnorm.txt

type loudnorm.txt

if errorlevel 1 (
    echo.
    echo El programa se ha detenido.
    goto :cleanup
)

REM =====================================================
REM EXTRAER PARAMETROS LOUDNORM
REM =====================================================

for /f "tokens=2 delims=:" %%A in ('findstr /i "input_i" loudnorm.txt') do (
    set INPUT_I=%%A
)

for /f "tokens=2 delims=:" %%A in ('findstr /i "input_tp" loudnorm.txt') do (
    set INPUT_TP=%%A
)

for /f "tokens=2 delims=:" %%A in ('findstr /i "input_lra" loudnorm.txt') do (
    set INPUT_LRA=%%A
)

for /f "tokens=2 delims=:" %%A in ('findstr /i "input_thresh" loudnorm.txt') do (
    set INPUT_THRESH=%%A
)

for /f "tokens=2 delims=:" %%A in ('findstr /i "target_offset" loudnorm.txt') do (
    set TARGET_OFFSET=%%A
)

REM =====================================================
REM LIMPIAR DATOS
REM =====================================================

set INPUT_I=!INPUT_I:,=!
set INPUT_TP=!INPUT_TP:,=!
set INPUT_LRA=!INPUT_LRA:,=!
set INPUT_THRESH=!INPUT_THRESH:,=!
set TARGET_OFFSET=!TARGET_OFFSET:,=!

set INPUT_I=!INPUT_I: =!
set INPUT_TP=!INPUT_TP: =!
set INPUT_LRA=!INPUT_LRA: =!
set INPUT_THRESH=!INPUT_THRESH: =!
set TARGET_OFFSET=!TARGET_OFFSET: =!

echo.
echo =====================================================
echo Valores loudnorm detectados
echo =====================================================
echo input_i=!INPUT_I!
echo input_tp=!INPUT_TP!
echo input_lra=!INPUT_LRA!
echo input_thresh=!INPUT_THRESH!
echo target_offset=!TARGET_OFFSET!
echo.

REM =====================================================
REM SEGUNDA PASADA
REM =====================================================

echo =====================================================
echo Segunda pasada loudnorm
echo =====================================================
echo.
echo Mostrando progreso en vivo...
echo.

ffmpeg ^
-hide_banner ^
-stats ^
-y ^
-i "%VIDEO%" ^
-map 0:v:0 ^
-map 0:a:0 ^
-sn ^
-c:v copy ^
-af loudnorm=I=-14:TP=-1.0:LRA=11:measured_I=!INPUT_I!:measured_TP=!INPUT_TP!:measured_LRA=!INPUT_LRA!:measured_thresh=!INPUT_THRESH!:offset=!TARGET_OFFSET! ^
-c:a aac ^
-b:a 192k ^
"%OUTPUT%"

if errorlevel 1 (
    echo.
    echo El programa se ha detenido.
    goto :cleanup
)

echo.
echo =====================================================
echo Conversion completada satisfactoriamente.
echo =====================================================
echo.

goto :cleanup

REM =====================================================
REM LIMPIEZA
REM =====================================================

:cleanup

del streams.txt >nul 2>&1
del volume.txt >nul 2>&1
del loudnorm.txt >nul 2>&1

echo Archivos temporales eliminados.
echo.

pause
exit /b