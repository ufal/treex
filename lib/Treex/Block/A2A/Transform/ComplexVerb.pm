package Treex::Block::A2A::Transform::ComplexVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

#TODO orig first last first_aux last_aux main
#has head => (
#    is            => 'ro',
#    default       => 'first_aux',
#    documentation => 'which verb should govern the whole complex verb structure',
#);

has projective => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'try to not introduce non-projectivities',
);

#TODO orig agreement
#has on_main => (
#    is => 'ro',
#    default => 'orig',
#    documentation => 'what should be the children of the main verb (the rest will depend on the auxiliary verbs)',
#);

sub process_atree {
    my ( $self, $atree ) = @_;
    $self->process_subtree($atree);
}

sub process_subtree {
    my ( $self, $node ) = @_;
    my @children = $node->get_children();

    if ( $self->is_verb($node) ) {
        my @verbs = grep { $self->is_verb($_) } @children;        
        if ( !$self->is_aux_verb($node) && @verbs ) {
            my $main = $node;
            my @aux_verbs = grep { $self->is_aux_verb($_) } @verbs;
            if (@aux_verbs) {
                my ($aux, @rest_aux) = @aux_verbs;
                $self->rehang($aux, $node->get_parent());
                $self->rehang($node, $aux);
                if ($self->projective){
                    if ($aux->precedes($node)){
                        for my $d (grep {$_->precedes($aux)} @children){
                            $self->rehang($d, $aux);
                        }
                    } else {
                        for my $d (grep {$aux->precedes($_)} @children){
                            $self->rehang($d, $aux);
                        }
                    }
                }
                @children = $aux->get_children();
            }
        }
    }

    foreach my $child (@children) {
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
    return $node->get_iset('pos') eq 'verb' || ( $node->tag || '' ) =~ /^V/;
}

sub is_aux_verb {
    my ( $self, $node ) = @_;
    return $node->get_iset('subpos') eq 'aux' || ( $node->afun || '' ) eq 'AuxV';
}

sub has_morp {
    my ( $self, $node ) = @_;
    return $node->get_iset('gender') || $node->get_iset('number') || $node->get_iset('person');
}

1;

=over

=item Treex::Block::A2A::Transform::ComplexVerb

AuxV-as-head, try to not introduce non-projectivities

TODO:
Trying to not breaking morphological agreement while restructuring complex verb forms.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

