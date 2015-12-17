package Treex::Block::Print::GrammatemesForTgen;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Print::Overall';

has '_stats' => ( is => 'rw', default => sub { {} } );

has 'da_file' => ( isa => 'Str', is => 'ro' );

has '_da_types' => ( is => 'rw' );

has '_cur_da_type' => ( is => 'rw' );

sub build_language { return log_fatal "Parameter 'language' must be given"; }

sub process_start {
    my ($self) = @_;

    if ( $self->da_file ) {
        my @das = ();

        open( my $fh, '<:utf8', $self->da_file );
        while ( my $line = <$fh> ) {
            my ($da_type) = ( $line =~ /^([a-z_?]*)\(/ );
            push @das, $da_type;
        }
        close($fh);
        $self->_set_da_types( \@das );
    }
    return;
}

sub process_ttree {
    my ( $self, $troot ) = @_;

    if ( $self->_da_types ) {
        $self->_set_cur_da_type( shift @{ $self->_da_types } );
    }
    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
        $self->process_tnode($tnode);
    }
    $self->_set_cur_da_type(undef);
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $gram     = $tnode->get_attr('gram');
    my $nodetype = $tnode->nodetype;
    my $sentmod  = $tnode->sentmod;
    my $val      = "nodetype=$nodetype+" . join( '+', map { $_ . '=' . $gram->{$_} } sort keys %$gram );
    if ($sentmod) {
        $val .= "+sentmod=$sentmod";
    }
    if ( $self->_cur_da_type ) {
        $self->_inc( $self->_cur_da_type . '//' . $tnode->t_lemma . " " . $tnode->formeme, $val );
        $self->_inc( $self->_cur_da_type . '//' . $tnode->formeme,                         $val );
    }
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

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::GrammatemesForTgen

=head1 DESCRIPTION

Prints the most common grammatemes found with the given t-lemma & formeme pair (backoff to
formeme only), to be used for surface realization of the Tgen generator output
(which currently lacks grammatemes altogether) via the L<Treex::Block::T2T::AssignDefaultGrammatemes>
block.

=head1 PARAMETERS

=over

=item da_file

Path to the list of DAs corresponding to each of the trees in the input file; used for
a more precise grammateme assignment. 

=back

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014–2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
