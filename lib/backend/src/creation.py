# import ast
import sys
import requests
import configparser
import json
import traceback
from app import app

config = configparser.ConfigParser()

def dashboard(hostname, sar_params, time_range, nested_terms):
    config.read(app.config.get('CFG_PATH'))
    api_endpoint = config.get('Grafana','api_url')

    payload = {
        "ts_beg": time_range['grafana_range_begin'],
        "ts_end": time_range['grafana_range_end'],
        "nodename": hostname,
        "modes": sar_params,
        "nested_terms": json.dumps(dict(nested_terms))
    }
    app.logger.info("Sending %s payload %s" % (api_endpoint, payload))
    try:
        res = requests.post(api_endpoint, data=payload)
        if res.status_code == 200:
            app.logger.info("status code: %s" % res.status_code)
            app.logger.info("content: \n%s" % res.content)
            app.logger.info("Dashboard created for -- %s" % hostname);
        else:
            app.logger.warn("status code: %s" % res.status_code)
            app.logger.warn("content: \n%s" % res.content)

    except ConnectionError:
        app.logger.error("endpoint not active. Couldn't connect.")
    except Exception as E:
        exc_type, exc_value, exc_tb = sys.exc_info()                                                                                                                                                                                                                                                                                                                                                                                        
        app.logger.error("\n".join(traceback.format_exception(exc_type, exc_value, exc_tb)))
        app.logger.warn(E)         
        sys.exit(1)

    return
