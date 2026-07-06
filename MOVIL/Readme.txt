La estructura es la misma:

logs
output
temp
subtitles

Ejeuctar estos comandos desde la terminal termux:

cd ~/storage/external-1/ffmpeg/ (Entrar en la SD)

chmod +x process.sh (permisos para el launcher)

ind /storage -iname "nba.mkv" (encontrar ruta del video)

readlink -f ~/storage/external-1 (encontrar la ruta actual real)

bash process.sh "/storage/3C3D-A6C7/Android/data/com.termux/files/ffmpeg/fifa.mkv" (Ejecutar automatización)

