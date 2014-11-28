package Treex::Core::Log;

use strict;
use warnings;

use 5.008;
use utf8;
use English '-no_match_vars';

use Carp qw(cluck);

use IO::Handle;
use Readonly;
use Time::HiRes qw(time);

use Exporter;
use base 'Exporter';
our @EXPORT = qw(log_fatal log_warn log_info log_debug log_memory running_time);    ## no critic (ProhibitAutomaticExportation)

$Carp::CarpLevel = 1;

binmode STDOUT, ":encoding(utf-8)";
binmode STDERR, ":encoding(utf-8)";

# Autoflush after every Perl statement should enforce that INFO and FATALs are ordered correctly.
{

    #my $oldfh = select(STDERR);
    #$| = 1;
    #select($oldfh);
    *STDERR->autoflush();
}


my @ERROR_LEVEL_NAMES = qw(ALL DEBUG INFO WARN FATAL);
Readonly my %ERROR_LEVEL_VALUE => map {$ERROR_LEVEL_NAMES[$_] => $_} (0 .. $#ERROR_LEVEL_NAMES);

#Readonly my %ERROR_LEVEL_VALUE => (
#    'ALL'   => 0,
#    'DEBUG' => 1,
#    'INFO'  => 2,
#    'WARN'  => 3,
#    'FATAL' => 4,
#);


use Moose::Util::TypeConstraints;
enum 'ErrorLevel' => [keys %ERROR_LEVEL_VALUE];

# how many characters of a string-eval are to be shown in the output
$Carp::MaxEvalLen = 100;

my $unfinished_line;

# By default report only messages with INFO or higher level
my $current_error_level_value = $ERROR_LEVEL_VALUE{'INFO'};

# Time when treex was executed.
our $init_time = time ();

# returns time elapsed from $init_time.
sub running_time
{
    return sprintf('%10.3f', time() - $init_time);
}

# allows to suppress messages with lower than given importance
sub log_set_error_level {
    my $new_error_level = uc(shift);
    if ( not defined $ERROR_LEVEL_VALUE{$new_error_level} ) {
        log_fatal("Unacceptable errorlevel: $new_error_level");
    }
    $current_error_level_value = $ERROR_LEVEL_VALUE{$new_error_level};
    return;
}

sub get_error_level {
    return $ERROR_LEVEL_NAMES[$current_error_level_value];
}

# fatal error messages can't be suppressed
sub log_fatal {
    my $message = shift;
    if ($unfinished_line) {
        print STDERR "\n";
        $unfinished_line = 0;
    }
    my $line = "TREEX-FATAL:" . running_time() . ":\t$message\n\n";
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'DEBUG'} ) {
        if ($OS_ERROR) {
            $line .= "PERL ERROR MESSAGE: $OS_ERROR\n";
        }
        if ($EVAL_ERROR) {
            $line .= "PERL EVAL ERROR MESSAGE: $EVAL_ERROR\n";
        }
    }
    $line .= "PERL STACK:";
    cluck $line;
    run_hooks('FATAL');
    die "\n";
}

# TODO: redesign API - $carp, $no_print_stack

sub log_warn {
    my ( $message, $carp ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'WARN'} ) {
        my $line = "";
        if ($unfinished_line) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        $line .= "TREEX-WARN:" . running_time() . ":\t$message\n";

        if ($carp) {
            Carp::carp $line;
        }
        else {
            print STDERR $line;
        }
    }
    run_hooks('WARN');
    return;
}

sub log_debug {
    my ( $message, $no_print_stack ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'DEBUG'} ) {
        my $line = "";
        if ($unfinished_line) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        $line .= "TREEX-DEBUG:" . running_time() . ":\t$message\n";

        if ($no_print_stack) {
            print STDERR $line;
        }
        else {
            Carp::cluck $line;
        }
    }
    run_hooks('DEBUG');
    return;
}

sub log_info {
    my ( $message, $arg_ref ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'INFO'} ) {
        my $same_line = defined $arg_ref && $arg_ref->{same_line};
        my $line = "";
        if ( $unfinished_line && !$same_line ) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        if ( !$same_line || !$unfinished_line ) {
            $line .= "TREEX-INFO:" . running_time() . ":\t";
        }
        $line .= $message;

        if ($same_line) {
            $unfinished_line = 1;
        }
        else {
            $line .= "\n";
        }

        print STDERR $line;
        if ($same_line) {
            STDERR->flush;
        }
    }
    run_hooks('INFO');
    return;
}

sub progress {    # progress se pres ntred neposila, protoze by se stejne neflushoval
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    if ( not $unfinished_line ) {
        print STDERR "TREEX-PROGRESS:" . running_time() . ":\t";
    }
    print STDERR "*";
    STDERR->flush;
    $unfinished_line = 1;
    return;
}

# ---------- HOOKS -----------------

my %hooks;    # subroutines can be associated with reported events

sub add_hook {
    my ( $level, $subroutine ) = @_;
    $hooks{$level} ||= [];
    push @{ $hooks{$level} }, $subroutine;
    return scalar(@{$hooks{$level}}) - 1;
}

sub del_hook {
    my ( $level, $pos ) = @_;
    $hooks{$level} ||= [];
    if ( $pos < 0 || $pos >= scalar(@{$hooks{$level}}) ) {
        return;
    }
    splice(@{$hooks{$level}}, $pos, 1);

    return;
}

sub run_hooks {
    my ($level) = @_;
    foreach my $subroutine ( @{ $hooks{$level} } ) {
        &$subroutine;
    }
    return;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Core::Log - logger tailored for the needs of Treex

=head1 SYNOPSIS

 use Treex::Core::Log;

 Treex::Core::Log::log_set_error_level('DEBUG');

 sub epilog {
     print STDERR "I'm going to cease!";
 }
 Treex::Core::Log::add_hook('FATAL',&epilog());

 sub test_value {
     my $value = shift;
     log_fatal "Negative values are unacceptable" if $ARGV < 0;
     log_warn "Zero value is suspicious" if $ARGV == 0;
     log_debug "test: value=$value";
 }



=head1 DESCRIPTION

C<Treex::Core::Log> is a logger developed with the Treex system.
It uses more or less standard leveled set of reporting functions,
printing the messages at C<STDERR>.


Note that this module might be completely substituted
by more elaborate solutions such as L<Log::Log4perl> in the
whole Treex in the future


=head2 Error levels


Specifying error level can be used for suppressing
reports with lower severity. This module supports four
ordered levels of report severity (plus a special value
comprising them all).

=over 4

=item FATAL

=item WARN

=item INFO - the default value

=item DEBUG

=item ALL

=back

The current error level can be accessed by the following functions:

=over 4

=item log_set_error_level($error_level)

=item get_error_level()

=back



=head2 Basic reporting functions

All the following functions are exported by default.

=over 4

=item log_fatal($message)

print the message, print the Perl stack too, and exit

=item log_warn($message)

=item log_info($message)

=item log_debug($message)

=back



=head2 Other reporting functions

=over 4

=item log_memory

print the consumed memory

=item progress

print another asterisk in a 'progress bar' composed of asterisks

=back




=head2 Hooks

Another functions can be called prior to reporting events, by
hooking a function on a certain error level event.

=over 4

=item add_hook($level, &hook_subroutine)

add the subroutine to the list of subroutines called prior
to reporting events with the given level

=item run_hooks($level)

run all subroutines for the given error level

=back



=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
