#!/bin/bash

ROMSPATH=/recalbox/share/roms
GAMELISTPATH=$ROMSPATH
IMAGESPATH=$ROMSPATH
TMP=/tmp
SCRAPER=$TMP/scraper
MAMEDEVICES=("mame" "fba" "fba_libretro" "neogeo")
CANSCRAPE=("${MAMEDEVICES[@]}" "nes" "snes" "n64" "gb" "gbc" "gba" "megadrive" "mastersystem" "sega32x" "gamegear" "pcengine" "atari2600" "lynx" "psx" "scummvm" "segacd")
ESDAEMON=$(ls /etc/init.d/S*emulationstation)

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
scraperZip=scraper_${arch}.zip
scraperURL=https://github.com/sselph/scraper/releases/download/${scraperVersion}/${scraperZip}
echo "ARCH = $arch -> the scraper ($scraperVersion) will run on $nbworkers core(s) - Downloading from $scraperURL"
wget -P $TMP -q $scraperURL || { echo "ERROR : unable to download the scrape archive. Exiting ... " ; exit 1 ; }
unzip -o $TMP/$scraperZip $(basename $SCRAPER) -d $TMP || { echo "ERROR : coulnd't unzip the scraper. Exiting ..." ; exit 1 ; }
rm $TMP/$scraperZip
chmod u+x $SCRAPER

esRunning=$(ps | grep emulationstation | grep -v grep | wc -l)
restartES=0
if [ $esRunning -ge 1 ]
then
  echo " +++ Shutting down EmulationStation to avoid ES rewriting the gamelist.xml files ..."
  $ESDAEMON stop
  restartES=1
  
  espid=$(ps | grep emulationstation | grep '/usr/bin' | grep -v grep | tr -s ' ' | cut -d ' ' -f 2 )
  echo -n "Waiting for emulationstation (pid $espid) to shutdown "
  while kill -0 "$espid" > /dev/null 2>&1 ; do echo -n "." ;sleep 1; done
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
    $SCRAPER $updateMode $arcade $imgparms -rom_dir="$device" -output_file="$GAMELISTPATH/$system/gamelist.xml" -workers=$nbworkers -img_workers=1 -image_path="./downloaded_images" -image_dir="$IMAGESPATH/$system/images"
  else
    echo "--- $system is not a scrapable system"
  fi
done

rm $SCRAPER

if [ $restartES -eq "1" ]
then
  echo -e "\n+++ Restarting ES ..."
  $ESDAEMON start
fi
