package Treex::Block::Print::Debug::IsReferential;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Print::Debug';

sub prepare_features_ref {
    my ($self, $zone) = @_;
    
    my @a_nodes = $zone->get_atree->get_descendants;
    my @it_nodes = grep {$_->form =~ /^[Ii]t$/} @a_nodes;

    my $feats = {};

    foreach my $it_anode (@it_nodes) {
        my @lex_tnodes = $it_anode->get_referencing_nodes('a/lex.rf');
        if (@lex_tnodes > 0) {
            my $lex_tnode = shift @lex_tnodes;
            if ($lex_tnode->get_coref_nodes > 0) {
                $feats->{$it_anode->id} = 1;
            }
            else {
                $feats->{$it_anode->id} = 0;
            }
        }
        else {
            $feats->{$it_anode->id} = 0;
        }
    }
    return $feats;
}

sub prepare_features_tst {
    my ($self, $zone) = @_;

    my @t_nodes = $zone->get_ttree->get_descendants;
    my @it_tnodes = grep {defined $_->wild->{referential}} @t_nodes;

    my %feats = map {$_->get_lex_anode->id => $_->wild->{referential}} @it_tnodes;
    return \%feats;
}

1;

=over

=item Treex::Block::Print::Debug::IsReferential

Debugging 'referential' flag for English pronouns 'it'.

=back

=cut

# Copyright 2012 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
