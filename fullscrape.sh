#!/bin/bash

ROMSPATH=/recalbox/share/roms
GAMELISTPATH=~/.emulationstation/gamelists
IMAGESPATH=~/.emulationstation/downloaded_images
#SCRAPER=~/outils/scraper
TMP=/tmp
SCRAPER=$TMP/scraper
MAMEDEVICES=("mame" "fba" "fba_libretro" "neogeo")
CANSCRAPE=("${MAMEDEVICES[@]}" "nes" "snes" "n64" "gb" "gbc" "gba" "megadrive" "mastersystem" "sega32x" "gamegear" "pcengine" "atari2600" "lynx" "psx" "scummvm" "segacd")

selectiveMode=0
updateMode=

# if $1 = -u, then set to update only mode
[ "$1" = '-u' ] && updateMode="-append" && shift

# check if some system names are passed as arguments
if [ $# -gt 0 ]
then
  selectiveMode=1
  selectedSystems=( "$*" )
fi

# rpi or rpi2 ?
uname -a | grep 'armv7' >/dev/null
if [ $? -eq "0" ]
then
  arch=rpi2
  nbworkers=4
  imgparms="-no_thumb=true -max_width=375"
else
  arch=rpi
  nbworkers=1
  imgparms="-thumb_only"
fi

echo "+++ Downloading and unzipping scraper ..."
scraperVersion=$(wget -qO- https://api.github.com/repos/sselph/scraper/releases/latest | grep tag_name | cut -d '"' -f 4)
scraperZip="scraper_${arch}.zip"
scraperURL=https://github.com/sselph/scraper/releases/download/${scraperVersion}/${scraperZip}
echo "ARCH = $arch -> the scraper ($scraperVersion) will run on $nbworkers core(s) - Downloading from $scraperURL"
wget -q $scraperURL
unzip -o $scraperZip $(basename $SCRAPER) -d $TMP
rm $scraperZip
chmod u+x $SCRAPER

esRunning=$(ps | grep emulationstation | grep -v grep | wc -l)
restartES=0
if [ $esRunning -ge 1 ]
then
  echo " +++ Shutting down EmulationStation to avoid ES rewriting the gamelist.xml files ..."
  /etc/init.d/S31emulationstation stop
  restartES=1
fi

#echo "$ROMSPATH/fba" | while read device
find $ROMSPATH -type d -maxdepth 1 | grep -v "^${ROMSPATH}$"| while read device
do
  system=$(basename $device)

  # If selective mode, check if the system is set for update. Else skip
  if [[ $selectiveMode = "1" ]] && [[ ! " ${selectedSystems[@]} " =~ " ${system} " ]]
  then
    echo "--- $system not set for scraping according to commandline"
    continue
  fi

  #Test if it's an arcade system
  if [[ " ${MAMEDEVICES[@]} " =~ " ${system} " ]]
  then
    arcade="-mame -mame_img=\"m,t,s\""
  else
    arcade=""
  fi

  if [[ " ${CANSCRAPE[@]} " =~ " ${system} " ]]
  then
    echo -e "\n+++ Scraping $system"
    $SCRAPER $updateMode $arcade $imgparms -rom_dir="$device" -output_file="$GAMELISTPATH/$system/gamelist.xml" -workers=$nbworkers -image_dir="$IMAGESPATH/$system" -image_path="$IMAGESPATH/$system"
  else
    echo "--- $system is not a scrapable system"
  fi
done

#rm $SCRAPER

if [ $restartES -eq "1" ]
then
  echo -e "\n+++ Restarting ES ..."
  /etc/init.d/S31emulationstation start
fi