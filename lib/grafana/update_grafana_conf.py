#!/usr/bin/env python3

# updates grafana.ini with db credentials
# from sarjitsu.conf file (for postgres)

import os
import configparser
import requests
from time import sleep

CONFIG_FILE='/etc/grafana/grafana.ini'
# BASE_DIR = os.path.dirname(os.path.dirname(__file__))
# SARJITSU_CONF_PATH=os.path.join(BASE_DIR, '../../conf/sarjitsu.conf')

# with open(SARJITSU_CONF_PATH, 'r') as f:
#     c = f.read().splitlines()
#     # cleanup bash for comments / newlines
#     c = [i for i in c if not i.startswith('#')]
#     while '' in c:
#         c.remove('')
#     env_vars = dict([i.split('=') for i in c])

config = configparser.ConfigParser()
config.read(CONFIG_FILE)

try:
    db_host = os.environ['DB_HOST']
except KeyError:
    import socket
    db_host = socket.gethostbyname('psql')

config['database']['type'] =  os.environ['GRAFANA_DB_TYPE']
config['database']['host'] = "%s:%s" % (db_host,
                                        os.environ['DB_PORT'])
config['database']['name'] =  os.environ['DB_NAME']
config['database']['user'] =  os.environ['DB_USER']
config['database']['password'] =  os.environ['DB_PASSWORD']
config['auth.anonymous']['enabled'] = 'true'
config['auth.anonymous']['org_role'] = 'Admin'


with open(CONFIG_FILE, 'w') as configfile:
    config.write(configfile)

print("updated grafana config..")

# We need to wait until grafana server is up before going on
sleep(60) 
print("Creating home dashboard")
print("Authentication")
t = requests.post("http://admin:admin@localhost:3000/api/auth/keys", data={"name":"apikey", "role": "Admin"})
print("Response: %s %s" % (t.status_code, t.text))
if t.status_code == 200:
    headers = {"Authorization": "Bearer %s" % t.json()['key']}
    dbjson = requests.get("http://localhost:3000/api/dashboards/home", headers=headers).json()
    dbjson['dashboard']['panels'].pop(2)
    dbjson['dashboard']['panels'].pop(0)
    dbjson['dashboard']['title'] = 'Sarjitsu Home'
    dbjson['dashboard']['panels'][0]['starred'] = False
    dbjson['dashboard']['panels'][0]['limit'] = 1000
    dbjson['dashboard']['panels'][0]['search'] = True
    print("Posting dashboard %s" % dbjson)
    p = requests.post("http://grafana:3000/api/dashboards/db", json=dbjson, headers=headers)
    print("Response: %s %s" % (p.status_code, p.text))
    if p.status_code == 200:
        print("Updating home dashboard ID %s" % p.json())
        u = requests.put("http://grafana:3000/api/org/preferences", json={"homeDashboardId": p.json()['id']}, headers=headers)
        print("Response: %s %s" % (u.status_code, u.text))
        if u.status_code == 200:
            print("Home dashboard updated")
