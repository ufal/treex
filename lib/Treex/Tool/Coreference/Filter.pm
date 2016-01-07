package Treex::Tool::Coreference::Filter;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Tool::Coreference::NodeFilter::Noun;
use Treex::Block::My::CorefExprAddresses;

use List::MoreUtils qw/any/;

sub get_types {
    my ($node) = @_;
    my $types;
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1})) {
        $types->{perspron} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => -1})) {
        #$type = "perspron_unexpr";
        $types->{zero} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {skip_nonref => 1})) {
        $types->{'#perspron.coref'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 0, reflexive => -1})) {
        $types->{'#perspron.no_refl'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($node)) {
        $types->{relpron} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Block::My::CorefExprAddresses::_is_cor($node)) {
        #$type = "cor";
        $types->{zero} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::Noun::is_sem_noun($node)) {
        $types->{'noun'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::Noun::is_sem_noun($node, {third_pers => 1})) {
        $types->{'noun.3_pers'} = 1;
    }
    #elsif (Treex::Block::My::CorefExprAddresses::_is_cs_ten($node)) {
    #    $type = "ten";
    #}
    return $types;
}


sub matches {
    my ($tnode, $node_types) = @_;

    my $types;
    if (defined $tnode->wild->{filter_types}) {
        $types = { map {$_ => 1} @{$tnode->wild->{filter_types}} };
    }
    else {
        $types = get_types($tnode);
        $tnode->wild->{filter_types} = [ sort keys %$types ];
    }
    
    return (any {$types->{$_}} @$node_types);
}

1;

# TODO adjust docs

__END__

=head1 NAME

Treex::Tool::Coreference::Filter

=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied

=head2 Types:
=over
=item perspron - all personal, possessive and reflexive pronouns in 3rd person (English, Czech)
=item zero - all #Cor nodes and unexpressed #PersPron nodes possibly in 3rd person (English, Czech)
=item relpron - all relative pronouns, relativizing adverbs, possibly including also some interrogative and fused pronouns (English, Czech)
=item all_anaph - perspron + zero + relpron
=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
