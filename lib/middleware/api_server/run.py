#!/usr/bin/env python3

import ast
import os, sys
import configparser
import requests, json
import logging
from logging.handlers import RotatingFileHandler
from flask import Flask, jsonify, request, Response
from create_dashboard import *
app = Flask(__name__)
def _read_configs():
    cfg_name = "/opt/api_server/sar-index.cfg"
    config = configparser.ConfigParser()
    config.read(cfg_name)

    global SOURCE, TSTAMP_FIELD, TEMPLATES_PATH, API_PORT
    SOURCE = config.get('Grafana', 'ds_name')
    TSTAMP_FIELD = config.get('Grafana', 'timeField')
    TEMPLATES_PATH = os.path.join(config.get('Grafana', 'templates_path'),
                                'grafana', 'templates')

    global db_credentials
    db_credentials = {}
    db_credentials['POSTGRES_DB_HOST'] = config.get('Postgres','db_host')
    db_credentials['POSTGRES_DB_PASS'] = config.get('Postgres','db_password')
    db_credentials['POSTGRES_DB_NAME'] = config.get('Postgres','db_name')
    db_credentials['POSTGRES_DB_USER'] = config.get('Postgres','db_user')
    db_credentials['POSTGRES_DB_PORT'] = config.getint('Postgres','db_port')

    global default_modes
    #FIXME: handle nested docs options in future
    default_modes = ['block_device', 'cpu_all', 'hugepages',
        'interrupts', 'io_transfer_rate_stats',
        'kernel_inode', 'load_avg', 'memory_page_stats',
        'memory_util', 'network', 'paging_stats',
        'proc_cswitch', 'swap_page_stats', 'swap_util', 'network',
                    'net_dev']
    return config


@app.route('/', methods=['GET'])
def home():
    return jsonify({'api_test': 'OK'})


@app.route('/test/client/', methods=['POST'])
def test():
    return jsonify({'got response from server': 'OK'})


@app.route('/db/create/', methods=['POST', 'GET'])
def create_db():
    if request.method  == 'GET':
        ts_beg = request.args.get('ts_beg')
        ts_end = request.args.get('ts_end')
        nodename = request.args.get('nodename')
        modes = request.args.get('modes')
        nested_terms = request.args.get('nested_terms')
    elif request.method  == 'POST':
        try:
            # maybe the upload was not from a form
            # FIXME: check if this could be the case
            ts_beg = request.json.get('ts_beg', '')
            ts_end = request.json.get('ts_end', '')
            nodename = request.json.get('nodename', '')
            modes = request.json.get('modes', '')
            nested_terms = request.json.get('nested_terms', '')
        except:
            ts_beg = request.form.get('ts_beg', '')
            ts_end = request.form.get('ts_end', '')
            nodename = request.form.get('nodename', '')
            modes = request.form.get('modes', '')
            nested_terms = request.form.get('nested_terms', '')
    else:
        txt = "only GET/POST requests are allowed on this endpoint"
        response = { "reply" : "FAILED",
                    "response": txt}
        app.logger.error(response)
        status=405
        resp = Response(json.dumps(response),
                        status=status,
                        mimetype='application/json')
        return resp

    if not modes:
        app.logger.warn("No modes received, setting default: %s" % default_modes)
        modes=default_modes

    if ts_beg and ts_end and nodename:
        app.logger.info("Got request for node %s beginning %s end %s nested: %s" % (nodename, ts_beg, ts_end, nested_terms))
        try:
            beg, end = tstos(ts_beg=ts_beg, ts_end=ts_end)
            date = beg.split()[0]
            PP = PrepareDashboard(DB_TITLE='%s_%s_investigation' % (nodename, date),
                                  DB_TITLE_ORIG='%s_%s_investigation' % (
                                      nodename, date),
                                  _FROM=beg, _TO=end,
                                  _FIELDS=modes.split(','),
                                  NODENAME=nodename,
                                  TIMEFIELD=TSTAMP_FIELD,
                                  TEMPLATES=TEMPLATES_PATH,
                                  db_credentials=db_credentials,
                                  DATASOURCE=SOURCE,
                                  nested_terms=nested_terms, app=app)

            PP.store_dashboard()
            response = { "reply" : "SUCCESS",
                        "response": "dashboard created for %s" % (nodename)}
            status=200
        except ValueError:
            txt = "dashboard could not be created. Check arg values supplied"
            response = { "reply" : "FAILED",
                        "response": txt}
            status=400
        except Exception as E:
            print("ERROR: %s" % E)
            txt = "unknown exception encountered while processing"
            response = { "reply" : "FAILED",
                        "response": txt}
            status=500
    else:
        response = { "reply" : "FAILED! check arguments",
                    "required_args" : "ts_beg, ts_end, nodename (all strings)",
                    "options_args" : "modes (comma separated list)"}
        status=400

    resp = Response(json.dumps(response),
                    status=status,
                    mimetype='application/json')
    return resp


if __name__ == '__main__':
    try:
        config = _read_configs()
        logger = logging.getLogger(__name__)
        formatter = logging.Formatter(
                "[%(asctime)s] {%(pathname)s:%(lineno)d} %(levelname)s - %(message)s")
        handler = RotatingFileHandler(config.get('Settings', 'log_file'),
                                    maxBytes=config.getint('Settings', 'log_size'),
                                    backupCount=1)  
        handler.setLevel(logging.DEBUG)
        handler.setFormatter(formatter)
        app.logger.addHandler(handler)
        stdout_handler = logging.StreamHandler(sys.stdout)
        stdout_handler.setLevel(logging.DEBUG)
        stdout_handler.setFormatter(formatter)
        app.logger.addHandler(stdout_handler)
        app.logger.setLevel(logging.DEBUG)
        app.logger.info("Starting up")
        app.run(host = '0.0.0.0',
                port = config.getint('Api','api_port'),
                debug = False)
    except:
        raise
