package Treex::Block::A2A::CS::FixBy;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

# worsens BLEU but performs really well

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    # 'by' preposition being a head of an inflected word
    
    if (!$en_counterpart{$dep}) {
	return;
    }
    my $aligned_parent = $en_counterpart{$dep}->get_eparents({first_only=>1, or_topological => 1});

    if (
	$d->{tag} =~ /^....[1-7]/
	&& $aligned_parent
	&& $aligned_parent->form
	&& $aligned_parent->form eq 'by'
        && !$self->isName($dep)
	) {

	# there shouldn't be any other preposition aligned to 'by'
	# so delete it if there is one
	my ( $nodes, $types ) = $aligned_parent->get_aligned_nodes();
	if ( my $node_aligned_to_by = $$nodes[0]) {
	    if ($node_aligned_to_by->tag =~ /^R/) {
		$self->logfix1( $node_aligned_to_by, "By (aligned prep)" );
		$self->remove_node($node_aligned_to_by, $en_hash, 1);
		$self->logfix2(undef);
		# now have to regenerate these as they might have been invalidated
		( $dep, $gov, $d, $g ) = $self->get_pair($dep);
	    }
	}

	# treat only right children
	if ($dep->ord < $gov->ord) {
	    return;
	}
	
	# now find the correct case for this situation
	my $original_case = $d->{case};
	my $new_case = $original_case;
	if ($g->{tag} =~ /^N/) {
	    #set dependent case to genitive
	    $new_case = 2;
	} elsif ($g->{tag} =~ /^[VA]/) {
	    #set dependent case to instrumental
	    $new_case = 7;
	}

	if ($new_case != $original_case) {

	    my $original_num = $d->{num};
	    my $new_num = $original_num;

	    my $new_tag = $d->{tag};
	    $new_tag =~ s/^(....)./$1$new_case/;
            my $old_form = $dep->form;
	    my $new_form = $self->get_form( $dep->lemma, $new_tag );
	    
	    # maybe the form is correct but the number is tagged incorrcetly
	    if ( !$new_form || lc($old_form) ne lc($new_form) ) { 
		my $try_num = $self->switch_num($original_num);
		$new_tag =~ s/^(...)../$1$try_num$new_case/;
		$new_form = $self->get_form( $dep->lemma, $new_tag );
		if ( $new_form && lc($old_form) eq lc($new_form) ) { 
		    # keep form, change number in tag
		    $new_num = $try_num;
		}
	    }

	    $d->{tag} =~ s/^(...)../$1$new_num$new_case/;
	    
	    $self->logfix1( $dep, "By" );
	    $self->regenerate_node( $dep, $d->{tag} );
	    $self->logfix2($dep);
	}

    }
}

1;

=over

=item Treex::Block::A2A::CS::FixBy

The English preposition 'by' is usually translated into Czech not by a preposition
but by using a specific case (genitive or instrumental:
genitive if the parent is a noun, instrumental if the parent is
a passive verb or an adjective).

=back

=cut

# Copyright 2011 Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
