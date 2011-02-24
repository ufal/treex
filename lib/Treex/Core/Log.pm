package Treex::Core::Log;

use utf8;
use strict;
use warnings;
use English '-no_match_vars';

use Carp;

use IO::Handle;
use Readonly;

$Carp::CarpLevel = 1;

binmode STDERR, ":utf8";

# Autoflush after every Perl statement should enforce that INFO and FATALs are ordered correctly.
{
    my $oldfh = select(STDERR);
    $| = 1;
    select($oldfh);
}

Readonly my %ERROR_LEVEL_VALUE => (
    'ALL'   => 0,
    'DEBUG' => 1,
    'INFO'  => 2,
    'WARN'  => 3,
    'FATAL' => 4,
);

use Moose::Util::TypeConstraints;
enum 'ErrorLevel' => keys %ERROR_LEVEL_VALUE;

# how many characters of a string-eval are to be shown in the output
$Carp::MaxEvalLen = 100;

my $unfinished_line;

# By default report only messages with INFO or higher level
my $current_error_level_value = $ERROR_LEVEL_VALUE{'INFO'};

# allows to surpress messages with lower than given importance
sub set_error_level {
    my $new_error_level = uc(shift);
    if ( not defined $ERROR_LEVEL_VALUE{$new_error_level} ) {
        log_fatal("Unacceptable errorlevel: $new_error_level");
    }
    $current_error_level_value = $ERROR_LEVEL_VALUE{$new_error_level};
    return;
}

sub get_error_level {
    return $current_error_level_value;
}

sub _ntred_message {
    my $message = shift;
    {
        no strict;
        no warnings;
        if ($main::is_in_ntred) {
            main::_msg $message;
        }
    }
}

# fatal error messages can't be surpressed
sub fatal {
    my $message = shift;
    if ($unfinished_line) {
        print STDERR "\n";
        $unfinished_line = 0;
    }
    my $line = "TREEX-FATAL:\t$message\n\n";
    $line .= "PERL ERROR MESSAGE: $OS_ERROR\n"        if $OS_ERROR;
    $line .= "PERL EVAL ERROR MESSAGE: $EVAL_ERROR\n" if $EVAL_ERROR;
    $line .= "PERL STACK:";
    _ntred_message($line);
    confess $line;
}

sub short_fatal {    # !!! neodladene
    my $message = shift;
    if ($unfinished_line) {
        print STDERR "\n";
        $unfinished_line = 0;
    }
    my $line = "TREEX-FATAL(short):\t$message\n";
    _ntred_message($line);
    print STDERR $line;
    exit;

}

# TODO: redesign API - $carp, $no_print_stack

sub warn {
    my ($message, $carp) = @_;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'WARN'};
    my $line = "";
    if ($unfinished_line) {
        $line            = "\n";
        $unfinished_line = 0;
    }
    $line .= "TREEX-WARN:\t$message\n";
    _ntred_message($line);
    if ($carp) {
        Carp::carp $line;
    }
    else {
        print STDERR $line;
    }
    return;
}

sub debug {
    my ( $message, $no_print_stack ) = @_;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'DEBUG'};
    my $line = "";
    if ($unfinished_line) {
        $line            = "\n";
        $unfinished_line = 0;
    }
    $line .= "TREEX-DEBUG:\t$message\n";
    _ntred_message($line);
    if ($no_print_stack) {
        print STDERR $line;
    }
    else {
        Carp::cluck $line;
    }
    return;
}

sub data {
    my $message = shift;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    my $line = "";
    if ($unfinished_line) {
        $line            = "\n";
        $unfinished_line = 0;
    }
    $line .= "TREEX-DATA:\t$message\n";
    _ntred_message($line);
    print STDERR $line;
    return;
}

sub info {
    my $message = shift;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    my $line = "";
    if ($unfinished_line) {
        $line            = "\n";
        $unfinished_line = 0;
    }
    $line .= "TREEX-INFO:\t$message\n";
    _ntred_message($line);
    print STDERR $line;
    return;
}

sub info_unfinished {
    my $message = shift;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    my $line = "";
    if ($unfinished_line) {
        $line            = "\n";
        $unfinished_line = 0;
    }
    $line .= "TREEX-INFO:\t$message";
    _ntred_message($line);
    print STDERR $line;
    STDERR->flush;
    $unfinished_line = 1;
    return;
}

sub info_finish {
    my $message = shift;
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    my $line = "";
    if ( not $unfinished_line ) {
        $line = "\nTREEX-INFO:\t";
    }
    $unfinished_line = 0;
    $line .= "$message\n";
    _ntred_message($line);
    print STDERR $line;
    return;
}

sub progress {    # progress se pres ntred neposila, protoze by se stejne neflushoval
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    if ( not $unfinished_line ) {
        print STDERR "TREEX-PROGRESS:\t";
    }
    print STDERR "*";
    STDERR->flush;
    $unfinished_line = 1;
    return;
}

# code for reporting memory consumptions (especially because of memory leaks)
#
# use Proc::ProcessTable;
# my $last_memory_usage = 0;
#
sub memory {

    #
    #     my $process_table = new Proc::ProcessTable;
    #     my $current_process;
    #
    #    PROCESS: foreach my $process ( @{ $process_table->table } ) {
    #        if ( $process->pid eq $$ ) {
    #            $current_process = $process;
    #            last PROCESS;
    #        }
    #    }
    #
    #    my $current_memory_usage = $current_process->size;
    #    my $increase             = $current_memory_usage - $last_memory_usage;
    #    $last_memory_usage = $current_memory_usage;
    #
    #    my $message = "current consumption = " . _reformat_long_number($current_memory_usage)
    #        . " B\tincrease from previous = " . _reformat_long_number($increase) . " B";
    #
    #    $message = "current consumption = " . _format_bytes($current_memory_usage)
    #        . " \tincrease from previous = " . _format_bytes($increase);
    #
    #    my $line = "";
    #    if ($unfinished_line) {
    #        $line            = "\n";
    #        $unfinished_line = 0;
    #    }
    #    $line .= "TREEX-MEMORY:\t$message\n";
    #    _ntred_message($line);
    #    print STDERR $line;
    #
    return;
}

# convert size to human readable format
sub _format_bytes {
    defined( my $size = shift ) || return undef;
    my $block = 1024;
    my @args  = qw/B K M G/;

    while ( @args && $size > $block ) {
        shift @args;
        $size /= $block;
    }

    my $truncate = 1;
    $size = sprintf( "%.${truncate}f", $size );

    return "$size$args[0]";
}

sub _reformat_long_number {
    my $number = shift;
    while ( $number =~ s/(\d)(\d\d\d)( |$)/$1 $2$3/ ) { }
    return $number;
}

# ---------- EXPORTED FUNCTIONS ------------

# this solution might be only tentative
# (Log::Log4perl or MooseX::Log::Log4perl might be preferred in the future),
# that's why the following declarations are kept apart from the old code.

use Exporter;
use base 'Exporter';

our @EXPORT = qw(log_fatal log_warn log_info log_memory log_set_error_level log_debug);

sub log_fatal           { fatal(@_); }
sub log_warn            { Treex::Core::Log::warn @_; }
sub log_info            { info @_; }
sub log_memory          { memory @_; }
sub log_set_error_level { set_error_level @_; }
sub log_debug           { debug @_; }

1;

# Copyright 2007 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TREEX_ROOT/README
