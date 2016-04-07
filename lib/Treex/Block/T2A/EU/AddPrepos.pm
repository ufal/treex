package Treex::Block::T2A::EU::AddPrepos;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddPrepos';

use utf8;

# In Spanish, it seems adverbs may have prepositions as well (e.g. "por allí").
has '+formeme_prep_regexp' => ( default => '^(?:n|adj|adv):(.+)[+]' );

my $CASES = "^(nom|gen|dat|acc|voc|loc|ins|abl|par|dis|ess|tra|com|abe|ine|ela|ill|add|ade|all|sub|sup|del|lat|tem|ter|abs|erg|cau|ben)\$";

override 'process_tnode' => sub {
    my ( $self, $tnode ) = @_;
    my $prep_forms_string = $self->get_prep_forms($tnode->formeme);
    my $anode = $tnode->get_lex_anode();

    my @anodes = $tnode->get_anodes({ordered=>1});

    # Skip weird t-nodes with no lex_anode and nodes with no prepositions to add
    return if (!defined $anode or !$prep_forms_string);

    # Occasionally there may be more than one preposition (e.g. na_rozdíl_od)
    my @prep_forms = split /_/, $prep_forms_string;
    my $posp_forms_string="";
    my @posp_cases;

    # There can be two types of data in prep_forms:
    #   Between brackets: Case
    #   Otherwise: Form

    # Get and store prepositions and cases
    foreach (@prep_forms){
	
	# Retrieve the form
	if (substr($_,0,1) ne "["){
	    $posp_forms_string.="_" if($posp_forms_string ne "");
	    $posp_forms_string.=$_ ;
	}
	else{ # Retrieve the case
	    my $len = length($_);
	    push(@posp_cases, substr($_, 1, $len-2)); # Remove brackets and store the case in the array
	}
    }
    
    # Store the pospositions in an array
    my @posp_forms = split /_/, $posp_forms_string;
    
    # Make the first element of the array head of the postpositions
    my $posp_head;
    if(defined($posp_forms[0])){
	$posp_head = $anode->get_parent()->create_child({lemma=>"$posp_forms[0]", form=>"$posp_forms[0]"});
	$posp_head->shift_after_subtree($anode);
    }
    
    shift(@posp_forms); # remove first element of the array

    # hang the rest of the pospositions from the head
    foreach (@posp_forms){
	my $posp_node = $posp_head->create_child({lemma=>"$_", form=> "$_"});
	$posp_node->shift_after_node($posp_head); # Give the nodes the proper order
    } 

    # Hang the anode from the posposition head
    $anode->set_parent($posp_head) if( defined($posp_head) &&  ($anode->get_parent()->id ne $posp_head->id));
    
    # Create new nodes for all prepositions.
    # Put them before $anode's subtree (in right word order)
    my @prep_nodes;
    
    my @subnodes = grep{$_->formeme =~ /^(n|adj):attr/} $tnode->get_children({ ordered => 1});
    my $nodeaux = $anodes[-1];

    if(@subnodes) {
	my @auxsubnodes = $subnodes[-1]->get_anodes({ ordered => 1});
	$nodeaux = $auxsubnodes[-1] if ($nodeaux->ord < $auxsubnodes[-1]->ord)
    }

    $nodeaux->iset->add("case" => "$posp_cases[-1]") if (defined $posp_cases[-1] && $posp_cases[-1] =~ /$CASES/);

    # Language-specific stuff to go here
    $self->postprocess($tnode, $anode, $prep_forms_string, \@prep_nodes);

    return;
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.
In Spanish, it seems adverbs may have prepositions as well (e.g. "por allí").

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
