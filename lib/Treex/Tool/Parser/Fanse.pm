package Treex::Tool::Parser::Fanse;
use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;

my $TOOL_DIR = "$ENV{TMT_ROOT}/share/installed_tools/parser/fanseparser";
my $JAR      = 'fanseparser-0.2.2.jar';

has memory => ( isa => 'Str', is => 'ro', default => '8000m' );

has [qw( _reader _writer _pid )] => ( is => 'rw' );

# TODO automatically download all the files needed if they are missing
# but Treex::Core::Resource cannot download whole directory so far
# alternatively we can try to "install" the tool

sub BUILD {
    my ($self) = @_;

    my $jar = "$TOOL_DIR/$JAR";
    log_fatal "Cannot find $jar\n" if !-f $jar;

    my $cmd = 'java -Xmx' . $self->memory . " -cp $jar tratz.parse.ParsingScript";
    $cmd .= " -wndir $TOOL_DIR/data/wordnet3/";
    $cmd .= " -posmodel $TOOL_DIR/posTaggingModel.gz";
    $cmd .= " -parsemodel $TOOL_DIR/parseModel.gz";
    $cmd .= " -sreader tratz.parse.io.TokenizingSentenceReader";
    $cmd .= " -swriter tratz.parse.io.DefaultSentenceWriter";
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe($cmd);
    $self->_set_reader($reader);
    $self->_set_writer($writer);
    $self->_set_pid($pid);

    # FanseParser outputs those messages correctly to stderr,
    # so they are not captured by bipipe/IPC::Open2.
    # open3 would be needed
    #    for my $expected (
    #        'Loading WordNet...Done',
    #        'Loading POS-tagging model...Done',
    #        'Loading parsing model...Done',
    #        'Beginning sentence processing:Parsing started',
    #        )
    #    {
    #        my $line = <$reader>;
    #        chomp $line;
    #        log_fatal "Unexpected parser output '$line'\nExpecting '$expected'"
    #            if $line !~ /^\Q$expected\E/;
    #    }
    return;
}

sub parse {
    my ( $self, $forms ) = @_;
    my $writer = $self->_writer;
    my $reader = $self->_reader;
    my $count  = scalar @$forms;

    # write input (escaping tokens with spaces)
    print $writer join ' ', map { s/ /_/g; $_ } @$forms;
    print $writer "\n";

    # read output
    my ( @postags, @parents, @deprels );
    for my $i ( 1 .. $count ) {
        my $got = <$reader>;
        chomp $got;
        my @items = split( /\t/, $got );
        $count--;
        my $expected_token = $forms->[ $i - 1 ];
        $expected_token =~ s/ /_/g;
        #log_fatal "Unexpected parser output '$got'.\nExpecting token $expected_token"
        #    if $items[1] ne $expected_token;
        push @postags, $items[4];
        push @parents, $items[6];
        push @deprels, $items[7];
    }

    # read the empty line dividing sentences in CoNLL
    <$reader>;

    return ( \@parents, \@deprels, \@postags );
}

# TODO kill $self->_pid in DEMOLISH

1;

__END__


=head1 NAME

Treex::Tool::Parser::Fanse - dependency parser of Tratz & Hovy (2011)

=head1 SYNOPSIS

  my $parser = Treex::Tool::Parser::Fanse->new();
  # default is a model and an executable trained for English
  my ( $parent_indices, $edge_labels, $pos_tags ) = $parser->parse( \@forms );

=head1 DESCRIPTION

"Fast, Accurate, Non-Projective, Semantically-Enriched Parser"

http://www.isi.edu/publications/licensed-sw/fanseparser/

Stephen Tratz and Eduard Hovy. 2011. A Fast, Accurate, Non-Projective, Semantically-Enriched Parser. In Proceedings of the 2011 Conference on Empirical Methods in Natural Language Processing. Edinburgh, Scotland, UK. 

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

