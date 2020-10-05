#!/usr/bin/env python3

import os
import json
import psycopg2
import random
import logging
import copy
from datetime import datetime, timedelta


def tstos(ts_beg=None, ts_end=None, current=False):
    """
    receives list of index names and
    guesses time range for dashboard."""
    if current:
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%fZ")
    else:
        ts_beg = datetime.strptime(ts_beg, "%Y-%m-%dT%H:%M:%S") \
            - timedelta(minutes=10)
        ts_end = datetime.strptime(ts_end, "%Y-%m-%dT%H:%M:%S") \
            + timedelta(minutes=10)
        return (ts_beg.strftime("%Y-%m-%d %H:%M:%S.%fZ"),
                ts_end.strftime("%Y-%m-%d %H:%M:%S.%fZ"))

class PrepareDashboard(object):
    """
    pass dashboard metadata and prepare rows from
    a pre-processed template.
    """

    def __init__(self, DB_TITLE='default', DB_TITLE_ORIG='default',
                 _FROM=None, _TO=None, _FIELDS=None,
                 TIMEFIELD='recorded_on', DATASOURCE=None,
                 TEMPLATES=None, NODENAME=None, db_credentials={},
                 nested_terms={}, app=None):
        """
        Use the precprocessed templates to create the dashboard,
        editing following parameters only:
        - fields to visualize
        - time range for the dashboard,
        - dashboard  title
        - datasource for dashboard
        - time field metric name for the datasource
        """
        self._FIELDS = _FIELDS
        self.NODENAME = NODENAME
        self.TEMPLATES = TEMPLATES
        self.TIMEFIELD = TIMEFIELD
        self.DATASOURCE = DATASOURCE
        self.DB_TITLE = DB_TITLE
        self.db_credentials = db_credentials
        self.nested_terms = json.loads(nested_terms)
        self.panel_id = 100
        self.nested_limit = { 'interrupts': 'sum' }
        if app:
            self.log = app.logger
        self.log.info("Preparing dashboard for node %s TEMPLATES %s nested_terms %s" % (NODENAME, TEMPLATES, nested_terms))
        # make these changes in dashboard parent template
        self.variable_params_dict = dict([('id', 1),
                                          ('title', self.DB_TITLE),
                                          ('originalTitle', DB_TITLE_ORIG),
                                          ('time', {'from': _FROM,
                                                    'to': _TO}),
                                          ('rows', []),
                                          ('schemaVersion', 1),
                                          ('version', 1)
                                          ])

    def init_db_connection(self):
        self.conn = psycopg2.connect("dbname='%s' user='%s' host='%s' port='%s' password='%s'" %
                                    (self.db_credentials['POSTGRES_DB_NAME'],
                                    self.db_credentials['POSTGRES_DB_USER'],
                                    self.db_credentials['POSTGRES_DB_HOST'],
                                    self.db_credentials['POSTGRES_DB_PORT'],
                                    self.db_credentials['POSTGRES_DB_PASS']))
        self.c = self.conn.cursor()

    def end_db_conn(self):
        self.conn.commit()
        self.conn.close()

    def create_row(self, field_name, description=False):
        """
        create a row for a given field_name

        if description holds True, this means:
                        this field_name refers to the main row with content
                        describing SAR in general, and explaining
                        the dashboard. Return as it is.

        """
        path = os.path.join(self.TEMPLATES, '%s.json' % (field_name))
        temp = json.load(open(path, 'r'))

        if description:
            return temp
        self.log.info("Creating row for field %s (desc: %s)" % (field_name, description))
        if field_name in self.nested_terms:
            template_panel = copy.deepcopy(temp['panels'])
            panel_list = []
            self.log.info("create_Row: Field %s is nested" % field_name)
            for f in self.nested_terms[field_name]:
                if field_name in self.nested_limit and f not in self.nested_limit[field_name]:
                    self.log.info("Field %s is limited to graphing only %s: Skipping %s" % (field_name, self.nested_limit[field_name], f))
                    continue
                elif field_name in self.nested_limit:
                    self.log.info("Field %s is limited to graphing only %s: Preparing %s" % (field_name, self.nested_limit[field_name], f))
                new_panels = copy.deepcopy(template_panel)
                for panel in new_panels:
                    panel_list.append(self.set_panel(panel, field_name, f))
            temp['panels'] = panel_list
        else:
            self.log.info("Field %s is NOT nested %s" % (field_name, self.nested_terms))
            for panel in temp['panels']:
                panel = self.set_panel(panel)

        # TODO: check whether if/else cases differ
        # for different metrics. Edit accordingly.
        # TODO: check if these really needs to be changed
        # self.PANEL_ID = 1 # auto-increament
        return temp

    def set_panel(self, panel, field_name=None, key_name=None):
       #  nested
       #    "bucketAggs": [
       #      {
       #        "fake": true,
       #        "field": "ts",
       #        "id": "8",
       #        "settings": {
       #          "interval": "auto",
       #        },
       #        "type": "date_histogram"
       #      },
       #      {
       #        "id": "2",
       #        "settings": {
       #          "nested": {
       #            "path": "cpu-load",
       #            "query": "0",
       #            "term": "cpu-load.cpu"
       #          }
       #        },
       #        "type": "nested"
       #      }
       #    ],

       # normal:
       #   "bucketAggs": [
       #     {
       #       "field": "recorded_on",
       #       "id": "2",
       #       "settings": {
       #         "interval": "auto"
       #       },
       #       "type": "date_histogram"
       #     }
       #   ],

      #disk.disk-device filesystems.filesystem interrupts.intr interrupts-processor.cpu interrupts-processor.intr network.net-dev.iface network.net-edev.iface

        self.panel_id += 1
        panel['datasource'] = self.DATASOURCE
        if key_name:
            panel['title'] = panel['title'].replace('%%KEY%%', key_name)
        panel['id'] = self.panel_id
        self.log.info("Panel: %s ID: %s" % (panel['title'], panel['id']))
        for target in panel['targets']:
            for agg in target['bucketAggs']:
                if agg['type'] == "date_histogram":
                    agg['field'] = self.TIMEFIELD
            if field_name and len(target['bucketAggs']) > 1:
                self.log.info("set_panel: Field %s is nested" % field_name)
                target['bucketAggs'][1]['settings']['nested']['query'] = str(key_name)
            target['timeField'] = self.TIMEFIELD
            target['query'] = "_metadata.nodename:%s" % (
                self.NODENAME)
        return panel
    def prepare_rows(self):
        """
        for all fields passed, pickup the template,
        and append to the 'rows' key of the json template
        """
        row = self.create_row('row_description', description=True)
        self.data['rows'].append(row)

        for field in self._FIELDS:
            try:
                row = self.create_row(field)
                self.log.info("Adding row: %s" % row)
                self.data['rows'].append(row)
            except Exception as err:
                self.log.error("couldn't prepare row for: %s" % field)
                self.log.error(err)

    def check_prev_metadata(self):
        """
        check grafana db for existant dashboards, panel id's and
        return them for next iteration.
        """
        pass

    def prepare_dashboard(self):
        """
        Check these if they already exist in grafana.db.
        Bump up those numbers, if so.
        - id
        - schemaVersion
        - version
        """
        self.log.info("Preparing dashboard")
        path = os.path.join(self.TEMPLATES, '%s.json' %
                            ('dashboard_template'))
        self.data = json.load(open(path, 'r'))
        for k, v in self.variable_params_dict.items():
            self.data[k] = v
        self.prepare_rows()

    def store_dashboard(self):
        """
        Connect to db and push data

        @schema:
        [id,
        version,
        'slug',
        'title',
        'data',
        org_id,
        'created',
        'updated']
        """
        self.init_db_connection()
        self.prepare_dashboard()
        # TODO: obtain metadata from check_prev_metadata()
        _id = random.getrandbits(12)
        version = 1
        slug = self.NODENAME +  str(random.getrandbits(12))
        title = self.DB_TITLE
        org_id = 1
        created = updated = tstos(current=True)
        self.c.execute("INSERT INTO dashboard VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                        (_id, version, slug, title, json.dumps(self.data),
                         org_id,created, updated))
        self.end_db_conn()
