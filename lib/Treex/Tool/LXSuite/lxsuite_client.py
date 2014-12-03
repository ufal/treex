#! /usr/bin/env python3
#
# Author: Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>
#
# Copyright NLX-Group, Universidade de Lisboa, 2014
#
import fcntl, os, re, select, signal, socket, subprocess, sys

usage = """
usage: {progname} HOST PORT KEY MODE INPUTFILE OUTPUTFILE

HOST is the lxsuite service host (e.g. nlx-server.di.fc.ul.pt).
PORT is the lxsuite service port (e.g. 10000).
KEY is your access key.
INPUTFILE and OUTPUTFILE are the names of the input and output files.  Use the
 minus sign (-) to make the program read from stdin and write to stdout.
MODE is one of:

    chunker_tokenizer_tagger_parser:OUT
        Runs the chunker, tokenizer, PoS tagger and dependency parser tools.
        OUT is either "conll.lx", "conll.usd" or "lxtriples" (see FORMATS below).

    chunker_tokenizer_tagger:OUT
        Runs the chunker, tokenizer and PoS tagger tools.
        OUT is either "plain", "ctags" or "conll" (see FORMATS below).

    chunker_tokenizer:OUT
        Runs the chunker and tokenizer tools.
        OUT is either "plain" or "ctags" (see FORMATS below).

    chunker:OUT
        Runs only the chunker, which tries to detect where each
         sentence ends and the next begins, trying to undo 
         linebreaks that were inserted within sentences (usually
         called "word wrapping").
         Each paragraph should be delimited at the input by an
          empty line.
         OUT is either "plain" or "ctags" (see FORMATS below).

    IN:tokenizer_tagger_parser:OUT
        Runs the tokenizer and PoS tagger tools.  Input is assumed
         to be chunked already.
        IN is either "plain" or "ctags" (see FORMATS below).
        OUT is either "conll.lx", "conll.usd" or "lxtriples" (see FORMATS below).

    IN:tokenizer_tagger:OUT
        Runs the tokenizer and PoS tagger tools.  Input is assumed
         to be chunked already.
        IN is either "plain" or "ctags" (see FORMATS below).
        OUT is either "plain", "ctags" or "conll.pos" (see FORMATS below).

    IN:tokenizer:OUT
        Tokenizes text.
        IN/OUT is either "plain" or "ctags" (see FORMATS below).

    IN:tagger_parser:OUT
        Runs PoS tagger and dependency parser. Assumes text has been sentence-chunked
         and tokenized.
        IN is either "plain" or "ctags" (see FORMATS below).
        OUT is either "conll.lx", "conll.usd" or "lxtriples" (see FORMATS below).

    IN:tagger:OUT
        Runs PoS tagger. Assumes text has been sentence-chunked 
         and tokenized.
        IN is either "plain" or "ctags" (see FORMATS below).
        OUT is either "plain", "ctags" or "conll.pos" (see FORMATS below).

    IN:parser:OUT
        Parses each sentence into a dependency tree. Assumes text has been
         sentence-chunked, tokenized and PoS-tagged.
        IN is either "plain", "ctags" or "conll.pos" (see FORMATS below).
        OUT is either "conll.lx", "conll.usd" or "lxtriples" (see FORMATS below).

    IN:to:OUT
        Converts IN format to OUT format.
        Available conversions: conll.lx to conll.usd, lxtriples to conll.usd,
         conll.lx to lxtriples and ctags (PoS tagged) to conll.pos.

    conjugator
        Portuguese verb conjugator.

    inflector
        Portuguese nominal and adjective inflector (input format: word,category,gender,number).

    help
        Shows this information.

FORMATS
    Use "plain" when the input/output text is plain text.
    Use "ctags" when the input/output text is marked with chunk
     tags (<p></p> and <s>/</s>).
    Use "conll.pos" when you want the tagged text in CoNLL tabular format.
    Use "conll.lx" when you want the parsed text in CoNLL tabular format 
      using LX dependency relations.
    Use "conll.usd" when you want the parsed text in CoNLL tabular format 
      using Stanford dependency relations.
    Use "lxtriples" when you want the parsed text in the LX triples format
      (using LX dependency relations).

Note: input and output are assumed to be UTF-8.

""".format(progname=sys.argv[0])

mode_regex = (
    "^(?:"
    "chunker:(?:plain|ctags)|"
    "chunker_tokenizer:(?:plain|ctags)|"
    "chunker_tokenizer_tagger:(?:plain|ctags|conll.pos)|"
    "chunker_tokenizer_tagger_parser:(?:conll.(?:lx|usd)|lxtriples)|"
    "(?:ctags|plain):tokenizer_tagger_parser:(?:conll.(?:lx|usd)|lxtriples)|"
    "(?:ctags|plain):tokenizer_tagger:(?:plain|ctags|conll.pos)|"
    "(?:ctags|plain):tokenizer:(?:plain|ctags)|"
    "(?:ctags|plain):tagger_parser:(?:conll.(?:lx|usd)|lxtriples)|"
    "(?:ctags|plain):tagger:(?:plain|ctags|conll.pos)|"
    "(?:ctags|plain|conll.pos):parser:(?:conll.(?:lx|usd)|lxtriples)|"
    "(?:conll.lx|lxtriples):to:conll.usd|"
    "conll.lx:to:lxtriples|"
    "ctags:to:conll.pos|"
    "conjugator|"
    "inflector"
    ")$"
)

signal.signal(signal.SIGPIPE, signal.SIG_DFL)


_def_maxbuf = 1024*1024
_chunksize = 4096


def set_nonblocking(stream):
    fd = stream.fileno()
    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)


def _pump(sock, istream, ostream, maxbuf=_def_maxbuf):
    sock.setblocking(False)
    set_nonblocking(istream)
    set_nonblocking(ostream)
    if maxbuf < _chunksize:
        maxbuf = _chunksize
    isock = osock = sock
    recving = sending = True
    sendbuf = bytes()
    recvbuf = bytes()
    while sending or recving:
        rlist = []
        wlist = []
        xlist = []
        if recving:
            if 0 < len(recvbuf):
                wlist.append(ostream)
            if maxbuf > len(recvbuf):
                if isock:
                    rlist.append(isock)
                elif 0 == len(recvbuf):
                    ostream.close()
                    ostream = None
                    recving = False
        if sending:
            if 0 < len(sendbuf):
                wlist.append(osock)
            if maxbuf > len(sendbuf):
                if istream:
                    rlist.append(istream)
                elif 0 == len(sendbuf):
                    osock.shutdown(socket.SHUT_WR)
                    osock = None
                    sending = False
        if 0 == len(rlist) == len(wlist):
            break
        if isock or osock:
            xlist.append(sock)
        if istream:
            xlist.append(istream)
        if ostream:
            xlist.append(ostream)
        rlist, wlist, xlist = select.select(rlist, wlist, xlist)
        for f in rlist:
            if f == istream:
                n = len(sendbuf)
                sendbuf += istream.read(_chunksize)
                if len(sendbuf) == n: # EOF at istream
                    istream.close()
                    istream = None
            else: # is sock
                n = len(recvbuf)
                recvbuf += sock.recv(_chunksize)
                if len(recvbuf) == n: # EOF at sock
                    #isock.shutdown(socket.SHUT_RD)
                    isock = None
        for f in wlist:
            if f == ostream:
                n = ostream.write(recvbuf)
                recvbuf = recvbuf[n:]
            else: # is sock
                n = sock.send(sendbuf)
                sendbuf = sendbuf[n:]
        for f in xlist:
            if f == istream:
                msg = "{}: Exception while selecting input stream."
            elif f == ostream:
                msg = "{}: Exception while selecting output stream."
            else: # is sock
                msg = "{}: Exception while selecting socket."
            print(msg.format(sys.argv[0]), file=sys.stderr)



if len(sys.argv) != 7:
    exit(usage)

host, port, key, mode, ifname, ofname = sys.argv[1:]

if not re.match(mode_regex, mode):
    exit("{}: Invalid mode ({})".format(sys.argv[0], mode))

istream = sys.stdin.buffer if ifname == "-" else open(ifname, "rb")
ostream = sys.stdout.buffer if ofname == "-" else open(ofname, "wb")
sock = socket.socket()
sock.connect((host, int(port)))
sock.send("{} {}\n".format(key, mode).encode("utf-8"))
status = sock.recv(3)
while not status.endswith("\n".encode("utf-8")):
    status += sock.recv(1)

status = status.decode("utf-8").strip()
if status != "OK":
    exit("{}: Error ({})".format(sys.argv[0], status))

_pump(sock, getattr(istream, "raw", istream), getattr(ostream, "raw", ostream))

