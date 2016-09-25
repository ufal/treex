package Treex::Block::Misc::MoveNodesAfterResegment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_document {
    my ( $self, $doc ) = @_;
    my @bundles = $doc->get_bundles();
    my $last_bundle;
    foreach my $bundle (@bundles){
        my $id = $bundle->id;
        if ($id =~ /(.+)_1of(\d+)$/){
            $last_bundle = $bundle;
        } elsif ($id =~ /_(\d+)of(\d+)+$/ and $1 > 1){
            $self->move_nodes($last_bundle, $bundle);
            $last_bundle = $bundle;
        } else {
            $last_bundle = undef;
        }
    }
    return;
}

sub move_nodes {
    my ($self, $bundle1, $bundle2 ) = @_;

    my $zone1 = $bundle1->get_zone($self->language, $self->selector);
    my $zone2 = $bundle2->get_zone($self->language, $self->selector);

    my $sent = $zone1->sentence;
    my @anodes = $zone1->get_tree('a')->get_descendants({ordered=>1});
    my $first_form = $anodes[0]->form;

    # move after the first sentence
    while (@anodes and $sent and $sent =~ /^\s*$first_form/){
        $sent =~ s/^\s*$first_form//;
        shift @anodes;
        $first_form = $anodes[0]->form if (@anodes);
    }

    # move all the nodes into the 2nd bundle
    my $tree2 = $zone2->create_tree('a');
    foreach my $anode (@anodes){
        $anode->set_parent($tree2);
        $anode->shift_after_subtree($tree2);
    }
   
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::MoveNodesAfterResegment -- fix for resegmenting pre-tokenized sentences

=head1 DESCRIPTION

Moves a-nodes from pre-tokenized sentences into bundles created by C<W2A::ResegmentSentences>.
Expects no normalization in word forms, but the tokens may already be tagged or lemmatized.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
