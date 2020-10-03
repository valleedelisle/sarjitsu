#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# Statement for enabling the development environment
DEBUG = True
CFG_PATH = "/opt/sarjitsu/conf/sar-index.cfg"

LOG_FILENAME = 'sarjitsu_app.log'
LOG_FILESIZE = 10000 # in Bytes

# Application threads. A common general assumption is
# using 2 per available processor cores - to handle
# incoming requests using one and performing background
# operations using the other.
THREADS_PER_PAGE = 2

SA_DIR = 'safiles'

# Enable protection agains *Cross-site Request Forgery (CSRF)*
# CSRF_ENABLED     = False
CSRF_ENABLED     = True

# Use a secure, unique and absolutely secret key for
# signing the data.
CSRF_SESSION_KEY = "*@^@^%^*THD66GDFCVWRB%heafidpxry02%%"

# Secret key for signing cookies
SECRET_KEY = "#$JATFGYTE^$TFEFV#$%$&"

# Define the database - we are working with
# SQLite for this example
SQLALCHEMY_DATABASE_URI = 'sqlite:///' + os.path.join(BASE_DIR, 'app.db')
DATABASE_CONNECT_OPTIONS = {}

# Dictionary that holds all the template configuration
TEMPLATE_CONFIGURATION = {
    # The title of the application as shown by the browser
    "header_text" : "Sarjitsu v.2.0",
    "help_text" : "upload SA binary file (from /var/log/sa/) here",
    "placeholder" : "for 2nd day of the month would be: /var/log/sa/sa02"
}

##########################
# Web Application settings
##########################

# The host IP to run the application from
#HOST = "127.0.0.1"
HOST = "0.0.0.0"

# The port to run the application from
PORT = 8005

# override above options with local configs if needed
try:
    from config_local import *
    dev_env = True
except ImportError:
    dev_env = False
except:
    raise
