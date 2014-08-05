package Treex::Block::W2A::JA::RehangAuxVerbs;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;
    
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }
    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    return 0 if ( $tag !~ /^Dōshi/ );

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # check, if our verb is dependent on a non-independent verb (non-pure auxiliary, e.g. "iru", "aru") or suffix-verb (pure auxiliary, e.g. "rareru", "saseru")
    # NOTE: pure auxiliaries, which are marked as Jodoshi (e.g. "masu") are parsed correctly in the parser block, so we do not fix them
    return 0 if ($parent->tag !~ /-HiJiritsu/ && $parent->tag !~ /-Setsubi/);

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    # we must also rehang other nodes which shouldnt be dependent on the
    # non-independent verb
    foreach my $child ($parent->get_children()) {
      # we don't want to rehang aux verbs
      $child->set_parent($a_node) if ($child->tag !~ /Jodōshi/);
    }

}

1;

__END__

=pod

=item Treex::Block::W2A::JA::RehangAuxVerbs

=head1 DESCRIPTION

Verbs (Dōshi) with tag Dōshi-HiJiritsu (non-independent) should be
dependent on independent verbs (tag Dōshi-Jiritsu) and "suffix" verbs (tag Dōshi-Setsubi) and not vice versa.
This block takes care of that.

---

Suggested order of applying Rehang* blocks:
W2A::JA::RehangAuxVerbsōshi
W2A::JA::RehangCopulas
W2A::JA::RehangParticles

=cut

# Author: Dusan Varis
