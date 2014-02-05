#!/usr/bin/env python
# coding=utf-8

"""
Execute commands given on STDIN, print their output to STDOUT.

Waits for "print '<<<<END>>>>'\n" on a single line to execute the
commands read from STDIN. If this occurs, the commands are executed
and their output, including "<<<<END>>>>", is returned immediately.

This is designed to work with the Treex::Tool::Python::RunFunc
module.
"""

from __future__ import unicode_literals
import sys
import traceback
import re
import codecs
import os
import fcntl

__author__ = "Ondřej Dušek"
__date__ = "2013"


cmd = ''


# input utf-8 decoding -- must be done this way to preserve non-blocking
fd = sys.stdin.fileno()
decode = codecs.getdecoder('utf-8')

# output utf-8 encoding
output = codecs.getwriter('utf-8')(sys.stdout)

while True:
    try:
        data = os.read(fd, 1024)
        if data == b'':
            break
        line = unicode(data, 'utf-8')
        # print >> sys.stderr, 'Read line:' + data
        cmd += line
    except Exception, e:
        print >> sys.stderr, e
        break
    # execute each command when it's fully read
    if "print '<<<<END>>>>'\n" in line:
        try:
            cmd = re.sub(r'^([\s]*)print (?!>)', r'\1print >> output, ', cmd)
            exec(cmd)
            output.flush()
            #print >> sys.stderr, 'Exec\'d ' + cmd
        except Exception, e:
            cmd = re.sub(r'[^\n]+\n$', '', cmd)
            _, _, tb = sys.exc_info()
            print >> sys.stderr, '\n\nCommand:', '\n', cmd, '\nException:\n', e, '\n\n', ''.join(traceback.format_tb(tb))
            pass
        cmd = ''
