package Treex::Tool::Coreference::NodeFilter;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Tool::Coreference::NodeFilter::DemonPron;
use Treex::Tool::Coreference::NodeFilter::Noun;
use Treex::Tool::Coreference::NodeFilter::Verb;
use Treex::Tool::Coreference::NodeFilter::Coord;

use List::MoreUtils qw/any/;

sub get_types {
    my ($node) = @_;
    my @types = @{$node->wild->{filter_types} // []};
    if (!@types) {
        my $types_hash = get_types_force($node);
        @types = sort keys %$types_hash;
        $node->wild->{filter_types} = \@types;
    }
    return @types;
}

sub get_types_force {
    my ($node) = @_;
    my $types;
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1})) {
        $types->{perspron} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1, possessive => 1})) {
        $types->{'perspron.poss'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => -1})) {
        $types->{perspron_unexpr} = 1;
        $types->{zero} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {skip_nonref => 1})) {
        $types->{'#perspron.coref'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1, reflexive => -1}) || 
        Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_prodrop($node, {parent_pos => 'v_expr', functor => 'ACT'})) {
        $types->{'#perspron.no_refl'} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1, reflexive => 1})) {
        $types->{'reflpron'} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($node)) {
        $types->{relpron} = 1;
        $types->{all_anaph} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_coz_cs($node)) {
        $types->{'relpron.coz'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_coz_cs($node) ||
        Treex::Tool::Coreference::NodeFilter::RelPron::is_co_cs($node)) {
        $types->{'relpron.co_coz'} = 1;
    }
    #if (Treex::Block::My::CorefExprAddresses::_is_cor($node)) {
    #    $types->{cor} = 1;
    #    $types->{zero} = 1;
    #    $types->{all_anaph} = 1;
    #}
    if (Treex::Tool::Coreference::NodeFilter::Noun::is_sem_noun($node)) {
        $types->{'noun'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::Noun::is_sem_noun($node, {third_pers => 1})) {
        $types->{'noun.3_pers'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::Verb::is_sem_verb($node)) {
        $types->{'verb'} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::DemonPron::is_demon($node)) {
        $types->{demonpron} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::Coord::is_coord_root($node)) {
        $types->{coord} = 1;
    }
    return $types;
}

sub get_matched_set {
    my ($node, $node_types) = @_;
    my %types = map {$_ => 1} get_types($node);
    return grep {$types{$_}} @$node_types;
}

sub matches {
    my ($node, $node_types) = @_;
    return 1 if (!@$node_types);
    return get_matched_set($node, $node_types) > 0;
}

1;

# TODO adjust docs

__END__

=head1 NAME

Treex::Tool::Coreference::NodeFilter

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
=item all_anaph - <perspron> + <zero> + <relpron>
=item #perspron.coref - <perspron> + unexpressed #PersPron nodes - pronouns marked as non-referential.
=item #perspron.no_refl - <perspron> + unexpressed #PersPron nodes - reflexive pronouns
=item noun - semantic nouns
=item noun.3_pers - semantic nouns in 3rd or unknown person
=item verb - semantic verbs
=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
