package Treex::Block::A2A::CS::FixAuxT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

use Treex::Tool::Depfix::CS::SimpleTranslator;

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( ( $dep->form eq 'se' || $dep->form eq 'si' ) && $d->{tag} =~ /^P/ ) {
        if ( $g->{tag} =~ /^V/ || $g->{tag} =~ /^A[GC]/ ) {
            # parent is a verb (or verb-like thing) - this is probably OK
            return;
        }
        else {
            # parent is not a verb, "se" is incorrect here
            my $ennode = $self->en($dep);
            if ($self->magic =~ /auxt_missc/
                && defined $ennode && $ennode->tag =~ /^V/
            ) {

                # try to reconstruct the missing node 
                $self->logfix1( $dep, "AuxT +" );
                
                # try to translate the node
                my $translator = Treex::Tool::Depfix::CS::SimpleTranslator->new();
                my ($translation) = $translator->translate_lemma($ennode->lemma);
                $translation =~ s/_.*$//;

                # tag: at least we know it should be a verb
                # (but maybe copy that from EN?)
                my $new_tag =
                    Treex::Tool::Depfix::CS::TagHandler->get_empty_tag();
                $new_tag = Treex::Tool::Depfix::CS::TagHandler->set_tag_cat(
                    $new_tag, 'pos', 'V' );
                
                # the new node is to be a parent of "se"
                my $new_node = $self->add_parent(
                    {
                        form => $translation,
                        lemma => $translation,
                        tag => $new_tag, 
                    },
                    $dep,
                );
                $new_node->shift_after_node($dep, {without_children=>1});
                
                $self->logfix2($new_node);
            }
            else {
                $self->logfix1( $dep, "AuxT" );
                $self->remove_node($dep);
                $self->logfix2(undef);
        }
        }
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixAuxT

Fixing reflexive tantum ("se", "si").

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
