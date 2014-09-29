package Treex::Block::Print::GrammatemesForTgen;


use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Print::Overall'; 

has '_stats' => ( is => 'rw', default => sub { {} } );

sub build_language { return log_fatal "Parameter 'language' must be given"; }

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $gram = $tnode->get_attr('gram');
    my $val = join( '+', map { $_ . '=' . $gram->{$_} } sort keys %$gram );

    $self->_inc( $tnode->t_lemma . " " . $tnode->formeme, $val );
    $self->_inc( $tnode->formeme,                         $val );
}

sub _inc {
    my ( $self, $key, $val ) = @_;

    if ( !defined( $self->_stats->{$key} ) ) {
        $self->_stats->{$key} = {};
    }
    $self->_stats->{$key}->{$val} = ( $self->_stats->{$key}->{$val} // 0 ) + 1;
}

sub _print_stats {
    my ($self) = @_;

    foreach my $key ( keys %{ $self->_stats } ) {
        my %vals = %{ $self->_stats->{$key} };
        my ($most_freq_val) = sort { $vals{$b} <=> $vals{$a} } keys %vals;
        print { $self->_file_handle } $key, "\t", $most_freq_val, "\n";
    }
}

sub _reset_stats {
    my ($self) = @_;
    $self->_set_stats( {} );
}

1;
