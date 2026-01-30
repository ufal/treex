package Treex::Tool::UMR::RelationSetter;

use Moose::Role;

sub set_relation {
    my ($self, $unode, $relation, $tnode) = @_;
    warn("NO UNODE: $relation $tnode->{id}"), return unless $unode;
    if ($unode->functor
        && $unode->functor !~ /^!!/
        && $unode->functor ne $tnode->functor
    ) {
        warn "CHANGING FUNCTOR $unode->{functor} TO $relation: $tnode->{id}.$tnode->{functor}";
    }
    return if ($unode->functor // "") =~ /[[:lower:]]/ && $relation =~ /^!!/;

    $unode->set_functor($relation);
    return
}

__PACKAGE__
