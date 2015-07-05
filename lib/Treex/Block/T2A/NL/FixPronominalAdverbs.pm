package Treex::Block::T2A::NL::FixPronominalAdverbs;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $lemma = $anode->lemma or return;

    return if ( $lemma !~ /^(er|waar)$/ );

    my $parent = $anode->get_parent();
    return if ( ( $parent->afun // '' ) ne 'AuxP' );

    $anode->set_parent( $parent->get_parent() );
    my $lemma = $anode->lemma . $parent->lemma;
    $lemma =~ s/met$/mee/;
    $anode->set_lemma( $lemma );

    $parent->remove();
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::NL::FixPronominalAdverbs

=head1 DESCRIPTION

Fixing pronominal adverbs, i.e. removing prepositional nodes 
above 'er' and 'waar' and merging the preposition into the lemma.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
