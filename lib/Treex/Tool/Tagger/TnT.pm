package Treex::Tool::Tagger::TnT;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;
with 'Treex::Tool::Tagger::Role';

has model => ( isa => 'Str', is => 'ro', required => 1, writer => '_set_model' );
has debug => ( isa => 'Bool', is => 'ro', required => 0, default => 0 );
has tntargs => ( isa => 'Str', is => 'ro', required => 0, default => ' -u1 -v0 ' );
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub BUILD {
    my $self = shift;

    my $executable = require_file_from_share( 
        "external_tools/tnt_tagger/tnt/tnt",
        ref( $self ),
    );
    my $modelname = $self->model;
    for my $suffix ( qw/123 lex/ ) {
        $self->_set_model( require_file_from_share( "$modelname.$suffix" ) );
    }

    # strip suffix from the model name
    $self->model =~ m/(.*)\.[^\.]*$/;
    $self->_set_model( $1 );

    # start tnt
    my ( $reader, $writer, $pid );
    my $redir = $self->debug ? '' : '2> /dev/null';
    ( $reader, $writer, $pid ) =
        Treex::Tool::ProcessUtils::bipipe("LC_ALL=en_US.UTF-8 $executable ".$self->tntargs." ".$self->model." - $redir");
    $self->_set_reader( $reader );
    $self->_set_writer( $writer );
    $self->_set_pid( $pid );

    return;
}

sub tag_sentence {
    my $self = shift;
    my $toks = shift;
    return [] if scalar @$toks == 0;

    my $tntwr = $self->_writer;
    my $tntrd = $self->_reader;

    # preserve lines beginning with %%, TnT would skip them!
    my $magic_prefix_doubleperc = "_";
    my @toks = map { /^%%/ ? $magic_prefix_doubleperc . $_ : $_ } @$toks;

    my @eos_toks = ( "", ".", "", "%% end of last sentence" );

    # tokens to force end of sentence
    my $cnt = 0;
    foreach my $tok ( @toks, @eos_toks ) {
        print $tntwr $tok . "\n";
        $cnt++;
        print STDERR "To tagger: " . $tok . "\n" if $self->debug;
    }
    my @gottoks = ();
    my @tags    = ();
    $cnt--;    # last token, the %% is not returned by TnT until next sentence
    while ( $cnt > 0 ) {
        my $got = <$tntrd>;
        die "Failed to read from TnT tagger, better to kill oneself."
            if !defined $got;
        print STDERR "Expecting $cnt toks, got: $got" if $self->debug;
        chomp $got;
        next if $got =~ /^%%/;    # skip TnT comments
        $cnt--;                   # expect one token less
        if ( $got =~ /^$magic_prefix_doubleperc/ ) {
            $got =~ s/^$magic_prefix_doubleperc//;
        }
        my ( $tok, $tag ) = split /\t+/, $got;    #/
        $tag = "" if !defined $tag;
        push @gottoks, $tok;
        push @tags,    $tag;
    }
    splice( @gottoks, 1 - scalar(@eos_toks) );
    splice( @tags,    1 - scalar(@eos_toks) );
    print STDERR "Toks from tagger: " . join( "\t", @gottoks ) . "\n" if $self->debug;
    print STDERR "Tags from tagger: " . join( "\t", @tags ) . "\n"    if $self->debug;

    return \@tags;
}

sub DEMOLISH {
    my ($self) = @_;
    close( $self->_writer );
    close( $self->_reader );
    Treex::Tool::ProcessUtils::safewaitpid( $self->_pid );
    return;
}

1;

__END__

=head1 NAME

Tagger::TnT

Wrapper around Brants's TnT.

Copyright 2008, 2014 Ondrej Bojar, Ales Tamchyna
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
