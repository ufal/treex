package Treex::Block::Write::LayerAttributes::FunctorsFromVallex;
use Moose;

use Treex::Core::Common;

use Treex::Tool::Vallex::ValencyFrame;
use Treex::Tool::Vallex::FrameElement;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '' ] } );

sub modify_single {

    my ( $self, $parent_tlemma, $formeme ) = @_;

    # get rid of undefs
    return ( undef, undef ) if ( !defined($parent_tlemma) || !defined($formeme) );

    # try to find lemma in Vallex
    my @frames = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( 'vallex.xml', 'cs', $parent_tlemma );

    # get possible formeme subsets
    my @formeme_subsets = _get_formeme_subsets($formeme);

    # try to find functors matching my formeme
    my ( %functors );

    foreach my $frame (@frames) {
        map { $functors{ $_->functor } = 1 } @{ $frame->elements_have_form($formeme) };
        foreach my $formeme_subset (@formeme_subsets) {
            map { $functors{ $_->functor } = 1 } @{ $frame->elements_have_form($formeme_subset) };
        }
    }

    # return the results (will be empty if no corresponding functors are found)
    return join( ' ', sort { $a cmp $b } keys %functors );
}

# Get possible formeme subsets (taking just one preposition/subjunction at a time) for formemes with two or more prepositions
sub _get_formeme_subsets {

    my ($formeme) = @_;
    my ( $syntpos, $prepjunc_str, $form ) = $formeme =~ /^(.+):(.+)\+([^\+]+)$/;
    return if ( !$prepjunc_str );

    my @prepjuncs = split( /\_/, $prepjunc_str );
    my @subsets;

    foreach my $prepjunc (@prepjuncs) {
        push @subsets, "$syntpos:$prepjunc+$form";
    }
    return @subsets;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::FunctorsFromVallex

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::FunctorsFromVallex->new();
    
    my $parent_tlemma = 'trápit';
    my $formeme = 'n:4';   
    # prints 'PAT'
    print $modif->modify_all( $parent_tlemma, $formeme );
    
    $parent_tlemma = 'čekat';
    $formeme = 'n:od_na+4'; # weird formeme due to wrong parsing    
    # prints 'PAT ORIG'
    print $modif->modify_all( $parent_tlemma, $formeme );      


=head1 DESCRIPTION

Given a parent t-lemma a and a formeme, this finds all corresponding functors from the PDT-VALLEX valency lexicon.

If the t-lemma is not listed in PDT-VALLEX or the formeme does not appear in the  corresponding entry, 
the output is an empty string.
A backoff to just one preposition at a time is used for formemes with more than one preposition.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
