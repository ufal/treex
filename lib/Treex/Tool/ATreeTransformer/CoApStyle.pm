package Treex::Tool::ATreeTransformer::CoApStyle;

use Moose;
use Treex::Core::Log;
use Moose::Util::TypeConstraints;

extends 'Treex::Tool::ATreeTransformer::BaseTransformer';

enum 'AFUN', [qw( Coord Apos )];
has afun => (
    is => 'rw',

    #    isa => 'OLD_ROOT', # doesn't work, weird
    required      => 1,
    documentation => 'to be applied on structures rooted by either Coord or Apos nodes',
);

enum 'NEW_SHAPE', [qw( chain tree )];
has new_shape => (
    is => 'rw',

    #    isa => 'NEW_SHAPE',
    required      => 1,
    documentation => 'new shape of the co/ap structure',
);

enum 'NEW_ROOT', [qw( first last )];
has new_root => (
    is => 'rw',

    #    isa => 'NEW_ROOT',
    required      => 1,
    documentation => 'which member (first/last) should be the new root of the co/ap structure',
);

sub apply_on_tree {
    my ( $self, $root ) = @_;
    $self->apply_on_subtree($root);
}

sub apply_on_subtree {
    my ( $self, $old_root ) = @_;

    foreach my $child ( $old_root->get_children ) {
        $self->apply_on_subtree($child);
    }

    if ( $old_root->afun and $old_root->afun eq $self->afun ) {    # either Coord or Apos

        my @nodes = $old_root->get_children( { add_self => 1, ordered => 1 } );

        if ( $self->new_root eq 'last' ) {
            @nodes = reverse @nodes;
        }

        # (1) choose the new root and rehang all the rest below it (just to avoid cycles)
        my @members = grep { $_->is_member and $_ ne $old_root } @nodes;
        my $new_root = $members[0];
        if ( not $new_root ) {
            log_warn 'No member in a co/ap construction';
            return;
        }
        $self->rehang( $new_root, $old_root->get_parent );
        foreach my $node ( grep { $_ ne $new_root } @nodes ) {
            $self->rehang( $node, $new_root );
        }

        # (2) rehanging all non-members and the old root below the nearest
        # following member (or below the last member, for those behind the last member)

        my @nonmembers_to_rehang;
        foreach my $node (@nodes) {
            if ( $node->is_member ) {
                foreach my $nonmember (@nonmembers_to_rehang) {

                    #                    print $nonmember->form."\t".$node->form."\n";
                    $self->rehang( $nonmember, $node );
                }
                @nonmembers_to_rehang = ();
            }
            else {
                push @nonmembers_to_rehang, $node;
            }
        }

        foreach my $nonmember (@nonmembers_to_rehang) {
            $self->rehang( $nonmember, $members[-1] );
        }

        # (3) rehang the remaining coordination members

        foreach my $member_index ( 1 .. $#members ) {
            if ( $self->new_shape eq 'tree' ) {
                $self->rehang( $members[$member_index], $new_root );
            }
            else {
                $self->rehang( $members[$member_index], $members[ $member_index - 1 ] );
            }
        }

        # TODO: changing is_member and afuns
    }
}

1;
