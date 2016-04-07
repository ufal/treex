package Treex::Block::Write::Manatee;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Data::Dumper;
use Treex::Block::A2T::SetDocOrds;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language'                        => ( required => 1 );
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'afun' );
has 'pos_attribute'                    => ( is       => 'rw', isa => 'Str', default => 'tag' );
has 'is_member_within_afun'            => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_shared_modifier_within_afun'   => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_coord_conjunction_within_afun' => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'morphology' => ( is       => 'ro', isa => 'Bool', default => 0 );
has 'analytical' => ( is       => 'ro', isa => 'Bool', default => 0 );
has 'tectogrammatical' => ( is       => 'ro', isa => 'Bool', default => 0 );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );
has 'get_bundle' => ( is       => 'rw', isa => 'Bool', default => 0 );
has '+extension' => ( default => '.vert' );

#Printing the following information for analytical layer: Write::Manatee analytical=1 
#form lemma pos ufeatures deprel parent_form parent_lemma parent_pos parent_ufeatures parent_deprel left/right immediate/distant distance
#(the last three attributes determine the distance of a node from its parent)
#For tectogrammatical, there are more attributes - see @values


sub process_atree {
    my ( $self, $atree ) = @_;

    # if only random sentences are printed
    return if rand() > $self->randomly_select_sentences_ratio;
	
    foreach my $anode ( $atree->get_descendants( { ordered => 1 } ) ) {
        my ( $lemma, $pos, $deprel ) =
            map { $self->get_attribute( $anode, $_ ) }
            (qw(lemma pos deprel));        
    		# convert lemma to the basic form
		my $truncated_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 );
       my $tnode;
       my $a_type; # HOW TO NAME IT MEANINGFULLY???  
       if ( $anode->get_referencing_nodes("a/lex.rf") ){

                ($tnode) = $anode->get_referencing_nodes("a/lex.rf");
                $a_type = 'lex';
        }
       elsif ( $anode->get_referencing_nodes("a/aux.rf")  ){
                ($tnode) = $anode->get_referencing_nodes("a/aux.rf");
                $a_type = 'aux';
       }
        else {
              #  $tnode = '_';
                $a_type = 'null';
        }
	
        #my ($tnode) = $anode->get_referencing_nodes("a/lex.rf"); #two nodes: in case of ellipsis, this choose the first one
        # print $anode->lemma, " ", ($tnode ? $tnode->t_lemma : "--"), "\n"	
        # append suffices to afuns
        my $suffix = '';
        $suffix .= 'M' if $self->is_member_within_afun            && $anode->is_member;
        $suffix .= 'S' if $self->is_shared_modifier_within_afun   && $anode->is_shared_modifier;
        $suffix .= 'C' if $self->is_coord_conjunction_within_afun && $anode->wild->{is_coord_conjunction};
        $deprel .= "_$suffix" if $suffix;
        my ($eparent) = $anode->get_eparents({or_topological=>1});
        my $ep_form = $eparent->form;
        my $ep_tag = $eparent->tag;
        my $ep_afun = $eparent->afun;
        my $e_parent_full_lemma = $eparent->lemma;
        my $ep_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $e_parent_full_lemma, 1 );    
        my $p_ord = $anode->get_parent->ord;
        my $p_form = $anode->get_parent->form;
        my $p_full_lemma = $anode->get_parent->lemma;
        my $p_lemma =  Treex::Tool::Lexicon::CS::truncate_lemma( $p_full_lemma, 1 );#TODO if parent is a root
        my $p_pos = $anode->get_parent->tag;#TODO set tag for parent of root to 'root'
        my $p_afun = $anode->get_parent->afun;
        my $left_right = $self->set_position( $anode );
        my $nearest = $self->set_immediate($anode);
        my $distance = $self->calc_distance($anode);
        my $ep_distance = $self->calc_ep_distance($anode,$eparent);        

        # Make sure that values are not empty and that they do not contain spaces.
        
        my $clause_number = $anode->clause_number;
        
        my ($functor, $t_lemma, $tfa, $deepord, $sempos, $grammatemes_rf, $coref_special, $antes, $val_frame, $discourse_special, $discourse_type, $mwes, $disc_target);
        #################t-layer################
       # foreach my $t_attr(qw(functor, t_lemma, tfa, deepord, sempos)){
        if (defined $tnode) { 
        # no strict 'refs'; 
        #$$t_attr = $tnode->get_attr($t_attr); #'DEFINED_ANODE_FUNCTOR';
                $t_lemma = $tnode->t_lemma;
                $tfa = $tnode->tfa;
                $deepord = $tnode->ord;
                $sempos = $tnode->gram_sempos;
                $coref_special = $tnode->get_attr('coref_special');
                $discourse_special = $tnode->get_attr('discourse_special');
                $discourse_type = $tnode->get_attr('discourse_type');

               my $disc = $tnode->get_attr('discourse');
               if ($disc){
                                                
                        ($discourse_type) = map { $_->{discourse_type} } @$disc ;
                        my ($disc_target_node) = map { $tnode->get_document->get_node_by_id( $_->{'target_node.rf'} ) } @$disc;
                        my $a_target = $disc_target_node->get_lex_anode();
                        my ( $d_form, $d1_lemma, $d_pos, $d_deprel ) =
                        map { $self->get_attribute( $a_target, $_ ) } (qw(form lemma pos deprel));
                        my $d_lemma=Treex::Tool::Lexicon::CS::truncate_lemma( $d1_lemma, 1 );
                        $disc_target = 'form='.$d_form.'|lemma='.$d_lemma."|tag=".$d_pos."|afun=". $d_deprel . '|functor='. $disc_target_node->functor;

                        my @disc_connector = map { $tnode->get_document->get_node_by_id( $_->{'t_connectors.rf'} ) } @$disc;

                } else { $discourse_type = '_DISCOURSE_TYPE'; $disc_target = '_DISC_TARGET'; }


                my $grammatemes = $tnode->get_attr('gram');
                my @grammateme_pairs = ();
                while ( my ( $name, $value ) = each %{$grammatemes} ) {
                        push @grammateme_pairs, $name . '=' . $value;
                }
        
                $grammatemes_rf=join('|', @grammateme_pairs);
                my ($t_antes) = $tnode->get_coref_text_nodes(); # also, get_coref_gram_nodes
                if ($t_antes){
                        $antes = 'tlemma='. $t_antes->t_lemma . '|functor=' . $t_antes->functor;  
                }
                else{
                        $antes = '_ANTES';
                } 
        }
        else{
        #        no strict 'refs';
               # $$t_attr = '_';
                $functor = '_FUNCTOR';
                $t_lemma = '_TLEMMA';
                $sempos ='_SEMPOS';
                $deepord = '_DEEPORD';
                $grammatemes_rf = '_GRMMATEMES';
                $coref_special = '_COREFSPECIAL';
                $antes = '_ANTES';
                $discourse_special ='_DISCOURSE';
                $discourse_type = '_DISCTYPE';
                $disc_target = '_DISCTARGET';
        }
       # }
        my @values;
        

        if ($self->morphology){
                 @values = ($anode->form, $truncated_lemma, $pos);
        }
        elsif ($self->analytical){
                
                @values = ($anode->form, $truncated_lemma, $pos, $deprel, $distance, $p_form, $p_lemma, $p_pos, $p_afun, $ep_distance, $ep_form, $ep_lemma, $ep_tag, $ep_afun); 
        }
        else{
                @values = ($anode->form, $truncated_lemma, $pos, $anode->ord, $clause_number, $anode->is_member, $deprel, $a_type, $deepord, $t_lemma, $functor, $tfa, $sempos, $grammatemes_rf, $coref_special, $antes, $discourse_special, $discourse_type, $disc_target, $p_form, $p_lemma, $p_pos, $p_afun, $ep_form, $ep_lemma, $ep_tag, $ep_afun);
        }
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

sub get_attribute {
    my ( $self, $anode, $name ) = @_;
    my $from = $self->{ $name . '_attribute' } || $name;    # TODO don't expect blessed hashref
    my $value = $anode->get_attr($from);
    return defined $value ? $value : '_';
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


#calculate distance from parent - UCNK style
sub calc_ep_distance{
    my ($self, $anode ,$eparent) = @_;
    my $dist;
     if ( $eparent->ord == "0" ){
        $dist = '0';
     } else{
        $dist = $eparent->ord - $anode->ord;
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


#override 'print_header' => sub {
#        my ($self, $document) = @_;
#    print { $self->_file_handle } "<doc>\n";
#};

override 'process_bundle' => sub {
	my ($self, $bundle) = @_;	
	my $position = $bundle->id; #$bundle->get_position()+1;
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
	token lemma POS-tag afun
	token lemma POS-tag afun
	...
	</s>
	<s id="2">
	token lemma POS-tag afun
	token lemma POS-tag afun
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

David Mareček, Daniel Zeman, Martin Popel, Ondřej Dušek, Michal Josífko

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
