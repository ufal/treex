package Treex::Block::HamleDT::Test::Statistical::ExtractTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use open qw( :std :utf8 );

sub process_anode {
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun || $node->conll_deprel || '';
    return if ($afun eq 'AuxC' or $afun eq 'AuxP' or $afun eq 'Coord' or $afun eq 'Apos');
    if ($node->get_echildren != 0) {
        my $string = tree2string( $node );
        # print STDERR $string . "\n";
        my $pomoc = $string;
        my $words;
        while ($pomoc =~ s/@([^ ]+)//) {
            $words .= " $1";
        }
        $pomoc = $string;
        my $tags;
        while ($pomoc =~ s/\=(\S+)@//) {
            $tags .= " $1";
        }
        my $ords;
        while ($pomoc =~ s/#(\d+) //) {
            $ords .= " $1";
        }
        my $tree = $string;
        $tree  =~ s/^[^=]+//;
        $words =~ s/^ +//;
        $tags  =~ s/^ +//;
	my $language = $node->get_zone()->language();
        print "$language\t$words\t$tree\t$tags\n";
    }
}

sub tree2string {
    my $node = shift;

    # list
    if ($node->children == 0) {
        return ($node->afun() || $node->conll_deprel)."=".($node->get_iset('pos') || $node->conll_pos || 'X')."@".($node->form() || '')."#".$node->ord();
    }

    # non-list
    else {
        my $string = ($node->afun() || $node->conll_deprel)."=".($node->get_iset('pos') || $node->conll_pos || 'X')."@".($node->form() || '')."#".$node->ord()." [ ".(join " ", map {tree2string($_)} $node->get_echildren( {dive=>'AuxCP', ordered=>1, or_topological=>1 } ) )." ]";
        return $string;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Extract Trees

=head1 DESCRIPTION

Prints a string representation of a subtree (wordforms, structure, tags, and word order, separated by tabs) to the standard output.
Uses afuns and Interset POS if available (presumably for the harmonized version), otherwise ConLL deprel and POS.

=head1 AUTHOR

Zdeněk Žabokrtský, Jan Mašek <{zabokrtsky,masek}@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
