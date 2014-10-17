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
stderr = codecs.getwriter('utf-8')(sys.stderr)

while True:
    try:
        # read the input and try to further enlarge the buffer at most 10 times 
        # (we don't want to fail if there's a unicode character right at the edge of the buffer)
        data = os.read(fd, 1024)
        if data == b'':
            break
        converted = 0
        trials = 10
        while trials and not converted:
            try:
                line = unicode(data, 'utf-8')
                converted = 1
            except UnicodeDecodeError:
                data += os.read(fd, 1024)
                trials -= 1
        #print >> stderr, "Read line:\n" + line
        #stderr.flush()
        cmd += line
    except Exception, e:
        print >> sys.stderr, str(type(e)), ':', e
        break
    # execute each command when it's fully read
    if "print '<<<<END>>>>'\n" in cmd:
        try:
            cmd = re.sub(r'^([\s]*)print (?!>)', r'\1print >> output, ', cmd)
            exec(cmd)
            output.flush()
            #print >> stderr, "Exec\'d:\n" + cmd
            #stderr.flush()
        except Exception, e:
            cmd = re.sub(r'[^\n]+\n$', '', cmd)
            _, _, tb = sys.exc_info()
            print >> sys.stderr, '\n\nCommand:', '\n', cmd, '\nException:\n', str(type(e)), ':', e, '\n\n', ''.join(traceback.format_tb(tb))
            pass
        cmd = ''
