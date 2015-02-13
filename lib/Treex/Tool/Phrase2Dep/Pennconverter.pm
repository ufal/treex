package Treex::Tool::Phrase2Dep::Pennconverter;
use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;

has after_rich_np => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'The phrase structure contains rich NP bracketing. '
        . 'E.g. PennTB pathed with annotation by David Vadas.',
);

has after_traces => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'The phrase structure contains traces and function tags.',
);

has [qw( _reader _writer _pid )] => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    #to be changed
    use Treex::Core::Resource;
    my $jar = Treex::Core::Resource::require_file_from_share(
        'installed_tools/pennconverter/pennconverter.jar',
        ref($self)
    );

    my $options = '';
    if ( !$self->after_traces ) {
        $options .= ' -raw';
    }

    if ( !$self->after_rich_np ) {
        $options .= ' -rightBranching=false';
    }

    # Head-selection rules that should look like CoNLL 2007
    # "-conll2007" seems to be a shortcut for
    # "-coordStructure=prague   -advFuncs=false -imAsHead=false
    #  -splitSmallClauses=false -name=false     -suffix=false"
    $options .= ' -conll2007';

    my $command = "java -jar $jar $options 2>/dev/null";
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);
    $self->_set_reader($reader);
    $self->_set_writer($writer);
    $self->_set_pid($pid);
    return;
}

sub convert {
    my ( $self, $mrg_string ) = @_;
    my $writer = $self->_writer;
    my $reader = $self->_reader;
    print $writer $mrg_string . "\n";

    my ( @parents, @deprels );
    while ( my $line = <$reader> ) {
        chomp $line;
        last if $line eq '';
        my @conll_columns = split /\t/, $line;
        push( @parents, $conll_columns[6] );
        push( @deprels, $conll_columns[7] );
    }
    log_fatal "Pennconverter was not able to convert: '$mrg_string'" if !@parents;
    return ( \@parents, \@deprels );
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

Treex::Tool::Phrase2Dep::Pennconverter - Wrapper for Java PennConverter tool

=head1 SYNOPSIS

  use Treex::Tool::Phrase2Dep::Pennconverter;
  my $pennconverter = Treex::Tool::Phrase2Dep::Pennconverter->new({
      after_traces=>1,
      after__rich_np=>1,
  });

  my $penn_string = '(S (NP (NNP John)) (VP (VBZ loves) (NP (NNP Mary))))';
  my ($parent_indices_ref, $deprels_ref) = $pennconverter->convert($penn_string);

=head1 DESCRIPTION

http://nlp.cs.lth.se/software/treebank_converter/

=cut

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
