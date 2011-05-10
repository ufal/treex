package Treex::Tools::Parser::Zpar;
use Moose;
use Treex::Core::Common;

use ProcessUtils;

has model => ( isa => 'Str', is => 'ro', default => 'en' );
has tool  => ( isa => 'Str', is => 'ro', default => 'zpar.en' );
has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    my $executable = "$ENV{TMT_ROOT}/share/installed_tools/parser/zpar/" . $self->tool;
    die "Cannot execute $executable\n" if !-x $executable;

    my $modeldir = "$ENV{TMT_ROOT}/share/data/models/parser/zpar/";
    die "Missing $modeldir\n" if !-d $modeldir;
    my $model = $modeldir . $self->model;
    die "Cannot find the model $model/depparser\n" if !-f "$model/depparser";

    my ( $reader, $writer, $pid ) = ProcessUtils::bipipe("$executable $model");
    $self->_set_reader($reader);
    $self->_set_writer($writer);
    $self->_set_pid($pid);

    for my $expected (
        'Parsing started',
        '[tagger] Loading model... done.',
        '[parser] Loading scores... done.',
        '[labeler] Loading scores... done.'
        )
    {
        my $line = <$reader>;
        chomp $line;
        log_fatal "Unexpected parser output '$line'\nExpecting '$expected'"
            if $line !~ /^\Q$expected\E/;
    }
    return;
}

sub parse {
    my ( $self, $forms ) = @_;
    my $writer = $self->_writer;
    my $reader = $self->_reader;
    my $count  = scalar @$forms;

    # write input
    print $writer join ' ', @$forms;
    print $writer "\n";

    # read output
    my ( @postags, @parents, @deprels );

    for my $i ( 1 .. $count ) {
        my $got = <$reader>;
        chomp $got;
        my @items = split( /\t/, $got );
        $count--;
        my $token = $forms->[ $i - 1 ];
        log_fatal "Unexpected parser output '$got'.\nExpecting =~ /^$token/" if $items[0] ne $token;
        push @postags, $items[1];
        push @parents, $items[2];
        push @deprels, $items[3];
    }

    # read empty line and "Sentence x processed in y sec."
    <$reader>;
    <$reader>;

    return ( \@parents, \@deprels, \@postags );
}

# TODO kill $self->_pid in DEMOLISH

1;

__END__


=head1 NAME

Treex::Tools::Parser::Zpar - transition-based dependency parser

=head1 SYNOPSIS

  my $parser = Treex::Tools::Parser::Zpar->new();
  # default is a model and an executable trained for English
  # can be set by model and tool parameters
  my ( $parent_indices, $edge_labels, $pos_tags ) = $parser->parse( \@forms );

=head1 DESCRIPTION

http://sourceforge.net/projects/zpar/files/0.4/zpar.zip/download
http://www.cl.cam.ac.uk/~yz360/zpar.html

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

