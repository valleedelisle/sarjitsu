#!/usr/bin/env python3

import os
import sys
import requests
import configparser
from app import app#, reset_cache
from app.users.controller import *
from app.users.forms import UploadForm
from time import ctime
from flask import Flask, \
    jsonify, \
    render_template, \
    Response, \
    json, \
    make_response, \
    request, \
    redirect, \
    session, \
    abort, \
    send_from_directory

# user modules
import upload_processor

config = configparser.ConfigParser()
config.read(app.config.get('CFG_PATH'))


@app.route('/asciimo', methods=['GET'])
def ascii():
    link = "http://i.imgur.com/kmbjB.png";
    return Response("<html><body><img src='%s'></body></html>" % link,
            mimetype='text/html')


@app.route('/', methods=['GET'])
def home():
    session['user'] = "anon"
    # reset_cache(session.sid)
    form = UploadForm(request.form)

    return render_template('index.html',
                                user=session['user'],
                                data=False,
                                form=form,
                                progress=0,
                                **app.config.get('TEMPLATE_CONFIGURATION'))


@app.route('/upload/', methods=['POST'])
def uploader():
    session['user'] = "anon"
    app.logger.info("current user <%s> for session ID: %s" %
                                    (session['user'], session.sid))
    if request.method == 'POST':
        form = UploadForm(request.form)
        form.datafile = request.files.getlist("datafile")
        if form.validate_on_submit() or form.data['cmd_mode']:
            target =  os.path.join(app.cache.get('saDir').decode('utf-8'),
                                    session.sid)
            _valid_results_found, response = upload_processor.begin(target,
                                                            session.sid, form)
        else:
            return jsonify({'form data': 'INVALID'})

        dashboard_url = config.get('Grafana','dashboard_url')
        if not dashboard_url:
            import socket; IP = socket.gethostbyname('frontend')
            dashboard_url = "http://%s:3000" % IP

        if form.data['cmd_mode']:
            res = {
                "valid_results": _valid_results_found,
                "data": response["nodenames_info"],
                "redirect_url": dashboard_url
            }
            return jsonify(res)
        else:
            return render_template('results.html',
                user=session['user'],
                data=response["nodenames_info"],
                form=form,
                valid_results=_valid_results_found,
                redirect_url=dashboard_url,
                progress=100,
                **app.config.get('TEMPLATE_CONFIGURATION'))

    abort(405)


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        session['username'] = request.form['username']
        return redirect(url_for('index'))
    return redirect(url_for('home'))


@app.route('/logout')
def logout():
    # remove the username from the session if it's there
    session.pop('username', None)
    return redirect(url_for('home'))


# @app.route('/<template>.html', methods=['GET'])
@app.route('/<template>/', methods=['GET'])
def template_loader(template='404'):
    session['user'] = "anon"
    # reset_cache(session.sid)
    form = UploadForm(request.form)

    try:
        return render_template('%s.html' % template,
                                user=session['user'],
                                data=False,
                                form=form,
                                progress=0,
                                **app.config.get('TEMPLATE_CONFIGURATION'))
    except:
        abort(404)


if __name__ == '__main__':
    try:
        app.run(host = app.config.get('HOST'),
                port = app.config.get('PORT'),
                debug = True)
        #app.config.get('DEBUG'))
    except:
        raise
