package Treex::Block::T2T::AssignDefaultGrammatemes;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use autodie;

extends 'Treex::Core::Block';

has 'grammateme_file' => ( isa => 'Str', is => 'ro' );

has 'grammatemes' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

has 'da_file' => ( isa => 'Str', is => 'ro' );

has '_da_types' => ( is => 'rw' );

has '_cur_da_type' => ( is => 'rw' );

sub process_start {
    my ($self) = @_;

    my $gram_file = $self->grammateme_file;
    if ( not -f $gram_file ) {
        $gram_file = Treex::Core::Resource::require_file_from_share($gram_file);
    }

    open( my $fh, '<:utf8', ($gram_file) );
    while ( my $line = <$fh> ) {
        chomp $line;
        my ( $key, $val ) = split /\t/, $line;
        $self->grammatemes->{$key} = $val;
    }

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
    close($fh);
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

    if ( $self->grammatemes->{ $self->_cur_da_type . '//' . $tnode->t_lemma . " " . $tnode->formeme } ) {
        $self->_set_grams( $self->grammatemes->{ $self->_cur_da_type . '//' . $tnode->t_lemma . " " . $tnode->formeme } );
    }
    elsif ( $self->grammatemes->{ $self->_cur_da_type . '//' . $tnode->formeme } ) {
        $self->_set_grams( $self->grammatemes->{ $self->_cur_da_type . '//' . $tnode->formeme } );
    }
    elsif ( $self->grammatemes->{ $tnode->t_lemma . " " . $tnode->formeme } ) {
        $self->_set_grams( $tnode, $self->grammatemes->{ $tnode->t_lemma . " " . $tnode->formeme } );
    }
    elsif ( $self->grammatemes->{ $tnode->formeme } ) {
        $self->_set_grams( $tnode, $self->grammatemes->{ $tnode->formeme } );
    }
}

sub _set_grams {
    my ( $self, $tnode, $grams ) = @_;

    foreach my $gram ( split /\+/, $grams ) {
        my ( $gram_type, $gram_val ) = split /=/, $gram;

        if ( $gram_type eq 'nodetype' ) {
            $tnode->set_nodetype($gram_val);
        }
        elsif ( $gram_type eq 'sentmod' ) {
            $tnode->set_sentmod($gram_val);
        }
        else {
            $tnode->set_attr( "gram/$gram_type", $gram_val );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::AssignDefaultGrammatemes

=head1 DESCRIPTION

Given a list of default grammatemes per t-lemma/formeme pair (backoff to formemes only), 
this will assign them to all matching nodes.

This is intended to be used with the Tgen generator output and the 
L<Treex::Block::Print::GrammatemesForTgen> block.

=head1 PARAMETERS

=over

=item grammateme_file

Path to the list of default grammatemes to be used. If the path is not valid as such,
it is searched in the Treex shared directory (and possibly downloaded from the web).

=item da_file

Path to the list of DAs corresponding to each of the trees in the input file; used for
a more precise grammateme assignment. 

=back

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014–2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
