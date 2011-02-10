package SEnglishA_to_SEnglishT::Fix_inconsistencies;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %lin_lemma2func; # {linear notation}{lemma} -> functor

#======================================================================

sub process_one_record
{
	my ($lin, $tree) = @_;
	my @stack = (); # stack of ancestors of the node in question
	my %parent; # {node's lemma} -> parent's lemma
	my %lemma2func; # {lemma} -> functor

	for my $rec (split ' ', $tree) {
		my $has_children; # whether the current node has children
		if ($rec eq ')') {
			# go one level up
			defined pop @stack or Report::fatal("Assertion failed: stack empty");
		}
		else {
			if ($rec =~ /\($/) { $has_children = chop $rec };
			$rec =~ /^([^,]+)(,([A-Z<>a-z]+))?/;
			my ($lemma, $func) = ($1, $3);
			$lemma2func{$lemma} = $func if $func;

			# create the parent link
			if (@stack) {
				$parent{ $lemma } = $stack[-1];
			}

			# overwriting the <up>-functor
			if ($func && $func eq '<up>') {
				delete $lemma2func{ $lemma };
				# find the real one
				my $up_lemma = $lemma;
				while ($func && $func eq '<up>') {
					$up_lemma = $parent{ $up_lemma };
					$func = $lemma2func{ $up_lemma };
				}
				# overwrite it (if reasonable)
				if (defined $func && $func =~ /\<([A-Z]+)\>/) {
					$lemma2func{ $lemma } = $1;
				}
			}

			if ($has_children) {
				# go one level down
				push @stack, $lemma;
			}
		}
	}
	!defined pop @stack or Report::fatal("Assertion failed: stack not empty");

	# delete functors belonging to the children
	map { $lemma2func{ $_ } =~ s/\<[A-Z]+\>// } keys %lemma2func;
	
	$lin_lemma2func{ $lin } = \%lemma2func;
}

#======================================================================

sub debug_lin_lemma2func 
{
	for my $lin (keys %lin_lemma2func) {
		print "$lin\n";
		for my $lemma (keys %{$lin_lemma2func{$lin}}) {
			print "  $lemma: ", $lin_lemma2func{$lin}{$lemma}, "\n";
		}
	}
}

#======================================================================

sub uniq { my %a; grep { !($a{$_}++) } @_ }

#======================================================================

BEGIN 
{
	my $f; # filehandle
	my $lin; # linear notation

	# read up the file with corrections
	open $f, "$ENV{TMT_ROOT}/personal/klimes/annot-new" or Report::fatal("Cannot open the file with corrections");
	while (<$f>) {
		$lin = $_ if /^[^ ]/;
		if (/^ *\* *(.*) [0-9]+$/) {
			chomp $lin;
			process_one_record($lin, $1);
		}
	}
	close $f;

	#debug_lin_lemma2func();
}

#======================================================================

sub fix
{
	my ($sent_root) = @_;

	for my $root ($sent_root->get_descendants) {		
		my $lin = join " ", map { $_->get_attr('m/lemma') } uniq sort { $a->get_ordering_value <=> $b->get_ordering_value } ($root->get_lex_anode, map { $_->get_anodes } $root->get_descendants);
		if (exists $lin_lemma2func{ $lin }) {
			print "--- \"$lin\" (", $root->get_attr('id'), ")\n";
			for my $node ($root->get_descendants({add_self=>1})) {
				my $lemma = $node->get_lex_anode? $node->get_lex_anode->get_attr('m/lemma') : '___';
				my $corr_func = $lin_lemma2func{ $lin }{ $lemma };
				if ($corr_func && $node->get_attr('functor') ne $corr_func) {
					print "  # $lemma: ", $node->get_attr('functor'), " -> $corr_func\n";
					$node->set_attr('functor', $corr_func);
				}
			}
		}
	}
}

#======================================================================

sub process_document
{
	my ( $self, $document ) = @_;

	for my $bundle ( $document->get_bundles ) {
		fix( $bundle->get_tree('SEnglishT') );
	}
}

1;

=over

=item SEnglishA_to_SEnglishT::Fix_inconsistencies

Fixes inconsistent English tectogramatical annotation using a file with manually resolved inconsistencies.

=back

=cut

# Copyright 2009 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
