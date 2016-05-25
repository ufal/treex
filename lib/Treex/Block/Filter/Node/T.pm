package Treex::Block::Filter::Node::T;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;

use List::MoreUtils qw/none/;

requires 'process_filtered_tnode';

subtype 'CommaArrayRef' => as 'ArrayRef';
coerce 'CommaArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'node_types' => ( is => 'ro', isa => 'CommaArrayRef', coerce => 1 );

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
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($node)) {
        $types->{relpron} = 1;
        $types->{all_anaph} = 1;
    }
    if (_is_cor($node)) {
        #$type = "cor";
        $types->{zero} = 1;
        $types->{all_anaph} = 1;
    }
    return $types;
}

sub _is_cor {
    my ($node) = @_;
    return 0 if ($node->get_layer ne "t");
    return ($node->t_lemma eq "#Cor");
}

sub process_tnode {
    my ($self, $tnode) = @_;
    
    my $types = get_types($tnode);
    return if (none {$types->{$_}} @{$self->node_types});

    $tnode->wild->{filter_types} = join ",", keys %$types;
    $self->process_filtered_tnode($tnode);
}

1;

__END__

=head1 NAME

Treex::Block::Filter::Node::T

=head1 DESCRIPTION

The role that applies process_tnode only to the specified category of t-nodes.

=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied

=head2 Types:

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
