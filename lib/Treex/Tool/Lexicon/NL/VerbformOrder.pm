package Treex::Tool::Lexicon::NL::VerbformOrder;

use utf8;
use strict;
use warnings;

# Normalized verbal order for signatures: finites > modal infinitives > infinitives > participles
sub verbform_priority {
    my ($anode) = @_;
    return 5 if ( $anode->match_iset( 'verbform' => 'fin' ) );
    return 4 if ( $anode->wild->{is_aan_het} );
    return 3 if ( $anode->match_iset( 'verbform' => 'inf' ) and $anode->lemma =~ /(kunnen|moeten|willen|mogen)/ );
    return 2 if ( $anode->match_iset( 'verbform' => 'inf' ) );
    return 1;
}

sub normalized_verbforms {
    my ($tnode) = @_;
    my @anodes = sort { verbform_priority($b) <=> verbform_priority($a) } grep { $_->is_verb || $_->wild->{is_aan_het} } $tnode->get_anodes( { ordered => 1 } );
    return @anodes;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::NL::VerbformOrder

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::NL::VerbformOrder;
 my @verbforms = Treex::Tool::Lexicon::NL::VerbformOrder::normalized_verbforms($t_node);

=head1 DESCRIPTION

Orders auxiliary + lexical a-nodes of a t-node according to their "importance"/normal order 
(the "most" finite form goes left).

Priority: finites, infinite modals, other infinitives, everything else. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
