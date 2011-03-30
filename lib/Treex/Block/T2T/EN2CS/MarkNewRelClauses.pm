package Treex::Block::T2T::EN2CS::MarkNewRelClauses;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if (( $tnode->formeme || "" ) eq 'v:fin'
        and $tnode->parent->precedes($tnode)
        and $tnode->src_tnode and ( $tnode->src_tnode->formeme || '' ) =~ /v:(inf|attr|ger)/
        and ( $tnode->get_parent->formeme || '' ) =~ /^n/
        )
    {

        $tnode->set_is_relclause_head(1);
        $tnode->set_formeme('v:rc');

    }
}

1;

=over

=encoding utf8

=item Treex::Block::T2T::EN2CS::MarkNewRelClauses

If gerunds, infinitives or attributive verb forms are turned
to finite verb clauses, then they are likely to become relative
clause. In such cases, relative pronouns must be added as well
as grammatical coreference links to the governing noun.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
