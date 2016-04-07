#transform Universal Dependencies into Manatee format
#Printing the following information: 
#form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant
package Treex::Block::Write::ManateeU;

use strict;
use warnings;
use Moose;
use Lingua::Interset qw(encode);
use Treex::Core::Common;
use Data::Dumper;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language'                        => ( required => 1 );
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'afun' );
has 'pos_attribute'                    => ( is       => 'rw', isa => 'Str', default => 'tag' );
has 'is_member_within_afun'            => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_shared_modifier_within_afun'   => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_coord_conjunction_within_afun' => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );

has '+extension' => ( default => '.vert' );

sub process_atree {
    my ( $self, $atree ) = @_;

    # if only random sentences are printed
    return if rand() > $self->randomly_select_sentences_ratio;
	
    foreach my $anode ( $atree->get_descendants( { ordered => 1 } ) ) {
        my ( $lemma, $pos) =
            map { $self->get_attribute( $anode, $_ ) }
            (qw(lemma pos));        
        
        my $deprel = $anode->deprel();
        my $ufeatures = join('|', $anode->iset()->get_ufeatures()); 
        my $ord = $anode->ord();
        my $p_ord = $anode->get_parent->ord;
        my $left_right = $self->set_position( $anode );
        my $nearest = $self->set_immediate($anode);
        my $distance = $self->calc_distance($anode);
        my $p_form = $anode->get_parent->form;
        my $p_lemma =  $anode->get_parent->lemma;
        my $p_pos = $anode->get_parent->tag;#TODO set tag for parent of root to 'root'
        my $p_ufeatures = join('|', $anode->get_parent->iset()->get_ufeatures());
        my $p_afun = $anode->get_parent->deprel();

        # Make sure that values are not empty and that they do not contain spaces.
        my @values = ($anode->form, $lemma, $pos, $ufeatures, $deprel, $p_form, $p_lemma, $p_pos, $p_ufeatures, $p_afun,$distance);
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        print { $self->_file_handle } join( "\t", @values ) . "\n";
    }
    return;
}

#calculate distance from parent - UCNK style
sub calc_distance{
    my ($self, $anode) = @_;
    my $dist;
     if ( $anode->get_parent->ord == "0" ){
        $dist = '0';
     } else{
        $dist = $anode->get_parent->ord - $anode->ord;
        if ($dist > 0){
                $dist= '+'.$dist;
        }
     }
        return $dist;
}

#checks if parent stands immediately before/after or 
sub set_immediate{
    my ($self, $anode) = @_;
    if ( abs($anode->ord - $anode->get_parent->ord) == 1){
        return "immediate";
    }
    else{
        return "distant";
    }

} 

#checks if a parent is situated left from the node or right from the node
sub set_position{
    my ($self, $anode) = @_;
    if ($anode->get_parent->precedes($anode)){
        return "left";
    }
    else{
        return "right";
    }   
}

sub get_attribute {
    my ( $self, $anode, $name ) = @_;
    my $from = $self->{ $name . '_attribute' } || $name;    # TODO don't expect blessed hashref
    my $value = $anode->get_attr($from);
    return defined $value ? $value : '_';
}

# Given a node and an array of candidate siblings/parents etc., this returns the topologically closest candidate to the node.
sub _get_nearest {

    my ( $node, @nodes ) = @_;

    if ( @nodes > 0 ) {

        my $nearest = $nodes[0];
        foreach my $cand (@nodes) {
            $nearest = $cand if ( abs( $cand->ord - $node->ord ) < abs( $nearest->ord - $node->ord ) );
        }
        return ($nearest);
    }
    return ();
}


#override 'print_header' => sub {
#        my ($self, $document) = @_;
#    print { $self->_file_handle } "<doc>\n";
#};

override 'process_bundle' => sub {
	my ($self, $bundle) = @_;	
	my $position = $bundle->get_position()+1;
    print { $self->_file_handle } "<s id=\"" . $position . "\">\n";
    $self->SUPER::process_bundle($bundle);    
    print { $self->_file_handle } "</s>\n";
};

override 'print_header' => sub {
	my ($self, $document) = @_;	
    print { $self->_file_handle } "<doc id=\"" . $document->file_stem . "\">\n";         
};

override 'print_footer' => sub {
	my ($self, $document) = @_;	
    print { $self->_file_handle } "</doc>\n";    
};

1;

__END__

=encoding utf8
=head1 NAME

Treex::Block::Write::Manatee

=head1 DESCRIPTION

Document writer for Manatee format, file with the following structure:

	<doc id="abc">
	<s id="1">
        form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant distance_from_parent
        form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant distance_from_parent
	...
	</s>
	<s id="2">
        form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant distance_from_parent
        form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant distance_from_parent
	...
	</s>
	...
	</doc>

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=item deprel_attribute

The name of attribute which will be printed into the 4th column (dependency relation).
Default is C<afun>.

=item pos_attribute

The name of attribute which will be printed into the 3rd column (part-of-speech tag).
Default is C<tag>.

=back

=head1 AUTHOR

David Mareček, Daniel Zeman, Martin Popel, Ondřej Dušek, Michal Josífko, Natalia Klyueva

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
