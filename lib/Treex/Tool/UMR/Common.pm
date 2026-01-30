package Treex::Tool::UMR::Common;

=head1 NAME

 Treex::Tool::UMR::Common

=head1 DESCRIPTION

Common functions for various UMR processing packages.

=head1 FUNCTIONS

=over 4

=item is_coord

Returns true for coordination concepts.

=item expand_coord

Recursively expands a coordination node. For a non-coordination node,
it returns the node.

=back

=cut

use warnings;
use strict;

use Exporter qw{ import };
our @EXPORT_OK = qw{ is_coord expand_coord entity2person is_possesive };

sub is_coord {
    my ($unode) = @_;
    return $unode->concept =~ /^(?:(?:but|contrast|have-cause)-91
                                   |and|contra|consecutive
                                   |exclusive-disjunctive|interval)$/x
            ? 1 : 0
}

sub expand_coord {
    my ($unode) = @_;
    return $unode unless is_coord($unode);

    my $expansion_re = $unode->concept =~ /-91$/ ? qr/^ARG[1-9]/ : qr/^op[1-9]/;
    my @expansion = map expand_coord($_),
                    grep $_->functor =~ /$expansion_re/,
                    $unode->children;
    return @expansion
}

sub entity2person {
    my ($unode) = @_;
    $unode->set_concept('person')
        if 'entity' eq ($unode->concept // "")
        && ($unode->entity_refperson // "") =~ /^(?:1st|2nd)/;
    return
}

sub is_possesive {
    my ($tnode) = @_;
    my $alex = $tnode->get_lex_anode or return;
    return $alex->tag =~ /^(?:AU|P[S19])/
}

__PACKAGE__
