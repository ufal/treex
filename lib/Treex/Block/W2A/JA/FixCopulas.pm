package Treex::Block::W2A::JA::FixCopulas;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;
    my $lemma = $a_node->lemma;
    
    # we change lemma of "じゃ" and "では" based on auxiliary verbs dependent on them
    if ( $lemma eq "じゃ" || $lemma eq "では" ) {
        foreach my $child ( $a_node->get_children() ) {
            
            # should be modified differently

            # $a_node->lemma = "だ" if $child->lemma eq "ない" ;
            # $a_node->lemma = "です" if $child->lemma eq "ん";
        }
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::JA::FixCopulas

=head1 DECRIPTION

Changes lemma for copulas in negative form. Negative aspect of copula should be kept in separate negative particle.

=head1 AUTHORS

Dusan Varis
