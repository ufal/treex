package Treex::Block::W2A::EN::FixTagsQuotes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {

    my ( $self, $aroot ) = @_;
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    for ( my $i = 0; $i < @anodes; ++$i ) {
        my $anode = $anodes[$i];

        # a POS marker with a space after it -- this is suspicious, might be a quote
        if ( $anode->form eq '\'' and $anode->tag eq 'POS' and not $anode->no_space_after ) {

            # try to find corresponding left quote
            my $j;
            for ( $j = $i - 1; $j >= 0; --$j ) {
                last if ( $anodes[$j]->form eq '`' or ( $anodes[$j]->form eq '\'' and $j == 0 or not $anodes[ $j - 1 ]->no_space_after ) );
            }
            next if ($j < 0);
            
            # quote found and the next word is not "s", "d", "m" (as in I'm, I'd, he's)
            if ($i == @anodes-1 or $anodes[$i+1] !~ /^[sdm]$/ ){
                $anode->set_tag('\'\'');
                $anodes[$j]->set_tag( '``');
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::EN::FixTagsQuotes

=head1 DESCRIPTION

Fix tagging of single quotes, which might get mis-tagged as possessive markers.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
