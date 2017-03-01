package Treex::Block::A2A::NodeIdFromCoNLLFeats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Checks whether conll/feat contains the "id" feature where the original node
# id is stored. Resets the node id.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $language = $zone->language();
    my $selector = $zone->selector();
    my $root = $zone->get_atree();
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $features = $node->conll_feat();
        if(defined($features))
        {
            my @idfeatures = grep {m/^id=\S+$/i} (split(/\|/, $features));
            my @ids = map {s/^id=//i; $_} (@idfeatures);
            if(scalar(@ids)>=1)
            {
                $node->set_id("$language-$selector-$ids[0]");
                my @nonidfeatures = grep {!m/^id=\S+$/i} (split(/\|/, $features));
                $node->set_conll_feat(join('|', @nonidfeatures));
            }
        }
    }
}



1;

=over

=item Treex::Block::A2A::NodeIdFromCoNLLFeats

Checks whether conll/feat contains the "id" feature where the original node
id is stored. Resets the node id.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
