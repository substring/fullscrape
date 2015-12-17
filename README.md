Simple shell for recalbox to scrape roms

Add -u as first parameter to update only

You can also add system names if you don't want to full scrape everything

Ex:
Scrape your full roms set : ./fullscrape.sh 
Only update existing scrapes : ./fullscrape.sh -u
Only scrape snes : ./fullscrape.sh snes
update SNES and SMS : ./fullscrape -u snes sms

This software uses :
  - https://github.com/sselph/scraper