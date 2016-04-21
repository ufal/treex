package Treex::Block::Misc::JoinBundles;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $doc ) = @_;
    my @bundles = $doc->get_bundles();
    my $last_bundle;
    foreach my $bundle (@bundles){
        my $id = $bundle->id;
        if ($id =~ /(.+)_1of(\d+)$/){
            $bundle->set_id("$1_joined$2");
            $last_bundle = $bundle;
        } elsif ($id =~ /_(\d+)of(\d+)+$/){
            $self->join_bundles($last_bundle, $bundle);
        } else {
            $last_bundle = undef;
        }
    }
    return;
}

sub join_bundles {
    my ($self, $bundle1, $bundle2 ) = @_;
    if (!$bundle1) {
        log_warn "There is no previous bundle to which we could join " . $bundle2->id;
        return;
    }

    foreach my $zone2 ($bundle2->get_all_zones()){
        my ($lang, $sele) = ($zone2->language, $zone2->selector);
        my $zone1 = $bundle1->get_or_create_zone($lang, $sele);

        # Join attribute "sentence" with one space
        if (defined $zone2->sentence){
            if (defined $zone1->sentence) {
                $zone1->set_sentence($zone1->sentence . ' ' . $zone2->sentence);
            } else {
                $zone1->set_sentence($zone2->sentence);
            }
        }

        # Join the trees
        for my $layer (qw(a t n p)){
            next if !$zone2->has_tree($layer);
            my $tree1 = $zone1->has_tree($layer) ? $zone1->get_tree($layer) : $zone1->create_tree($layer);
            foreach my $subtree ($zone2->get_tree($layer)->get_children()){
                $subtree->set_parent($tree1);
                $subtree->shift_after_subtree($tree1) if $layer =~ /a|t/;
            }
        }
    }
    
    $bundle2->remove();
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::JoinBundles - join all trees in resegmented bundles

=head1 MOTIVATION

Some resources (most notably WMT newstest) are segmented to chunks of text
which mostly correspond to sentences, but sometimes contain more than one sentence.
Sometimes we want to process such documents in Treex and output (Write::*)
the result in a format where one output segement correspond to one input segement.
(So e.g. for "one-sentence-per-line writers", we have the same number of input and output lines.)

However, most Treex blocks expect exactly one (linguistic) sentence in each bundle.
The solution is to use block C<W2A::ResegmentSentences> after the reader
and C<Misc::JoinBundles> before the writer.

=head1 DESCRIPTION

If id of a bundle (e.g. I<s42_2of3>) suggest that the bundle was produced by C<W2A::ResegmentSentences>,
it is merged with all other "subsegement" bundles (I<s42_1of3> and I<s42_3of3>).
Technically, this means that all bundles except the first one are added to the first one.
Merging/adding means that for each zone,

=over

=item

the attribute sentence is concatenated (joined with a single space)

=item

all trees (a,t,n,p) are hanged under the original technical node of the first bundle

=back

=head1 PARAMETERS

=head1 SEE ALSO

L<Treex::Block::W2A::ResegmentSentences>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
