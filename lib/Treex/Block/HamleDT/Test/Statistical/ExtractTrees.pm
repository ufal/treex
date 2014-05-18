package Treex::Block::HamleDT::Test::Statistical::ExtractTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'type' => ( is => 'rw', isa => 'Str', default => '' );

use open qw( :std :utf8 );

sub process_anode {
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun || $node->conll_deprel || '';
    return if ($afun eq 'AuxC' or $afun eq 'AuxP' or $afun eq 'Coord' or $afun eq 'Apos');
    if ($node->get_echildren != 0) {
        my $type = $self->type;
        my $string = tree2string( $node, $type );
        $node->get_address() =~ m/(^.*)##/;
        my $file = $1;
        my $pomoc = $string;
        my $words;
        while ($pomoc =~ s/\|([^ \$]+)//) {
            $words .= " $1";
        }
        $pomoc = $string;
        my $afuns;
        while ($pomoc =~ s/(\S+)=/=/) {
            $afuns .= " $1";
        }
        $afuns =~ s/^\s+\S+/_/; # the afun of the root is irrelevant
        my $tags;
        while ($pomoc =~ s/=(\S+)\|//) {
            $tags .= " $1";
        }
        my $ords;
        while ($pomoc =~ s/~(\d+)\$/\$/) {
            $ords .= " $1";
        }
        my $ids;
        while ($pomoc =~ s/\$(\S+)//) {
            $ids .= " $1";
        }
        my $tree = $string;
        $tree =~ s/~\d+\$\S+//g;
        $tree  =~ s/^[^=]+//;
        $words =~ s/^ +//;
        $tags  =~ s/^ +//;
	my $language = $node->get_zone()->language();
        print join("\t", ($language, $words, $tree, $tags, $afuns, $file, $ids)), "\n";
    }
}

sub tree2string {
    my $node = shift;
    my $type = shift;

    # list
    if ($node->children == 0) {
        return (($type eq 'pdt' ? $node->afun() : $node->conll_deprel) || '')
                . '=' . (($type eq 'pdt' ? $node->get_iset('pos') : $node->conll_cpos) || 'X')
                . '|' . ($node->form() || '')
                . '~' . $node->ord()
                . '$' . $node->get_attr('id');
    }

    # non-list
    else {
        my $string = (($type eq 'pdt' ? $node->afun() : $node->conll_deprel) || '')
                      . '=' . (($type eq 'pdt' ? $node->get_iset('pos') : $node->conll_cpos) || 'X')
                      . '|' . ($node->form() || '')
                      . '~' . $node->ord()
                      . '$' . $node->get_attr('id')
                      . ' [ ' . (join ' ', map {tree2string($_, $type)} $node->get_children( {ordered=>1} ) ) . ' ]';
        return $string;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Test::Statistical::Extract Trees

=head1 DESCRIPTION

Prints a string representation of a subtree (wordforms, structure, tags, word order, filename, and node IDs, separated by tabs) to the standard output.
Depending on the value of the parameter 'type' (either 'pdt' or 'orig'), uses either afuns and Interset POS, or ConLL deprel and POS.

=head1 AUTHOR

Zdeněk Žabokrtský, Jan Mašek <{zabokrtsky,masek}@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
