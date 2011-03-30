package Treex::Block::T2T::EN2CS::ValencyRelatedRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my @echildren = $tnode->get_echildren( { or_topological => 1 } );

    # "He managed to..." -> "Podařilo se mu..."
    if ($tnode->t_lemma =~ /^((po)?dařit|líbit)/
        && $tnode->formeme =~ /fin/
        && grep { $_->formeme eq 'v:inf' } @echildren
        )
    {
        foreach my $subj ( grep { $_->formeme =~ /n:1/ } @echildren ) {
            $subj->set_formeme('n:3');
        }
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::ValencyRelatedRules

Rules for specific shifts in valency frames.

=back

=cut

# Copyright 2010-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
