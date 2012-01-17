package Treex::Block::T2T::AssignWordnetHyperchain;
use Moose;                                                                                                                                                   
use Treex::Core::Common;                                                                                                                                     
extends 'Treex::Core::Block';                                                                                                                                

use Treex::Tool::Wordnet::SimpleQuery;

my $DEBUG = 0;

has '_wordnet' => ( isa => 'Object', is => 'rw' );

has '+language' => ( required => 1 );

has 'wn_file' => ( isa => 'Str', is => 'ro', default => 'simple-wn-2.1.sqlite' ); 

sub BUILD {
	my ($self) = @_;
	$self->_set_wordnet( Treex::Tool::Wordnet::SimpleQuery->new( { language => $self->language, 
		wn_file => $self->wn_file } ) );
	return;
}


sub process_tnode {
	my ($self, $tnode) = @_;


	# just on nouns, right now
	if (defined $tnode->gram_sempos and $tnode->get_attr('t_lemma') !~ /^#/) {

		my $pos = undef;

		if ($tnode->gram_sempos eq 'n.denot') {
			$pos = 'n';
		}
# 		elsif ($tnode->gram_sempos eq 'adj.denot') {
# 			$pos = 'a';
# 		}
		elsif ($tnode->gram_sempos eq 'v') {
			$pos = 'v';
		}
# 		elsif ($tnode->gram_sempos =~ /^adv/) {
# 			$pos = 'b'; # adverbial
# 		}

		if (defined $pos) {
			my $literal = $tnode->get_attr('t_lemma') . '-' . $pos;

			my $hyperchain = $tnode->get_attr('wn/hyperchain');

			# always rewrite, so block can be used to correct previous values
	# 		my $literal = $tnode->get_attr('t_lemma') . '-' . 'n';
			my @result = $self->_wordnet->find_by_literal($literal);
			
			# adding spaces for better readability of query regexes
			$hyperchain = join(" | ", map { $_->{'hyperchain'} } @result); 
			log_debug("$literal -> $hyperchain");
# 			print "$literal -> $hyperchain\n";
			$tnode->set_attr('wn/hyperchain', " $hyperchain ") if $hyperchain;
# 			}
		}
	}
}

1;

__END__

=head1 NAME

Treex::Block::T2T::AssignWordnetHyperchain

=head1 VERSION

0.1

=head1 SYNOPSIS


=head1 DESCRIPTION

add a list of hyperonyms to noun nodes 

=head1 AUTHORS

Jan Ptáček

Lenka Smejkalova

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
