@echo off
setlocal EnableDelayedExpansion
cd /D "%~dp0"
chcp 65001 > nul

if not exist "%~dp0ffmpeg.exe" (
    echo [ERROR] ffmpeg.exe not found.
    pause & exit /b 1
)

set "SCRIPT_DIR=%~dp0"
if "!SCRIPT_DIR:~-1!"=="\" set "SCRIPT_DIR=!SCRIPT_DIR:~0,-1!"

for /f "delims=" %%d in ('python -c "from datetime import date; print(date.today().strftime('%%d_%%m'))"') do set "TODAY=%%d"

:NEW_URL

echo.
if not "%~1"=="" (
    set "url=%~1"
    shift
) else (
    set /p "url=Enter Youtube video or playlist URL: "
)

if "!url!"=="" (
    echo [ERROR] URL not provided.
    goto :NEXT_URL
)

echo Checking content...

set "playlistName="
for /f "usebackq delims=" %%i in (`python -m yt_dlp --flat-playlist --print "%%(playlist_title)s" --playlist-items 1 --no-warnings "!url!" 2^>nul`) do (
    set "playlistName=%%i"
    goto :gotPlaylist
)

:gotPlaylist

if /I "!playlistName!"=="NA"   set "playlistName="
if /I "!playlistName!"=="[NA]" set "playlistName="

if "!playlistName!"=="" (
    echo Content: Video
    set "outputDir=!SCRIPT_DIR!"
    set "outputTemplate=%%(title)s.%%(ext)s"
) else (
    set "folderName=!playlistName!_!TODAY!"
    echo Content: Playlist ^-^> !playlistName!
    for %%A in ("!SCRIPT_DIR!") do set "parentDir=%%~dpA"
    if "!parentDir:~-1!"=="\" set "parentDir=!parentDir:~0,-1!"
    set "outputDir=!parentDir!\!folderName!"

    mkdir "!outputDir!" 2>nul
    if not exist "!outputDir!" (
        echo [WARNING] Could not append sufix to playlist name.
        set "folderName=!playlistName!"
        set "outputDir=!parentDir!\!playlistName!"
        mkdir "!outputDir!" 2>nul
    ) else (
        echo Directory created: !folderName!
    )

    set "outputTemplate=%%(playlist_index)s - %%(title)s.%%(ext)s"
)

echo Destination: !outputDir!
echo.
echo Starting download...
echo.

python -m yt_dlp ^
 --format "bestaudio[ext=m4a]/bestaudio/best" ^
 --extract-audio ^
 --audio-format mp3 ^
 --audio-quality 0 ^
 --ffmpeg-location "!SCRIPT_DIR!" ^
 --embed-thumbnail ^
 --convert-thumbnails jpg ^
 --embed-metadata ^
 --download-archive "!SCRIPT_DIR!\archive.txt" ^
 --no-abort-on-error ^
 --sleep-requests 2 ^
 --sleep-interval 5 ^
 --max-sleep-interval 10 ^
 --output "!outputDir!\!outputTemplate!" ^
 "!url!"

echo.
if !ERRORLEVEL!==0 (
    echo [OK] Download process concluded with no errors.
) else (
    echo [WARNING] Download process concluded with errors.
)

echo.
echo Converting artwork...
python "!SCRIPT_DIR!\fix_artwork.py" "!outputDir!"

echo.
echo Download files saved in: !outputDir!

:NEXT_URL

echo.
set "option="
set /p "option=Download more URLs? (y/n): "

if /I "!option!"=="y" (
    set "url="
    goto :NEW_URL
)

echo.
echo Exiting...
pause
exit /b