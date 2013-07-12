package Treex::Block::Eval::AtreeUAS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'eval_is_member' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'eval_is_shared_modifier' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'eval_punc' => (isa => 'Bool', is => 'ro', default => 1);
has sample_size => (
    is => 'ro',
    isa => 'Int',
    default => 0,
    documentation => 'How many sentences should be in a sample (default is 0=all)',
);
has _number_of_nodes => (is => 'rw', isa => 'Int', default => 0 );
has _same_as_ref => (is => 'rw', isa => 'HashRef', default => sub { my %h = (); return \%h } );
has _sentences_in_current_sample => (is => 'rw', isa => 'Int', default => 0);

sub process_bundle {
    my ( $self, $bundle ) = @_;

	my $ref_zone;
	my @ref_parents;
	my @ref_is_member;
	my @ref_is_shared_modifier;
	
	my @compared_zones;
	
	if ($self->eval_punc) {
    	$ref_zone = $bundle->get_zone( $self->language, $self->selector );
		@compared_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();    	
	}	
	else {
		my $ref_zone_orig = $bundle->get_zone( $self->language, $self->selector ); 
		$ref_zone = $self->clone_atree_with_no_punc($ref_zone_orig);
				
		my @compared_zones_orig = grep { ($_ ne $ref_zone_orig) && ($_ ne $ref_zone)  && $_->language eq $self->language } $bundle->get_all_zones();
		@compared_zones = map{$self->clone_atree_with_no_punc($_)}@compared_zones_orig;
	}
	
   	@ref_parents = map { $_->get_parent->ord } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
   	@ref_is_member = map { $_->is_member ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
   	@ref_is_shared_modifier = map { $_->is_shared_modifier ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );

    $self->_set_number_of_nodes($self->_number_of_nodes + @ref_parents);

    foreach my $compared_zone (@compared_zones) {
        my @parents = map { $_->get_parent->ord } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_member = map { $_->is_member ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_shared_modifier = map { $_->is_shared_modifier ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );

        if ( @parents != @ref_parents ) {
            log_fatal 'There must be the same number of nodes in compared trees';
        }
        my $label = $compared_zone->get_label;
        my $ref_label = $ref_zone->get_label;
        foreach my $i ( 0 .. $#parents ) {
            my $eqp = $parents[$i] == $ref_parents[$i];
            my $eqm = $is_member[$i] == $ref_is_member[$i];
            my $eqs = $is_shared_modifier[$i] == $ref_is_shared_modifier[$i];
            $self->_same_as_ref->{'UASp('.$label.','.$ref_label.')'}++ if($eqp);
            $self->_same_as_ref->{'UASpm('.$label.','.$ref_label.')'}++ if($eqp && $eqm);
            $self->_same_as_ref->{'UASps('.$label.','.$ref_label.')'}++ if($eqp && $eqs);
            $self->_same_as_ref->{'UASpms('.$label.','.$ref_label.')'}++ if($eqp && $eqm && $eqs);
            # Depending on block parameters, one of the above values is also "the" UAS required by the caller.
            # For the sake of compatibility, we will output it only with the label, without extras.
            if ( $eqp &&
                 ( !$self->eval_is_member || $eqm ) &&
                 ( !$self->eval_is_shared_modifier || $eqs )
               ) {
                $self->_same_as_ref->{$label}++;
            }
        }
    }

    $self->_set_sentences_in_current_sample($self->_sentences_in_current_sample + 1);
    if ($self->sample_size && $self->_sentences_in_current_sample >= $self->sample_size){
        $self->print_stats();
    }
    
    # remove cloned 'no punc' zones
    if (!$self->eval_punc) {
    	$bundle->remove_zone($ref_zone->language, $ref_zone->selector);
    	map{$bundle->remove_zone($_->language, $_->selector)}@compared_zones;
    }
    
    return;
}

sub print_stats {
    my ($self) = @_;
    foreach my $zone_label ( sort keys %{$self->_same_as_ref} ) {
        print "$zone_label\t".$self->_same_as_ref->{$zone_label}."/".$self->_number_of_nodes."\t" . ( $self->_same_as_ref->{$zone_label} / $self->_number_of_nodes ) . "\n";
        $self->_same_as_ref->{$zone_label} = 0;
    }
    $self->_set_sentences_in_current_sample(0);
    $self->_set_number_of_nodes(0);
    return;
}

sub clone_atree_with_no_punc {
	my ($self, $z) = @_;
	my $bundle = $z->get_bundle();
	my $new_selector = $z->selector . 'nopunc';
	my $no_punc_zone = $bundle->get_or_create_zone( $z->language, $new_selector);
	my $atree_orig = $bundle->get_zone( $z->language, $z->selector )->get_atree();
	my $atree_clone = $no_punc_zone->create_atree();
	$atree_orig->copy_atree($atree_clone);
	my @desc = 	$no_punc_zone->get_atree->get_descendants( { ordered => 1 } );
	foreach my $n (@desc) {
		if ($n->form =~ /^\p{IsP}$/ ) {
			my $p = $n->parent;
			if (!$n->is_leaf()) {
				my @children = $n->get_children();
				foreach my $c (@children) {
					$c->set_parent($p);
				}
			} 
			$n->remove();
		}
	}
	return $no_punc_zone;	
}

sub process_end {
    my ($self) = @_;
    if ($self->_sentences_in_current_sample){
        $self->print_stats();
    }
}

1;

=over

=item Treex::Block::Eval::AtreeUAS

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, David Marecek, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
