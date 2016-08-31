package Treex::Block::T2A::EU::FixOrder;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

#### TODO: Exceptions
my $MAX_SUBTREE = 3;


sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->formeme =~ /^v:/) {

    	if (($tnode->gram_verbmod || "") ne "imp") {
    	    my ($object) = grep { $_->formeme =~ /:(\[abs\]\+X|obj)$/ } $tnode->get_children({following_only=>1});
    	    my $child = $tnode->get_children({following_only=>1, first_only=>1});

    	    $child->shift_before_node($tnode) if (defined $child && scalar ($child->get_descendants()) <= $MAX_SUBTREE);
    	    $object->shift_before_node($tnode) if (defined $object && scalar ($object->get_descendants()) <= $MAX_SUBTREE);
#    	    $child->shift_before_node($tnode) if (defined $child);
#    	    $object->shift_before_node($tnode) if (defined $object);
    	}
    	else {
    	    # my ($object) = grep { $_->formeme =~ /:(\[abs\]\+X|obj)$/ } $tnode->get_children({preceding_only=>1});

    	    # $object->shift_after_node($tnode) if (defined $object);
    	    my @object = grep { $_->formeme =~ /:(\[abs\]\+X|obj)$/ } $tnode->get_children({preceding_only=>1});

    	    $object[-1]->shift_after_node($tnode) if ($#object >= 0 && scalar ($object[-1]->get_descendants()) <= $MAX_SUBTREE);
    	}
    }
    
    if (( $tnode->functor || "" ) !~ /^(CONJ|COORD)$/
    	and ( $tnode->formeme || "" ) =~ /^n:/
	and ( $tnode->t_lemma || "" ) =~ /^[a-z_\-]*$/i) {

    	my @attributes = grep {$_->formeme =~ /^(n|adj):attr/} $tnode->get_children({ ordered => 1 });
    	my $last_attr = $tnode;
    	$last_attr = $attributes[-1] if (defined $attributes[-1] && $tnode->precedes($attributes[-1]));

    	foreach my $a (@attributes) {
    	    #log_info("FixOrder (0): f=".$a->formeme." s=".$a->gram_sempos);

    	    if (($a->formeme || "" ) =~ /^n:attr$/ and
    	    	($a->gram_sempos || "") =~ /^n.denot$/ and
    	    	$tnode->precedes($a) && $a->is_leaf()) {
		
    	    	#log_info("FixOrder (1): ".$a->id. " before " .$tnode->id);
     	    	$a->shift_before_node($tnode);
    	    	$last_attr = $tnode if ($last_attr->precedes($tnode));

    	    	# #log_info("FixOrder (1): ".$a->id. " after " .$last_attr->id);
    	    	# $a->shift_after_node($last_attr);
    	    	# $last_attr = $a;
    	    }

    	    if (($a->formeme || "" ) =~ /^adj:attr$/ and
    		($a->gram_sempos || "") =~ /^adj.denot$/ and
    		$a->precedes($tnode) and $a->t_lemma !~ /ko$/) {
		
    		#log_info("FixOrder (1): ".$a->id. " after " .$tnode->id);
    		$a->shift_after_node($tnode);
    		$last_attr = $a if ($last_attr->precedes($a));

    		# log_info("FixOrder (1): ".$a->id. " after " .$last_attr->id);
    		# $a->shift_after_node($last_attr);
    		# $last_attr = $a;
    	    }
	    
    	    if (($a->formeme || "" ) =~ /^(n|adj):attr$/ and
    		($a->gram_sempos || "") =~ /^n.pron.indef$/ and
    		$a->precedes($tnode)) {
    		#log_info("FixOrder (2): ".$a->id. " after " .$last_attr->id);
		
    		$a->shift_after_node($last_attr);
    		$last_attr = $a;
    	    }
    	}

    	@attributes = grep {$_->formeme =~ /^(n|adj):attr/} $tnode->get_children({ ordered => 1 });
    	my $first_attr = $tnode;
    	$first_attr = $attributes[0] if (defined $attributes[0] && $attributes[0]->precedes($tnode));

    	my @phrase_heads = grep {$_->formeme =~ /^(n|adj):\[[a-z]*\]/ && $_->t_lemma =~ /^[a-z_\-]*$/i} $tnode->get_children({ ordered => 1 });
    	foreach my $a (@phrase_heads) {
    	    #log_info("FixOrder (3): ".$a->id. " before " .$first_attr->id);
    	    $a->shift_before_node($first_attr) if ($first_attr->precedes($a));
    	}
    }
    
    if ($tnode->t_lemma eq "ez") {
 	my ($child) = grep {$_->t_lemma eq "jadanik"} $tnode->get_children({following_only => 1});
	
 	$child->shift_before_node($tnode) if ($child);
    }   
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EU::FixOrder

=head1 DESCRIPTION



=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA Group, University of the Basque Country (UPV/EHU)
