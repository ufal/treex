package Treex::Block::W2A::ES::FixTagAndParse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::Generation::ES_Morphology;
use Treex::Tool::Lexicon::Generation::ES;
my $generator = Treex::Tool::Lexicon::Generation::ES->new();
my $imperative_iset = Lingua::Interset::FeatureStructure->new({pos=> 'verb', verbform=>'fin', number=>'sing', mood=>'imp', person=>3});

has generator2 => ( is => 'rw' );

sub BUILD {
    my $self = shift;

    return;
}

sub process_start {
    my ($self) = @_;
    $self->set_generator2( Treex::Tool::Lexicon::Generation::ES_Morphology->new() );
    return;
}

sub process_anode {
    my ($self, $anode) = @_;
    my $lemma = $anode->lemma;
    
    # == Fix dependency structutre
    if ($anode->form eq '¿'){
        my $right_mark = $anode->get_siblings({last_only=>1});
        if (!$right_mark || $right_mark->form ne '?'){
            $right_mark = first {$_->form eq '?' && $_->follows($anode)} $anode->get_root->get_descendants({ordered=>1}) or return;
            if ($anode->follows($anode->get_parent)){
                $anode->set_parent($right_mark->get_parent()) if !$right_mark->is_descendant_of($anode);;
            } else {
                $right_mark->set_parent($anode->get_parent()) if !$anode->is_descendant_of($right_mark);
            }
        }
        # TODO if ($anode->follows($anode->get_parent) or $anode->get_siblings({preceding_only=>1})){ }
    }
    
    
    # == Fix lemma
    if ($lemma eq "al" && $anode->iset->pos eq "adp") {
	$lemma = "a";
	$anode->iset->add(definiteness=>'def', prontype=>'art');
	$anode->set_form($lemma);
    }

    if ($lemma eq "del" && $anode->iset->pos eq "adp") {
	$lemma = "de";
	$anode->iset->add(definiteness=>'def', prontype=>'art');
	$anode->set_form($lemma);
    }
    $anode->set_lemma($lemma);


    ####Forma eta lema berdina dutenetan, ahal bada, lema eta ezaugarriak zuzendu egiten dira

    my @analizes = $self->generator2->analyze_form($anode->form);
    my $posZahar = $anode->get_iset('pos');

    my $aldatua=0;
    if ( ((lc $anode->form eq lc $lemma) && ($anode->get_iset('pos')) =~ /^(verb)|(noun)|(adv)|(adj)$/ )
	&&
	(($anode->get_iset('advtype') && ($anode->get_iset('advtype') ne 'tim')) || !$anode->get_iset('advtype'))
	&&
	(( ( (($anode->get_iset('nountype') || "") eq 'prop') && $anode->ord == 1)
	  || (($anode->get_iset('nountype') || "") ne 'prop') )) )
	  #nountype prop eukitzekotan 1. posizioa izan behar da.
    {

	#formaren lema berdinik dagoen bilatu
	my @index = grep { $analizes[$_]->{lemma} eq $lemma } 0..$#analizes;
	my $aurkitua=0;
	foreach my $ind (@index)
	{
	    if (($analizes[$ind]->{tag} =~ /^V.+/ && $anode->is_verb)
	       || ($analizes[$ind]->{tag} =~ /^NC.+/ && $anode->is_noun)
	       || ($analizes[$ind]->{tag} =~ /^R.+/ && $anode->get_iset('pos') eq 'adv' )
	       || ($analizes[$ind]->{tag} =~ /^A.+/ && $anode->get_iset('pos') eq 'adj') 
	      )
	    {
		if ($analizes[$ind]->{tag} =~ /^NC.+/ && (($anode->get_iset('nountype') ne 'prop' ) || !$anode->get_iset('nountype'))) 
		{
		    $anode->set_iset('nountype' => 'com' );
		}
		$aurkitua = 1;
		last;
	    }
	}
	if ($aurkitua==0)
	{	    
	    #forma horrekin lema bakarra badago, esleitu.
	    if ($#analizes==0)
	    {		
		if ($analizes[0]->{tag} =~ /^V.+/) 
		{
		    $anode->set_lemma($analizes[0]->{lemma});
		    $anode->set_iset('pos','verb');
		    $anode->set_iset('verbform','inf') if ($analizes[0]->{tag} =~ /^V.N.+/);
		    $anode->set_iset('verbform'=>'fin', 'mood'=>'ind') if ($analizes[0]->{tag} =~ /^V.I.+/);
		    $anode->set_iset('mood'=>'imp', 'verbform'=>'fin') if ($analizes[0]->{tag} =~ /^V.M.+/);
		    $anode->set_iset('verbform','ger') if ($analizes[0]->{tag} =~ /^V.G.+/);
		    $anode->set_iset('verbform','part') if ($analizes[0]->{tag} =~ /^V.P.+/);

		}
		if ($analizes[0]->{tag} =~ /^NC.+/ && ($anode->get_iset('nountype') ne 'prop' )) 
		{
		    $anode->set_lemma($analizes[0]->{lemma});
		    $anode->set_iset('pos' => 'noun', 'nountype' => 'com' );
		}
		if ($analizes[0]->{tag} =~ /^A.+/) 
		{
		    $anode->set_lemma($analizes[0]->{lemma});
		    $anode->set_iset('pos','adj');
		}
		if ($analizes[0]->{tag} =~ /^R.+/) 
		{
		    $anode->set_lemma($analizes[0]->{lemma});
		    $anode->set_iset('pos','adv');
		}
	    }
	    #gehiago badaude
	    elsif ($#analizes>0)
	    {
		#berdinak elkartu
		my $berdina = 1;
		my @ezberdinak;
		push @ezberdinak, $analizes[0];
		my $hirugarren1;
		my $hirugarren2;
		foreach my $i (1..$#analizes)
		{
		    #lema eta etiketako lehen bi hizkiak konparatu
		    my $katea1 = $analizes[$i-1]->{lemma} . ' ' . substr($analizes[$i-1]->{tag},0,2);
		    my $katea2 = $analizes[$i]->{lemma} . ' ' . substr($analizes[$i]->{tag},0,2);
		    $hirugarren1 = substr($analizes[$i-1]->{tag},2,1) if ($analizes[0]->{tag} =~ /^V.+/);
		    $hirugarren2 = substr($analizes[$i]->{tag},2,1) if ($analizes[0]->{tag} =~ /^V.+/);
		    if ($katea1 ne $katea2)
		    {
			$berdina = 0;
			push @ezberdinak, $analizes[$i];
		    }
		}

		#denak berdinak badira, esleitu
		if ($berdina == 1)
		{
		    if ($analizes[0]->{tag} =~ /^V.+/) 
		    {
			$anode->set_iset('pos','verb');
			if ($hirugarren1 eq $hirugarren2)
			{
			    $anode->set_iset('verbform','inf') if ($hirugarren1 eq 'N');
			    $anode->set_iset('verbform'=>'fin', 'mood'=>'ind') if ($hirugarren1 eq 'I');
			    $anode->set_iset('mood'=>'imp', 'verbform'=>'fin') if ($hirugarren1 eq 'M');
			    $anode->set_iset('verbform','ger') if ($hirugarren1 eq 'G');
			    $anode->set_iset('verbform','part') if ($hirugarren1 eq 'P');
			}
		    }
		    if ($analizes[0]->{tag} =~ /^NC.+/ && $anode->get_iset('nountype') ne 'prop') 
		    {
			$anode->set_iset('pos'=>'noun', 'nountype'=>'com');
		    }
		    if ($analizes[0]->{tag} =~ /^A.+/) 
		    {
			$anode->set_iset('pos','adj');
		    }
		    if ($analizes[0]->{tag} =~ /^R.+/) 
		    {
			$anode->set_iset('pos','adv');
		    }
		    $anode->set_lemma($analizes[0]->{lemma});
		}
		#ezberdinak badaude
		else
		{
		    #hitza aditza bada, bilatu aditzak lemetan
		    if ($anode->get_iset('verbform'))
		    {
			my @index= grep { $ezberdinak[$_]->{tag} =~ /^V.+/ } 0..$#ezberdinak;
			if ($#index==0)
			{
			    $anode->set_iset('pos','verb');
			    $anode->set_lemma($ezberdinak[$index[0]]->{lemma});
			}
		    }
		    #hitza izena bada
		    if ( ($anode->get_iset('nountype') || "") ne 'prop')
		    {
			my @index= grep { $ezberdinak[$_]->{tag} =~ /^NC.+/ } 0..$#ezberdinak;
			if ($#index>=0)
			{
			    $anode->set_iset('pos'=>'noun', 'nountype'=>'com');
			    $anode->set_lemma($ezberdinak[$index[0]]->{lemma});
			}
		    }
		    #adverb
		    if ($anode->get_iset('pos') eq 'adv')
		    {
			my @index= grep { $ezberdinak[$_]->{tag} =~ /^R.+/ } 0..$#ezberdinak;
			if ($#index==0)
			{
			    $anode->set_lemma($ezberdinak[$index[0]]->{lemma});
			}
		    }
		    #adj
		    if ($anode->get_iset('pos') eq 'adj')
		    {
			my @index= grep { $ezberdinak[$_]->{tag} =~ /^A.+/ } 0..$#ezberdinak;
			if ($#index==0)
			{
			    $anode->set_lemma($ezberdinak[$index[0]]->{lemma});
			}
		    }
		}

	    }
	    #kategoria hasierakotik ezberdina bada
	    if ($posZahar ne $anode->get_iset('pos'))
	    { $aldatua = 1; }
	}

	##Aldatzeko aukera izan duten guztientzat:
	if ($anode->get_iset('pos') ne 'verb')
	{
	    $anode->set_iset('tense'=>'', 'verbform'=>'');
	}
	
    }
    
    ### verb->noun, adj->verb, noun->verb, noun->adj, ezaugarriak ezabatu
    my $posBerri = $anode->get_iset('pos');
    if ($posZahar eq 'verb' && $posBerri eq 'noun')
    {
	$anode->set_iset('tense' => '', 'mood' => '', 'verbform' => '');
    }
    if (($posZahar =~ /(adj)|(noun)/) && $posBerri eq 'verb')
    {
	$anode->set_iset('prontype' => '', 'nountype' => '');
    }
    if ($posZahar eq 'noun' && $posBerri eq 'adj')
    {
	$anode->set_iset('nountype' => '');
    }
    if ($posBerri =~ /(adv)|(verb)/)
    {
	$anode->set_iset('prontype' => '');
    }


    # == Fix iset
    
    # lemma=hacer form=haga iset: ind sing 3 pres must be an error ($expected_form is "hace")
    #       comprobar  compruebe                                                       comprueba
    #       acceder    acceda                                                          accede
    # etc.
    #if ($anode->matches(mood=>'ind', number=>'sing', person=>'3', tense=>'pres')){
    if ($anode->is_verb){
        my $expected_form = $generator->best_form_of_lemma($anode->lemma, $anode->iset);
        if ($expected_form ne lc $anode->form){
            my $imperative_form = $generator->best_form_of_lemma($anode->lemma, $imperative_iset);
            # in our dataset imperative is more probable than subjunctive
            if ($imperative_form eq lc $anode->form){
                $anode->iset->set_hash($imperative_iset);
            }
        }           
    }
    
    # Subjunctive in the main clause is suspicious.
    # Very often the same form can be also an imperative, which is more probable.
    if ($anode->parent->is_root && $anode->matches(mood=>'sub', tense=>'pres', number=>'sing', person=>'3')){
        $anode->iset->set_mood('imp');
    }

    # Some subjects should be actually objects
    $self->fix_false_subject($anode);  
   
    $anode->set_tag(join ' ', $anode->get_iset_values);

    return;
}

sub fix_false_subject {
    my ($self, $anode) = @_;
    return if !$anode->is_verb;
    my @children = $anode->get_echildren({or_topological=>1});
    my $subject_child = first {$_->afun eq 'Sb'} @children;
    return if !$subject_child;
    
    my $is_first_person_verb = $anode->iset->person eq '1' ? 1 : 0;
    $is_first_person_verb = 1 if $anode->is_infinitive && any {$_->iset->person eq '1' && $_->afun eq 'AuxV'} @children;
    
    if ($is_first_person_verb && $subject_child->iset->person ne '1'){
        $subject_child->set_afun('Obj');
    }
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::ES::FixTagAndParse - fix IXA-Pipes errors

=head1 DESCRIPTION


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
