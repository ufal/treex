package Treex::Block::Write::LayerAttributes::Determiner;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $anode ) = @_;

    # only include regular adjectives and past participles 
    if ( $anode->iset->pos eq 'adj' ) {
        return '' if ( $anode->iset->adjtype || $anode->iset->prontype );
    }
    elsif ( $anode->iset->pos eq 'verb' ) {
        return '' if ( !$anode->match_iset( 'verbform' => 'part', 'tense' => 'past' ) );
    }
    else {
        return '';
    }
    my $art = first { $_->iset->adjtype || $_->iset->prontype } $anode->get_children( { ordered => 1 } );
    return $art->lemma if ($art);
    my ($aparent) = $anode->get_eparents( { or_topological => 1 } );
    return '' if ( !$aparent or $aparent->is_root );
    $art = first { $_->iset->adjtype || $_->iset->prontype } $aparent->get_echildren( { or_topological => 1, ordered => 1 } );
    return $art->lemma if ($art);
    my ($agrandpa) = $aparent->get_eparents( { or_topological => 1 } );
    return '' if ( !$agrandpa or $agrandpa->is_root );
    $art = first { $_->iset->adjtype || $_->iset->prontype } $agrandpa->get_echildren( { or_topological => 1, ordered => 1 } );
    return $art->lemma if ($art);
    return '';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::Determiner

=head1 DESCRIPTION

Finds and returns the lemma of the determiner of the current NP, if applicable. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
