package MemcachedTest;

use strict;
use warnings;

use File::Basename;

our $MODEL_PACKAGE = 'Treex::Tool::TranslationModel::ML::Model';
our $MODEL_PARAMS = '"model_type maxent"';
our $MODEL_DIR = $ENV{'TMT_ROOT'} . '/share/data/models/translation/en2cs/';
our $MODEL_BIG = $MODEL_DIR . 'tlemma_czeng12.maxent.10000.100.2_1/';
our $MODEL_SMALL = $MODEL_DIR . 'czeng09.lemmas.taliG-4_3.maxent.10000.100.2.1.pls.gz';

our $LEMMAS_BIG = dirname(__FILE__) . "/lemmas.big.txt";
our $LEMMAS_SMALL = dirname(__FILE__) . "/lemmas.small.txt";


our $TESTS = [
    [$MODEL_SMALL, $LEMMAS_SMALL],
    [$MODEL_BIG, $LEMMAS_BIG],
];

our $MEMCACHED = dirname(__FILE__) . "/../memcached.pl";

our $LOAD_SMALL_CMD = "$MEMCACHED load $MODEL_PACKAGE $MODEL_PARAMS $MODEL_SMALL";
our $LOAD_BIG_CMD = "$MEMCACHED load $MODEL_PACKAGE $MODEL_PARAMS $MODEL_BIG";

our $EXTRACT_CMD = dirname(__FILE__) . "/extract-lemmas.pl";
our $CHECK_CMD = dirname(__FILE__) . "/check-lemmas.pl";


sub start_memcached {
    Treex::Tool::Memcached::Memcached::start_memcached(30);
    my $host = Treex::Tool::Memcached::Memcached::get_memcached_hostname();
}

sub stop_memcached {
    Treex::Tool::Memcached::Memcached::stop_memcached();
}

;

1;
