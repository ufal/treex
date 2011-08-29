package Treex::Block::A2A::Transform::AllPunctBelowTechRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

# orig first last first_aux last_aux main
has head => (
    is => 'ro',
    default => 'orig',
    documentation => 'which verb should govern the whole complex verb structure',
);

# orig agreement
has on_main => (
    is => 'ro',
    default => 'orig',
    documentation => 'what should be the children of the main verb (the rest will depend on the auxiliary verbs)',
);


sub process_atree {
    my ( $self, $atree ) = @_;
    $self->process_subtree($atree);
}

sub process_subtree {
    my ( $self, $node ) = @_;
    my @children = $node->get_children();

    if ($self->is_verb($node)) {
        my @verbs = grep {$self->is_verb($_)} @children;
        my $main;
        if ($self->is_aux_verb($node)) {
            ($main) = grep {!$self->is_aux_verb($_)} @verbs;
        } else {
            $main = $node;
        }
    }

    foreach my $child ( @children ) {
        $self->process_subtree($child);
    }
    return;
}



sub find_verb_group {
    my ( $self, $node ) = @_;
    return if !$self->is_verb($node);
       
}

sub is_verb {
    my ( $self, $node ) = @_;
    return ($node->iset->{pos}||'') eq 'verb' || ($node->tag||'') =~ /^V/;
}

sub is_aux_verb {
    my ( $self, $node ) = @_;
    return ($node->afun||'') eq 'AuxV';
}

sub has_morp {
    my ( $self, $node ) = @_;
    return $node->iset->{gender} || $node->iset->{number} || $node->iset->{person};
}

1;

=over

=item Treex::Block::A2A::Transform::ComplexVerb

Trying to not breaking morphological agreement while restructuring complex verb forms.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

