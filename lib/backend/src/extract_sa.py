import os
import sys
import requests
import subprocess
import traceback

# user mods
import creation
from app import app
from scripts.vos.analysis.lib import index_sar


def extract(sessionID, target, sa_filename):
    TSTAMPS={}
    CMD_CONVERT = ['-x', "--", "-A"]

    SAR_XML_FILEPATH = os.path.join(target, "%s.%s" % (sa_filename, "sar.xml"))
    file_metadata = "file_metadata:%s:%s" % (sessionID, sa_filename)

    sadf_type_det = app.cache.hget(file_metadata, "sadf_type_det").decode()
    app.logger.info('sysstat version found for: %s' % sadf_type_det)

    _SCRIPT = "%s-%s-64" % ('scripts/vos/analysis/bin/sadf', sadf_type_det)
    CMD_CONVERT.insert(0, _SCRIPT)

    conv_path = app.cache.hget(file_metadata, "sa_file_path_conv")
    if conv_path:
        target_file = conv_path.decode()
    else:
        target_file = app.cache.hget(file_metadata, "sa_file_path").decode()

    CMD_CONVERT.insert(-2, target_file)

    #FIXME: check if env in Popen is working fine
    app.logger.info("spawned CMD: %s" % " ".join(CMD_CONVERT))
    try:
        p1 = subprocess.Popen(CMD_CONVERT, env={'LC_ALL': 'C'},
                              stdout=open(SAR_XML_FILEPATH, 'w'))
        p1.wait()
        app.logger.info("SAR data extraction completed!")
    except ValueError:
        app.logger.error("Invalid arguments provided to Popen while \
                          trying to extract SAR data")
    except OSError as e:
        app.logger.error("Error forking the process while trying to \
                          extract the SA data")
        error_string = "[%s]: %s" % (str(e.errno), e.message)
        app.logger.error(error_string)

    CMD_GREP = ["scripts/detect_nodename", SAR_XML_FILEPATH]
    try:
        p2 = subprocess.Popen(CMD_GREP, stdout=subprocess.PIPE)
        p2.wait()
        NODENAME = p2.communicate()[0].decode().replace("\n", "")
    except ValueError:
        app.logger.error("Invalid argument provided to Popen while \
                         trying to detect nodename")
    except OSError as e:
        app.logger.error("Error forking the process while trying to \
                         detect the nodename")
        error_string = "[%s]: %s" % (str(e.errno), e.message)
        app.logger.error(error_string)

    #FIXME: check if call_indexer works everytime. And if it handles errors
    try:
        #FIXME: bad XML ExpatError
        state, beg, end, nested_terms = index_sar.call_indexer(file_path=SAR_XML_FILEPATH,
                                            _nodename=NODENAME,
                                            cfg_name=app.config.get('CFG_PATH'),
                                            run_unique_id=sessionID,
                                            run_md5=sessionID)
        # import pdb; pdb.set_trace()

        if state:
            TSTAMPS['grafana_range_begin'] = beg
            TSTAMPS['grafana_range_end'] = end
    except Exception as E:
        exc_type, exc_value, exc_tb = sys.exc_info()
        app.logger.error("\n".join(traceback.format_exception(exc_type, exc_value, exc_tb)))
        app.logger.warn(E)
        sys.exit(1)
        #app.logger.warn("=====Running alternate ES indexing script======")
        #CMD_INDEXING = ['scripts/vos/analysis/bin/index-sar',
        #                SAR_XML_FILEPATH, NODENAME]
        #app.logger.info('ES indexing cmd: ' + " ".join(CMD_INDEXING))
        #p3 = subprocess.Popen(CMD_INDEXING, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        #p3.wait()
        #RESULT_RAW = p3.communicate()
        #RAW_STDOUT = RESULT_RAW[0].decode().splitlines()
        #RAW_STDERR = RESULT_RAW[1].decode()

        #if "ConnectionError" in RAW_STDERR:
        #    print(RAW_STDERR, file=sys.stderr)
        #    return (NODENAME, False, sadf_type_det)

        #if "ERROR" in RAW_STDERR:
        #    # ES indexing failed
        #    print(RAW_STDERR, file=sys.stderr)
        #    # return (NODENAME, False, sadf_type_det)

        #TMP = [line for line in RAW_STDOUT if line.startswith('grafana_range')]
        #if TMP:
        #    for line in TMP:
        #        k,v = line.split(' ')
        #        TSTAMPS[k] = v

    if TSTAMPS:
        app.logger.info("[ES data ingested] -- %s" % NODENAME);
        app.logger.info('beg: %s' % TSTAMPS['grafana_range_begin'])
        app.logger.info('end: %s' % TSTAMPS['grafana_range_end'])

        GRAPHING_OPTIONS = app.cache.hget("sar_args:%s" % sessionID, "fields").decode()
        creation.dashboard(NODENAME, GRAPHING_OPTIONS, TSTAMPS, nested_terms)

        return (NODENAME, TSTAMPS, sadf_type_det)
    else:
        return (NODENAME, False, sadf_type_det)
