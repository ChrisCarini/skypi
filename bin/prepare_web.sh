#!/usr/bin/env bash

git clone https://github.com/flightaware/dump1090.git ./
find * -maxdepth 0 -name 'public_html' -prune -o -exec rm -rf '{}' ';'
rm -rf ./.* 2> /dev/null
mv public_html/* ./
rm -rf public_html
mkdir data

##
# Receiver JSON file; contents below:
##
# Sample:
#  {
#    "version" : "3.6.3",
#    "refresh" : 1000,
#    "history" : 120,
#    "lat" : 37.37,
#    "lon" : -122.00
#  }
touch data/receiver.json


##
# Aircraft JSON file; contents below:
##
# Sample:
#  { "now" : 1548230026.4,
#    "messages" : 6622327,
#    "aircraft" : [
#      {"hex":"780aec","alt_baro":34000,"alt_geom":35000,"gs":445.4,"ias":291,"mach":0.832,"track":328.3,"mag_heading":314.5,"baro_rate":0,"geom_rate":0,"squawk":"7347","category":"A0","lat":37.264938,"lon":-121.542274,"nic":8,"rc":186,"seen_pos":4.7,"version":0,"nac_v":2,"mlat":[],"tisb":[],"messages":268,"seen":0.1,"rssi":-3.2},
#      {"hex":"ad9ac9","flight":"JBU1415 ","alt_baro":5550,"alt_geom":5925,"gs":233.4,"track":252.8,"baro_rate":-256,"squawk":"2554","emergency":"none","category":"A3","nav_qnh":1030.4,"nav_altitude":1792,"nav_heading":0.0,"lat":37.463146,"lon":-121.978873,"nic":8,"rc":186,"seen_pos":3.0,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":386,"seen":0.1,"rssi":-2.5},
#      {"hex":"899000","category":"A5","version":0,"mlat":[],"tisb":[],"messages":33,"seen":127.6,"rssi":-3.4},
#      {"hex":"0d0986","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":850,"seen":142.3,"rssi":-4.0},
#      {"hex":"ab9bb6","category":"A0","version":0,"mlat":[],"tisb":[],"messages":400,"seen":185.3,"rssi":-3.1}
#    ]
#  }
touch data/aircraft.json


