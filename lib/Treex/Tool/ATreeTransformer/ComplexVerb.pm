package Treex::Tool::ATreeTransformer::ComplexVerb;

use Moose;
use Treex::Core::Log;
use Moose::Util::TypeConstraints;

extends 'Treex::Tool::ATreeTransformer::BaseTransformer';


enum 'NEW_ROOT', [qw( first last )];
# in the future, root selection might be based also on other
# indicators, not only on position
has new_root => (
    is => 'rw',
#    isa => 'NEW_ROOT',
    required => 1,
    documentation => 'which member (first/last) should be the new root of the co/ap structure',
);


sub apply_on_tree {
    my ($self, $root) = @_;


    foreach my $node (grep {1} $root->get_descendants) { # can i recognize verb universally (using interset)?

        my @verb_group = grep {$_->afun eq 'AuxV' or $_ eq $node}
            $node->get_children({ordered=>1,add_self=>1});

        if (@verb_group > 1) {

            if ($self->new_root eq 'last') {
                @verb_group = reverse @verb_group;
            }

            my $new_root = $verb_group[0];

            if ($new_root ne $node) {
                $self->rehang($new_root, $node->get_parent);
                foreach my $child (grep {$_ ne $new_root} @verb_group) {
                    $self->rehang($child,$new_root);
                    foreach my $grandchild ($child->get_children) {
                        $self->rehang($grandchild, $new_root);
                    }
                }
            }
        }
    }
}

1;
