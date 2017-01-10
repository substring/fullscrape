#!/bin/bash

function getLang {
  rbxLocale=$(grep "^system.language" recalbox.conf | cut -d "=" -f 2 | cut -d "_" -f 1 )
  echo "${rbxLocale}"
}

function showHelp {
  echo "Usage : "
  echo "-u : update - only scrape new roms"
}




ROMSPATH=/recalbox/share/roms
GAMELISTPATH=$ROMSPATH
IMAGESPATH=$ROMSPATH
TMP=/tmp
SCRAPER=$TMP/scraper
MAMEDEVICES=("mame" "fba" "fba_libretro" "neogeo")
CANSCRAPE=("${MAMEDEVICES[@]}" "atari2600" "atari7800" "lynx" "colecovision" "gw" "vectrex" "o2em" "fds" "nes" "snes" "n64" "gb" "gbc" "gba" "virtualboy" "megadrive" "mastersystem" "sega32x" "segacd" "sg1000" "gamegear" "dreamcast" "pcengine" "supergrafx" "psx" "scummvm" "ngp" "ngpc")
ESDAEMON=$(ls /etc/init.d/S*emulationstation)

selectiveMode=0
updateMode=
screenScraper=

OPTIND=1

while getopts "h?us" opt; do
    case "$opt" in
    h|\?)
        showHelp
        exit 0
        ;;
    u)  updateMode="-append"
        ;;
    #~ s)  screenScraper="-use_ss=true -use_gdb=false `getLang`"
        #~ ;;
    esac
done

shift $((OPTIND-1))

# check if some system names are passed as arguments
if [ $# -gt 0 ]
then
  selectiveMode=1
  selectedSystems=( "$*" )
fi

echo "-u : $updateMode"
echo "-s : $screenScraper"
echo "Remaining args : $selectedSystems"
#exit 0

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

rbxLang=`getLang`
# Run an empty scraper to get hash files
$SCRAPER -console_src=ss,gdb,ovgdb -mame_src=ss,gdb

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
    arcade="-mame -mame_img=\"s,t,m,c\""
  else
    arcade=""
  fi
  # Disabling ovgdb for now as a source as it slows down the process because it's checking for its hash file everytime
  if [[ " ${CANSCRAPE[@]} " =~ " ${system} " ]]
  then
    echo -e "\n+++ Scraping $system"
    $SCRAPER $updateMode $arcade $imgparms \
      -hash_file=/recalbox/share/system/.sselph-scraper/hash.csv \
      -rom_dir="$device" \
      -output_file="$GAMELISTPATH/$system/gamelist.xml" \
      -workers=$nbworkers \
      -console_src=ss,gdb -mame_src=ss,gdb \
      -console_img=s,b,f,a,l,3b \
      -lang=$rbxLang \
      -img_workers=1 \
      -image_path="./downloaded_images" \
      -image_dir="$IMAGESPATH/$system/downloaded_images"
  else
    echo "--- $system is not a scrapable system"
  fi
done

#rm $SCRAPER

if [ $restartES -eq "1" ]
then
  echo -e "\n+++ Restarting ES ..."
  $ESDAEMON start
fi
